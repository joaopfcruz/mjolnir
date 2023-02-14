#!/bin/bash

source "$MJOLNIR_PATH/includes/vars.sh"
source "$MJOLNIR_PATH/includes/logger.sh"
source "$MJOLNIR_PATH/includes/setup_out_folders.sh"
source "$MJOLNIR_PATH/includes/slack.sh"

SCRIPTNAME_SCAN="scan.sh"

usage() { log_err "Usage: ${SCRIPTNAME_SCAN} -f <fleet> -i <input file> -o <organization> [-s (notify activity on Slack)] [-n number of elements of axiom fleet (override defaults)]" "${SCRIPTNAME_SCAN}"; exit 0; }

notify_flag=false
notify_flag_fleet_cmd=""

while getopts "f:i:o:sn:" flags; do
  case "${flags}" in
    f)
      fleet=${OPTARG}
      ;;
    i)
      inputfile=${OPTARG}
      ;;
    o)
      org=${OPTARG}
      ;;
    s)
      notify_flag=true
      notify_flag_fleet_cmd="-s"
      ;;
    n)
      number_fleet_override=${OPTARG}
      ;;
    *)
      usage
      ;;
  esac
done
shift $((OPTIND-1))
if [ -z "${fleet}" ] || [ -z "${inputfile}" ] || [ -z "${org}" ]; then
  usage
fi

#input sanitization

#remove special characters from prefix, just in case
#axiomfleet-spawn.sh also does this so it should be fine.
fleet=$(echo "${fleet}" | tr -dc '[:alnum:]')

if ! [ -f "${inputfile}" ]; then
  log_err "Input file not found" "${SCRIPTNAME_SCAN}"; exit 1
fi

bzip2_test=$(file ${inputfile} | grep "${inputfile}: bzip2 compressed data")
if [ -z "${bzip2_test}" ]; then
  log_err "Input file is not a bzip2 file" "${SCRIPTNAME_SCAN}"; exit 1
fi

#n_created=$($AXIOM_PATH/interact/axiom-ls | grep "active" | grep -E "${fleet}[0-9]*" | wc -l)
#if ! [ $n_created -eq 0 ]; then
#  log_err "Fleet members are still alive. Please delete the fleet first or set a different fleet name to be created" "${SCRIPTNAME_SCAN}"; exit 1;
#fi

if ! [ -z "${number_fleet_override}" ] && ! [[ "${number_fleet_override}" =~ ^[0-9]+$ ]]; then
  log_err "-n parameter should be an integer number" "${SCRIPTNAME_AXIOMFLEET_SPAWN}"; exit 1;
fi

#GO!
output="${MJOLNIR_OUT_FOLDER_PATH}/${org}/${MJOLNIR_OUT_SUBFOLDER_SCAN}/${MJOLNIR_OUT_SUBFOLDER_SCAN}.out.${org}.$(date +'%Y_%m_%dT%H_%M_%S').txt"
jsonoutput="${output::-4}.json"
setup_output_folders $org $MJOLNIR_OUT_SUBFOLDER_SCAN

log_info "[START ${SCRIPTNAME_SCAN}] Scanning supermodule starting..." "${SCRIPTNAME_SCAN}"
slack_notification "${notify_flag}" "${SLACK_EMOJI_START_PROCESS} [_${SCRIPTNAME_SCAN}_] *Scanning supermodule starting*. Input file: \`${inputfile}\` " "${SLACK_CHANNEL_ID_FULLACTIVITY}"

tmp_scan_inputfile="/tmp/tmpscaninput.txt"
scan_inputfile="/tmp/scaninput.txt"

input_jsondata=$(bzcat ${inputfile})
stage2_results_hosts=$(echo $input_jsondata | jq -c ".recon.stages.stage2.results.hostnames")
stage2_results_ips=$(echo $input_jsondata | jq -c ".recon.stages.stage2.results.ips")

rm -f ${tmp_scan_inputfile}
log_info "Analyzing input file ${inputfile}..." "${SCRIPTNAME_SCAN}"
h=0
i=0
if [[ $stage2_results_hosts == "null" ]]; then
  log_warn "No hostnames were found on the input file. Check the stage2 output part of the recon process on the input file." "${SCRIPTNAME_SCAN}"
  slack_notification "${notify_flag}" "${SLACK_EMOJI_ORANGE_CIRCLE} [_${SCRIPTNAME_SCAN}_] No hostnames were found on the input file. Check the \`stage2\` output part of the recon process on the input file." "${SLACK_CHANNEL_ID_FULLACTIVITY}"
else
  #collect ip resolutions from stage2 recon phase
  while IFS='' read -r doublequoted_hostname; do
    ips=$(echo $stage2_results_hosts | jq -c ".${doublequoted_hostname}")
    if [[ $ips != "\"Unable to resolve hostname\"" ]]; then
      echo $ips | tr -d '"][' >> ${tmp_scan_inputfile}
      h=$((h+1))
    fi
  done < <(echo $stage2_results_hosts | jq "keys[]")
fi
#split ips one per line (since some hostnames will have multiple resolutions)
sed -i "s/,/\n/g" ${tmp_scan_inputfile}

log_info "Number of targets found to scan (from 'hostnames' input): ${h}" "${SCRIPTNAME_SCAN}"
slack_notification "${notify_flag}" "${SLACK_EMOJI_GREEN_CIRCLE} [_${SCRIPTNAME_SCAN}_] Number of targets found to scan (from \`hostnames\` input): \`${h}\`" "${SLACK_CHANNEL_ID_FULLACTIVITY}"

if [[ $stage2_results_ips == "null" ]]; then
  log_warn "No IP addresses were found on the input file. Check the stage2 output part of the recon process on the input file." "${SCRIPTNAME_SCAN}"
  slack_notification "${notify_flag}" "${SLACK_EMOJI_ORANGE_CIRCLE} [_${SCRIPTNAME_SCAN}_] No IP addresses were found on the input file. Check the \`stage2\` output part of the recon process on the input file." "${SLACK_CHANNEL_ID_FULLACTIVITY}"
else
  #collect IPs from stage2 recon phase
  while IFS='' read -r doublequoted_ip; do
    echo $doublequoted_ip | tr -d '"' >> ${tmp_scan_inputfile}
    i=$((i+1))
  done < <(echo $stage2_results_ips | jq "keys[]")
fi

#remove duplicates (if any)
sort -u ${tmp_scan_inputfile} > ${scan_inputfile}
rm -f ${tmp_scan_inputfile}

log_info "Number of targets found to scan (from 'ips' input): ${i}" "${SCRIPTNAME_SCAN}"
slack_notification "${notify_flag}" "${SLACK_EMOJI_GREEN_CIRCLE} [_${SCRIPTNAME_SCAN}_] Number of targets found to scan (from \`ips\` input): \`${i}\`" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
log_info "Total number of target to scan: $((h+i))" "${SCRIPTNAME_SCAN}"
slack_notification "${notify_flag}" "${SLACK_EMOJI_GREEN_CIRCLE} [_${SCRIPTNAME_SCAN}_] Total number of target to scan: \`$((h+i))\`" "${SLACK_CHANNEL_ID_FULLACTIVITY}"

if ! [ -z "${number_fleet_override}" ]; then
  fleet_count=${number_fleet_override}
else
  fleet_count=${MAX_FLEET_NUMBER}
  if [[ $((h+i)) -lt ${MAX_FLEET_NUMBER} ]]; then
    fleet_count=$((h+i))
  fi
fi


#${MJOLNIR_PATH}/fleetmgmt/axiomfleet-spawn.sh -p "${fleet}" -n ${fleet_count} "${notify_flag_fleet_cmd}"

#Network discovery with masscan + NMAP
#1. run masscan to scan all TCP ports on all IP addresses discovered in the recon process (analyzed above and stored in ${scan_inputfile}
#2. With masscan output, prepare a set of different nmap scans. Output will be analyzed so different IP addresses but with the same set of open ports will be scanned at once

#run axiom-scan ${scan_inputfile} -m masscan -o masscanoutput.txt --fleet aesir* -p 0-65535 --rate 100000 --retries 3 --open-only

#prepare set of nmap scans based on masscan output
nmap_scans_file="/tmp/nmap_scans_file.txt"
rm -f ${nmap_scans_file}
python3 - << EOF
import re

def ip_to_hostname(ip):
  json_data = ${input_jsondata}
  ips = json_data["recon"]["stages"]["stage2"]["results"]["ips"]
  hostnames = json_data["recon"]["stages"]["stage2"]["results"]["hostnames"]
  if ip in ips.keys():
    return ips[ip]
  else:
    for h in hostnames.keys():
      if ip in hostnames[h]:
        return h

data = {}
with open("/home/thor/masscanoutput.txt") as masscanoutput:
  for line in masscanoutput:
    line = line.rstrip("\n")
    try:
      ip = re.search("^Host:\s+(\d+\.\d+\.\d+\.\d+)\s+\(\)\s+Ports:\s+\d+/\S+/\S+////$", line).group(1)
      port = re.search("^Host:\s+\d+\.\d+\.\d+\.\d+\s+\(\)\s+Ports:\s+(\d+)/\S+/\S+////$", line).group(1)
    except AttributeError:
      ip = None
      port = None
    if ip and port:
      hostname = ip_to_hostname(ip)
      try:
        data[port].append(hostname)
      except KeyError:
        data[port] = [hostname]

with open("${nmap_scans_file}", "w") as fout:
  for port in data.keys():
      hosts = ",".join(list(dict.fromkeys(data[port])))
      #file format:
      #port#hostnames(comma separated)
      fout.write(f"{port}#{hosts}\n")
EOF

nmap_scan_input="/tmp/nmap_targets.txt"
nmap_scan_intermediate_output="/tmp/nmap_interm_output.txt"
nmap_final_output="/home/thor/nmapoutput.txt"
rm -f ${nmap_scan_input} ${nmap_scan_intermediate_output} ${nmap_final_output}
for scan in $(cat ${nmap_scans_file});
do
  port=$(echo $scan | grep -oP "^\K\d+")
  hosts=$(echo $scan | grep -oP "^\d+#\K\S+$" | sed "s/,/\n/g")
  echo $port
  echo "${hosts}" > ${nmap_scan_input}
  cat ${nmap_scan_input}
  axiom-scan ${nmap_scan_input} -m nmap -oX ${nmap_scan_intermediate_output} --fleet "${fleet}*" -p ${port} --resolve-all -Pn -sS -T4 -sV --script=default,vuln --min-rate 1000 --max-retries 3
  cat ${nmap_scan_intermediate_output} >> ${nmap_final_output}
  rm -f ${nmap_scan_intermediate_output}
  axiom-scan ${nmap_scan_input} -m nmap -oX ${nmap_scan_intermediate_output} --fleet "${fleet}*" -p ${port} --resolve-all -Pn -sS -T4 -sV --script=default,vuln --min-rate 1000 --max-retries 3 -6
  cat ${nmap_scan_intermediate_output} >> ${nmap_final_output}
  rm -f ${nmap_scan_input} ${nmap_scan_intermediate_output}
done
#rm -f ${nmap_scans_file}

#rm -f ${scan_inputfile}
#compress output
#log_info "Compressing output" "${SCRIPTNAME_SCAN}"
#bzip2 -z ${jsonoutput}
#log_info "DONE. output saved to ${jsonoutput}.bz2" "${SCRIPTNAME_SCAN}"

#${MJOLNIR_PATH}/fleetmgmt/axiomfleet-delete.sh -p "${fleet}" "${notify_flag_fleet_cmd}"

#log_info "[END ${SCRIPTNAME_SCAN}] Scanning supermodule finished." "${SCRIPTNAME_SCAN}"
#slack_notification "${notify_flag}" "${SLACK_EMOJI_FINISH_PROCESS} [_${SCRIPTNAME_SCAN}_] Scanning supermodule finished. output saved to: \`${jsonoutput}.bz2\`" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
