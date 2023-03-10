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
setup_output_folders ${org} ${MJOLNIR_OUT_SUBFOLDER_SCAN}

log_info "[START ${SCRIPTNAME_SCAN}] Scanning supermodule starting..." "${SCRIPTNAME_SCAN}"
slack_notification "${notify_flag}" "${SLACK_EMOJI_START_PROCESS} [_${SCRIPTNAME_SCAN}_] *Scanning supermodule starting*. Input file: \`${inputfile}\` " "${SLACK_CHANNEL_ID_FULLACTIVITY}"

tmp_scan_inputfile="/tmp/scan.in.tmp"
scan_inputfile="/tmp/scan.in"

input_jsondata=$(bzcat ${inputfile})
stage2_results_hosts=$(echo ${input_jsondata} | jq -c ".recon.stages.stage2.results.hostnames")
stage2_results_ips=$(echo ${input_jsondata} | jq -c ".recon.stages.stage2.results.ips")

rm -f ${tmp_scan_inputfile} ${scan_inputfile}
log_info "Analyzing input file ${inputfile}..." "${SCRIPTNAME_SCAN}"
h=0
i=0
if [[ ${stage2_results_hosts} == "null" ]]; then
  log_warn "No hostnames were found on the input file. Check the stage2 output part of the recon process on the input file." "${SCRIPTNAME_SCAN}"
  slack_notification "${notify_flag}" "${SLACK_EMOJI_ORANGE_CIRCLE} [_${SCRIPTNAME_SCAN}_] No hostnames were found on the input file. Check the \`stage2\` output part of the recon process on the input file." "${SLACK_CHANNEL_ID_FULLACTIVITY}"
else
  #collect hostnames from stage2 recon phase
  while IFS='' read -r doublequoted_hostname; do
    ips=$(echo ${stage2_results_hosts} | jq -c ".${doublequoted_hostname}")
    if [[ ${ips} != "\"Unable to resolve hostname\"" ]]; then
      echo ${doublequoted_hostname} | tr -d '"' >> ${tmp_scan_inputfile}
      h=$((h+1))
    fi
  done < <(echo ${stage2_results_hosts} | jq "keys[]")
fi

log_info "Number of targets found to scan (from 'hostnames' input): ${h}" "${SCRIPTNAME_SCAN}"
slack_notification "${notify_flag}" "${SLACK_EMOJI_GREEN_CIRCLE} [_${SCRIPTNAME_SCAN}_] Number of targets found to scan (from \`hostnames\` input): \`${h}\`" "${SLACK_CHANNEL_ID_FULLACTIVITY}"

if [[ ${stage2_results_ips} == "null" ]]; then
  log_warn "No IP addresses were found on the input file. Check the stage2 output part of the recon process on the input file." "${SCRIPTNAME_SCAN}"
  slack_notification "${notify_flag}" "${SLACK_EMOJI_ORANGE_CIRCLE} [_${SCRIPTNAME_SCAN}_] No IP addresses were found on the input file. Check the \`stage2\` output part of the recon process on the input file." "${SLACK_CHANNEL_ID_FULLACTIVITY}"
else
  #collect IP addresses from stage2 recon phase (hostanem if available otherwise IP address)
  while IFS='' read -r doublequoted_ip; do
    hostname=$(echo ${stage2_results_ips} | jq -c ".${doublequoted_ip}")
    if [[ ${hostname} != "\"Unable to reverse resolve IP\"" ]]; then
      echo ${hostname} | tr -d '"' >> ${tmp_scan_inputfile}
    else
      echo ${doublequoted_ip} | tr -d '"' >> ${tmp_scan_inputfile}
    fi
    i=$((i+1))
  done < <(echo ${stage2_results_ips} | jq "keys[]")
fi

#remove duplicates (if any) and collect IP addreses only (ignore PTR resolutions)
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


##NAABU##
naabu_output="/tmp/naabu.out"
#rm -f ${naabu_output}
log_info "Running naabu module (input file: ${scan_inputfile} ; output file: ${naabu_output}; fleet: ${fleet})..." "${SCRIPTNAME_SCAN}"
slack_notification "${notify_flag}" "${SLACK_EMOJI_GREEN_CIRCLE} [_${SCRIPTNAME_SCAN}_] Running \`naabu\` module on fleet \`${fleet}\`" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
#axiom-scan ${scan_inputfile} -m naabu -o ${naabu_output} --fleet "${fleet}*" -p - -c 100 -rate 10000 -sa -iv 4,6 -Pn -retries 3

##NMAP##
nmap_output="/tmp/nmap.out"
#rm -f ${nmap_scans_file} ${nmap_output}
discovered_ports=$(cat ${naabu_output} | cut -d ":" -f 2 | sort -u)
discovered_ports=$(echo -n "${discovered_ports}" | tr "\n" ",")
#run nmap against all hosts and all discovered ports
#(not all ports will be found in all hosts but that's fine (for the sake of simplicity))
log_info "Running nmap module (input file: ${scan_inputfile} ; output file: ${nmap_output}; fleet: ${fleet})..." "${SCRIPTNAME_SCAN}"
slack_notification "${notify_flag}" "${SLACK_EMOJI_GREEN_CIRCLE} [_${SCRIPTNAME_SCAN}_] Running \`nmap\` module on fleet \`${fleet}\`" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
#axiom-scan ${scan_inputfile} -m nmap -oX ${nmap_output} --fleet "${fleet}*" -p ${discovered_ports} -Pn -sS -sC -T4 -sV --min-rate 1000 --max-retries 3 --open
#rm -f ${nmap_output}.html

httpx_output="/tmp/httpx.out"
#rm -f ${httpx_output}
#we're not interested in grouping hosts by open ports, but it's a quick and dirty way to get the correspondent hostname of an IP at this point,
#since host-ports will give us ip_port data only
group_by_ports_data=$($MJOLNIR_PATH/auxiliary/nmap-parse-output/nmap-parse-output ${nmap_output} group-by-ports)
http_ports_data=$($MJOLNIR_PATH/auxiliary/nmap-parse-output/nmap-parse-output ${nmap_output} http-ports)
http_ports=$(echo "${http_ports_data}" | grep -P "^http://" | cut -d ":" -f 3 | sort -u | tr "\n" "," | sed 's/.$//')
https_ports=$(echo "${http_ports_data}" | grep -P "^https://" | cut -d ":" -f 3 | sort -u | tr "\n" "," | sed 's/.$//')
#run httpx against all hosts and all discovered HTTP/HTTPS ports
#(not all ports will be found in all hosts but that's fine (for the sake of simplicity))
log_info "Running httpx module (input file: ${scan_inputfile} ; output file: ${httpx_output}; fleet: ${fleet})..." "${SCRIPTNAME_SCAN}"
slack_notification "${notify_flag}" "${SLACK_EMOJI_GREEN_CIRCLE} [_${SCRIPTNAME_SCAN}_] Running \`httpx\` module on fleet \`${fleet}\`" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
#axiom-scan ${scan_inputfile} -m httpx --fleet "${fleet}*" -o ${httpx_output} -p http:${http_ports},https:${https_ports} -sc -cl -ct -location -hash sha512 -jarm -title -server -tech-detect -json -random-agent -fr -timeout 3

#rm -f ${scan_inputfile}
#rm -f ${naabu_output}
#rm -f ${nmap_output}
#rm -f ${httpx_output}

#converting output to json
python3 - << EOF
import json
from bisect import bisect_left
from lxml import etree

data={"scan":{"firstpassscan":{"description":"First pass scan takes all domains and subdomains as input and quickly scan all range of TCP ports from 1 to 65535","results":{}},"secondpassscan":{"description":"The second pass scan receives the results of first pass scan as input and perform a more targeted scan on those ports only","results":{}},"targeteddiscovery":{"description":"After first and second pass scans, some additional discovery scans are executed to find ports running specific services which can then be used to perform focused exploitation on those services","results":{}}}}

#naabu output
with open("${naabu_output}") as f:
  for line in f:
    domain, port = line.strip().split(':')
    if domain in data["scan"]["firstpassscan"]["results"]:
      #using bisect_left to insert the port in the correct index and keep the array sorted
      pos = bisect_left(data["scan"]["firstpassscan"]["results"][domain], int(port))
      data["scan"]["firstpassscan"]["results"][domain].insert(pos, int(port))
    else:
      data["scan"]["firstpassscan"]["results"][domain] = [int(port)]

#nmap output
x = 0
nmap_data = {}
nmap_xml_tree = etree.parse("${nmap_output}")
hosts_elements = nmap_xml_tree.findall(".//host")
for h_xmlelem in hosts_elements:
  ports_elements = h_xmlelem.findall(".//ports")
  for p_xmlelem in ports_elements:
    port_elements = p_xmlelem.findall(".//port")
    for sp_xmlelem in port_elements:
      p_state_elements = sp_xmlelem.find(".//state")
      if p_state_elements.attrib["state"] == "open":
        addr_elements = h_xmlelem.find(".//address")
        hostnames_elements = h_xmlelem.findall(".//hostnames/hostname")
        protocol, port = sp_xmlelem.attrib["protocol"] if "protocol" in sp_xmlelem.attrib.keys() else "unknown", sp_xmlelem.attrib["portid"] if "portid" in sp_xmlelem.attrib.keys() else "unknown"
        p_service_elements = p_xmlelem.find(".//service")
        p_service_cpe_element = p_xmlelem.find(".//cpe")
        cpe = p_service_cpe_element.text if p_service_cpe_element is not None else "unknown"
        service_name, service_product, service_version = p_service_elements.attrib["name"] if "name" in p_service_elements.attrib.keys() else "unknown", p_service_elements.attrib["product"] if "product" in p_service_elements.attrib.keys() else "unknown", p_service_elements.attrib["version"] if "version" in p_service_elements.attrib.keys() else "unknown"
        if hostnames_elements:
          for hostname_xmlelem in hostnames_elements:
            h_type = hostname_xmlelem.attrib["type"] if "type" in hostname_xmlelem.attrib.keys() else "unknown"
            if h_type == "user":
              name = hostname_xmlelem.attrib["name"] if "name" in hostname_xmlelem.attrib.keys() else "unknown"
              nmap_data[f"{name}:{port}"] = {"protocol": protocol, "service_name": service_name, "service_product": service_product, "service_version": service_version, "cpe": cpe}
        else:
              addr = addr_elements.attrib["addr"] if "addr" in addr_elements.attrib.keys() else "unknown"
              nmap_data[f"{addr}:{port}"] = {"protocol": protocol, "service_name": service_name, "service_product": service_product, "service_version": service_version, "cpe": cpe}

nmap_data_sorted = {k: nmap_data[k] for k in sorted(nmap_data)}
data["scan"]["secondpassscan"]["results"] = nmap_data_sorted

EOF
exit
#compress output
log_info "Compressing output" "${SCRIPTNAME_SCAN}"
bzip2 -z ${jsonoutput}
log_info "DONE. output saved to ${jsonoutput}.bz2" "${SCRIPTNAME_SCAN}"

${MJOLNIR_PATH}/fleetmgmt/axiomfleet-delete.sh -p "${fleet}" "${notify_flag_fleet_cmd}"

log_info "[END ${SCRIPTNAME_SCAN}] Scanning supermodule finished." "${SCRIPTNAME_SCAN}"
slack_notification "${notify_flag}" "${SLACK_EMOJI_FINISH_PROCESS} [_${SCRIPTNAME_SCAN}_] Scanning supermodule finished. output saved to: \`${jsonoutput}.bz2\`" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
