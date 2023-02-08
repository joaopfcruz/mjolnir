#!/bin/bash

source "$MJOLNIR_PATH/includes/vars.sh"
source "$MJOLNIR_PATH/includes/logger.sh"
source "$MJOLNIR_PATH/includes/setup_out_folders.sh"
source "$MJOLNIR_PATH/includes/slack.sh"

TMP_FILE="/tmp/recon.tmp"

usage() { log_err "Usage: $0 -f <fleet> -i <input file> -o <organization> [-s (notify activity on Slack)]"; exit 0; }

notify_flag=false
while getopts ":f:i:o:s" flags; do
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
  log_err "Input file not found"; exit 1
fi

if ! [[ $(file ${inputfile}) = "${inputfile}: ASCII text" ]]; then
  log_err "Input file is not a text file or is an empty file"; exit 1
fi

n_created=$($AXIOM_PATH/interact/axiom-ls | grep "active" | grep -E "${fleet}[0-9]*" | wc -l)
if [ $n_created -eq 0 ]; then
  log_err "Fleet was not found"; exit 1;
else
  log_info "Fleet ${fleet} was found. Number of instances in fleet: ${n_created}"
fi

#GO!
output="${MJOLNIR_OUT_FOLDER_PATH}/${org}/${MJOLNIR_OUT_SUBFOLDER_RECON}/${MJOLNIR_OUT_SUBFOLDER_RECON}.out.${org}.$(date +'%Y_%m_%dT%H_%M_%S').txt"
jsonoutput="${output::-4}.json"
setup_output_folders $org $MJOLNIR_OUT_SUBFOLDER_RECON

log_info "[START $0] Recon supermodule starting..."
log_info "Input data:"
slack_notif_text="${SLACK_EMOJI_START_PROCESS} [_$0_] *Recon supermodule starting*. Input data:"$'\n'
for dom in $(cat ${inputfile})
do
  log_info "    $dom"
  slack_notif_text="${slack_notif_text}        :dart:\`$dom\`"$'\n'
done
slack_notification "${notify_flag}" "${slack_notif_text}" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
rm -f ${output} ${TMP_FILE}
log_info "Running amass module (input file: ${inputfile} ; output file: ${TMP_FILE}; fleet: ${fleet})..."
slack_notification "${notify_flag}" "${SLACK_EMOJI_GREEN_CIRCLE} [_$0_] Running \`amass\` module on fleet \`${fleet}\`" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
axiom-scan ${inputfile} -m amass -o ${TMP_FILE} --fleet "${fleet}*" -brute -active
grep -f ${inputfile} ${TMP_FILE} >> ${output}
log_info "Total results so far (still not cleaned up): $(wc -l < ${output})"
rm -f ${TMP_FILE}
log_info "Running assetfinder module (input file: ${inputfile} ; output file: ${TMP_FILE}; fleet: ${fleet})..."
slack_notification "${notify_flag}" "${SLACK_EMOJI_GREEN_CIRCLE} [_$0_] Running \`assetfinder\` module on fleet \`${fleet}\`" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
axiom-scan ${inputfile} -m assetfinder -o ${TMP_FILE} --fleet "${fleet}*"
grep -f ${inputfile} ${TMP_FILE} >> ${output}
log_info "Total results so far (still not cleaned up): $(wc -l < ${output})"
rm -f ${TMP_FILE}
log_info "Running cero module (input file: ${inputfile} ; output file: ${TMP_FILE}; fleet: ${fleet})..."
slack_notification "${notify_flag}" "${SLACK_EMOJI_GREEN_CIRCLE} [_$0_] Running \`cero\` module on fleet \`${fleet}\`" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
axiom-scan ${inputfile} -m cero -o ${TMP_FILE} --fleet "${fleet}*"
grep -f ${inputfile} ${TMP_FILE} >> ${output}
log_info "Total results so far (still not cleaned up): $(wc -l < ${output})"
rm -f ${TMP_FILE}
log_info "Running findomain module (input file: ${inputfile} ; output file: ${TMP_FILE}; fleet: ${fleet})..."
slack_notification "${notify_flag}" "${SLACK_EMOJI_GREEN_CIRCLE} [_$0_] Running \`findomain\` module on fleet \`${fleet}\`" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
axiom-scan ${inputfile} -m findomain -o ${TMP_FILE} --fleet "${fleet}*"
grep -f ${inputfile} ${TMP_FILE} >> ${output}
log_info "Total results so far (still not cleaned up): $(wc -l < ${output})"
rm -f ${TMP_FILE}
log_info "Running subfinder module (input file: ${inputfile} ; output file: ${TMP_FILE}; fleet: ${fleet})..."
slack_notification "${notify_flag}" "${SLACK_EMOJI_GREEN_CIRCLE} [_$0_] Running \`subfinder\` module on fleet \`${fleet}\`" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
axiom-scan ${inputfile} -m subfinder -o ${TMP_FILE} --fleet "${fleet}*"
grep -f ${inputfile} ${TMP_FILE} >> ${output}
log_info "Total results so far (still not cleaned up): $(wc -l < ${output})"
rm -f ${TMP_FILE}
log_info "Running censys 'subdomains' (input file: ${inputfile} ; output file: ${TMP_FILE}; fleet: N/A - running locally)..."
slack_notification "${notify_flag}" "${SLACK_EMOJI_GREEN_CIRCLE} [_$0_] Running \`censys subdomains\` (locally)" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
for dom in $(cat ${inputfile})
do
  censys subdomains $dom | grep -v "^Found" | perl -n -e '/\s+-\s+(\S+)/ && print "$1\n"' >> ${TMP_FILE}
done
grep -f ${inputfile} ${TMP_FILE} >> ${output}
log_info "Total results so far: $(wc -l < ${output})"
rm -f ${TMP_FILE}
log_info "Running recon-ng (input file: ${inputfile} ; output file: ${TMP_FILE}; fleet: N/A - running locally)..."
slack_notification "${notify_flag}" "${SLACK_EMOJI_GREEN_CIRCLE} [_$0_] Running \`recon-ng\` submodules (locally)" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
RECON_NG_CMDS_FILE="/tmp/recon-ng.cmds"
RECON_NG_DEL_TMPWORKSPACE_CMDS_FILE="/tmp/recon-ng_delwspace.cmds"
RECON_NG_TMPWORKSPACE="tmp_workspace"
for dom in $(cat ${inputfile})
do
  printf "%s\n"\
    "options set TIMEOUT 60"\
    "modules load recon/domains-hosts/hackertarget"\
    "options set SOURCE ${dom}"\
    "run"\
    "modules load recon/domains-hosts/certificate_transparency"\
    "options set SOURCE ${dom}"\
    "run"\
    "modules load reporting/list"\
    "options set COLUMN host"\
    "options set FILENAME ${TMP_FILE}"\
    "run"\
    "exit" > "${RECON_NG_CMDS_FILE}"
  recon-ng -w ${RECON_NG_TMPWORKSPACE} -r ${RECON_NG_CMDS_FILE}
  grep -f ${inputfile} ${TMP_FILE} >> ${output}
  rm -f ${RECON_NG_CMDS_FILE} ${TMP_FILE}

  printf "%s\n"\
  "workspaces remove ${RECON_NG_TMPWORKSPACE}"\
  "exit" > "${RECON_NG_DEL_TMPWORKSPACE_CMDS_FILE}"
  recon-ng -r ${RECON_NG_DEL_TMPWORKSPACE_CMDS_FILE}
  rm -f ${RECON_NG_DEL_TMPWORKSPACE_CMDS_FILE}
done
log_info "Total results so far: $(wc -l < ${output})"
rm -f ${TMP_FILE}
log_info "Running input domain permutations (input file: ${inputfile} ; output file: ${TMP_FILE}; fleet: N/A - running locally)..."
slack_notification "${notify_flag}" "${SLACK_EMOJI_GREEN_CIRCLE} [_$0_] Running \`input domain permutations\` internal module (locally)" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
for result in $(cat "${output}")
do
  domain=""
  other_domains=()
  for i in $(cat "${inputfile}")
  do
    if echo "${result}"| grep -q "${i}"; then
      domain=${i}
    else
      other_domains=("${other_domains[@]}" "${i}")
    fi
  done
  if ! [ -z "${domain}" ]; then
    for d in "${other_domains[@]}"; do
      test_domain=${result//$domain/$d}
      if [ -n "$(getent ahosts $test_domain | awk '{ print $1 }' | head -1)" ]; then
        echo "$test_domain" >> ${TMP_FILE}
      fi
    done
  fi
done
cat ${TMP_FILE}
grep -f ${inputfile} ${TMP_FILE} >> ${output}
log_info "Total results so far (still not cleaned up): $(wc -l < ${output})"
rm -f ${TMP_FILE}

#clean up useless data (like duplicates and wildcards)
log_info "Cleaning up data..."
grep -P "(?=^.{4,253}$)(^(?:[a-zA-Z0-9](?:(?:[a-zA-Z0-9\-]){0,61}[a-zA-Z0-9])?\.)+([a-zA-Z]{2,}|xn--[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])$)" ${output} | sort -u > ${TMP_FILE}
mv ${TMP_FILE} ${output}
log_info "Total results so far (after clean up duplicates and other irrelevant data): $(wc -l < ${output})"

#this one doesn't need cleanup. Running after cleaning useless data
log_info "Running censys 'search' (input file: ${inputfile} ; output file: ${TMP_FILE}; fleet: N/A - running locally)..."
slack_notification "${notify_flag}" "${SLACK_EMOJI_GREEN_CIRCLE} [_$0_] Running \`censys search\` (locally)" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
CENSYS_TMP_FILE="/tmp/censys.recon.tmp"
censys_query=""
for dom in $(cat ${inputfile})
do
  censys_query+="$dom or "
done
censys_query=${censys_query::-4}
censys search "${censys_query}" --index-type hosts --pages -1 > ${CENSYS_TMP_FILE}
python3 - << EOF
import json
with open("${CENSYS_TMP_FILE}") as fcensystmp:
  entries = json.load(fcensystmp)
  with open("${TMP_FILE}", "w") as ftmp:
    for e in entries:
      try:
        for name in e["dns"]["reverse_dns"]["names"]:
          ftmp.write(f"{name}\n")
      except KeyError:
        ftmp.write(f"{e['ip']}\n")
EOF
rm -f ${CENSYS_TMP_FILE}
cat ${TMP_FILE} >> ${output}
rm -f ${TMP_FILE}

log_info "Total number of results: $(wc -l < ${output})"
slack_notification "${notify_flag}" "${SLACK_EMOJI_GREEN_CIRCLE} [_$0_] Total number of results after cleanup: \`$(wc -l < ${output})\`" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
#converting output to json and execute 2nd stage of recon
python3 - << EOF
import json
import socket
with open("${jsonoutput}", "w") as fout:
  data={"recon":{"stages":{"stage1":{"description":"The first stage of reconnaissance process crawls and queries multiple sources in order to retrieve all known IP addresses and hosts related to the top-level domains provided"}}}}
  with open("${output}") as fin:
    results = [result.rstrip("\n") for result in fin]
    data["recon"]["stages"]["stage1"]["results"] = results
    data["recon"]["stages"]["stage2"] = {}
    stage2 = data["recon"]["stages"]["stage2"]
    stage2["description"]="The second stage of reconnaissance process takes the output of previous stage and evaluates what hosts are alive and what IP addresses they resolve to (or reverse DNS in case of IP to name resolution)"
    stage2["results"]={"hostnames":{},"ips":{}}
    stage2_hostnames = stage2["results"]["hostnames"]
    stage2_ips = stage2["results"]["ips"]
    for r in results:
      try:
        socket.inet_aton(r)
        try:
          stage2_ips[r] = socket.gethostbyaddr(r)[0]
        except socket.herror:
          stage2_ips[r] = "Unable to reverse resolve IP"
      except socket.error:
        try:
          stage2_hostnames[r] = socket.gethostbyname_ex(r)[2]
        except socket.gaierror:
          stage2_hostnames[r] = "Unable to resolve hostname"
  json.dump(data, fout, indent=2)
EOF

rm -f ${output}
#compress output
log_info "Compressing output"
bzip2 -z ${jsonoutput}
log_info "DONE. output saved to ${jsonoutput}.bz2"
log_info "[END $0] Recon supermodule finished."
slack_notification "${notify_flag}" "${SLACK_EMOJI_FINISH_PROCESS} [_$0_] Recon supermodule finished. output saved to: \`${jsonoutput}.bz2\`" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
