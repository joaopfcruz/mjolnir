#!/bin/bash

source "$MJOLNIR_PATH/includes/vars.sh"
source "$MJOLNIR_PATH/includes/logger.sh"
source "$MJOLNIR_PATH/includes/setup_out_folders.sh"
source "$MJOLNIR_PATH/includes/slack.sh"

SCRIPTNAME_SCAN="scan.sh"

MAX_FLEET_NUMBER=25

usage() { log_err "Usage: ${SCRIPTNAME_SCAN} -f <fleet> -i <input file> -o <organization> [-s (notify activity on Slack)]" "${SCRIPTNAME_SCAN}"; exit 0; }

notify_flag=false
notify_flag_fleet_cmd=""

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
      notify_flag_fleet_cmd="-s"
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

n_created=$($AXIOM_PATH/interact/axiom-ls | grep "active" | grep -E "${fleet}[0-9]*" | wc -l)
if ! [ $n_created -eq 0 ]; then
  log_err "Fleet members are still alive. Please delete the fleet first or set a different fleet name to be created" "${SCRIPTNAME_SCAN}"; exit 1;
fi

#GO!
output="${MJOLNIR_OUT_FOLDER_PATH}/${org}/${MJOLNIR_OUT_SUBFOLDER_SCAN}/${MJOLNIR_OUT_SUBFOLDER_SCAN}.out.${org}.$(date +'%Y_%m_%dT%H_%M_%S').txt"
jsonoutput="${output::-4}.json"
setup_output_folders $org $MJOLNIR_OUT_SUBFOLDER_SCAN

log_info "[START ${SCRIPTNAME_SCAN}] Scanning supermodule starting..." "${SCRIPTNAME_SCAN}"
slack_notification "${notify_flag}" "${SLACK_EMOJI_START_PROCESS} [_${SCRIPTNAME_SCAN}_] *Scanning supermodule starting*. Input file: \`${inputfile}\` " "${SLACK_CHANNEL_ID_FULLACTIVITY}"

scan_inputfile="/tmp/scaninput.txt"

input_jsondata=$(bzcat ${inputfile})
stage2_results_hosts=$(echo $input_jsondata | jq -c ".recon.stages.stage2.results.hostnames")
stage2_results_ips=$(echo $input_jsondata | jq -c ".recon.stages.stage2.results.ips")

rm -f ${scan_inputfile}
log_info "Analyzing input file ${inputfile}..." "${SCRIPTNAME_SCAN}"
h=0
i=0
if [[ $stage2_results_hosts == "null" ]]; then
  log_warn "No hostnames were found on the input file. Check the stage2 output part of the recon process on the input file." "${SCRIPTNAME_SCAN}"
  slack_notification "${notify_flag}" "${SLACK_EMOJI_ORANGE_CIRCLE} [_${SCRIPTNAME_SCAN}_] No hostnames were found on the input file. Check the \`stage2\` output part of the recon process on the input file." "${SLACK_CHANNEL_ID_FULLACTIVITY}"
else
  #collect hostnames from stage2 recon phase
  while IFS='' read -r doublequoted_hostname; do
    ips=$(echo $stage2_results_hosts | jq -c ".${doublequoted_hostname}")
    if [[ $ips != "\"Unable to resolve hostname\"" ]]; then
      hostname=$(echo $doublequoted_hostname | tr -d '"')
      echo "$hostname" >> ${scan_inputfile}
      h=$((h+1))
    fi
  done < <(echo $stage2_results_hosts | jq "keys[]")
fi
log_info "Number of targets found to scan (from 'hostnames' input): ${h}" "${SCRIPTNAME_SCAN}"
slack_notification "${notify_flag}" "${SLACK_EMOJI_GREEN_CIRCLE} [_${SCRIPTNAME_SCAN}_] Number of targets found to scan (from \`hostnames\` input): \`${h}\`" "${SLACK_CHANNEL_ID_FULLACTIVITY}"

if [[ $stage2_results_ips == "null" ]]; then
  log_warn "No IP addresses were found on the input file. Check the stage2 output part of the recon process on the input file." "${SCRIPTNAME_SCAN}"
  slack_notification "${notify_flag}" "${SLACK_EMOJI_ORANGE_CIRCLE} [_${SCRIPTNAME_SCAN}_] No IP addresses were found on the input file. Check the \`stage2\` output part of the recon process on the input file." "${SLACK_CHANNEL_ID_FULLACTIVITY}"
else
  #collect IPs from stage2 recon phase
  #if it reverse resolves to an hostname, collect hostname
  #else, collect IP
  while IFS='' read -r doublequoted_ip; do
    hostname=$(echo $stage2_results_ips | jq -c ".${doublequoted_ip}")
    if [[ $hostname != "\"Unable to reverse resolve IP\"" ]]; then
      hostname=$(echo $hostname | tr -d '"')
      echo "$hostname" >> ${scan_inputfile}
    else
      ip=$(echo $doublequoted_ip | tr -d '"')
      echo "$ip" >> ${scan_inputfile}
    fi
    i=$((i+1))
  done < <(echo $stage2_results_ips | jq "keys[]")
fi
log_info "Number of targets found to scan (from 'ips' input): ${i}" "${SCRIPTNAME_SCAN}"
slack_notification "${notify_flag}" "${SLACK_EMOJI_GREEN_CIRCLE} [_${SCRIPTNAME_SCAN}_] Number of targets found to scan (from \`ips\` input): \`${i}\`" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
log_info "Total number of target to scan: $((h+i))" "${SCRIPTNAME_SCAN}"
slack_notification "${notify_flag}" "${SLACK_EMOJI_GREEN_CIRCLE} [_${SCRIPTNAME_SCAN}_] Total number of target to scan: \`$((h+i))\`" "${SLACK_CHANNEL_ID_FULLACTIVITY}"

fleet_count=${MAX_FLEET_NUMBER}
if [[ $((h+i)) -lt ${MAX_FLEET_NUMBER} ]]; then
  fleet_count=$((h+i))
fi
${MJOLNIR_PATH}/fleetmgmt/axiomfleet-spawn.sh -p "${fleet}" -n ${fleet_count} "${notify_flag_fleet_cmd}"

#rm -f ${scan_inputfile}
#compress output
#log_info "Compressing output" "${SCRIPTNAME_SCAN}"
#bzip2 -z ${jsonoutput}
log_info "DONE. output saved to ${jsonoutput}.bz2" "${SCRIPTNAME_SCAN}"

${MJOLNIR_PATH}/fleetmgmt/axiomfleet-delete.sh -p "${fleet}" "${notify_flag_fleet_cmd}"

log_info "[END ${SCRIPTNAME_SCAN}] Scanning supermodule finished." "${SCRIPTNAME_SCAN}"
slack_notification "${notify_flag}" "${SLACK_EMOJI_FINISH_PROCESS} [_${SCRIPTNAME_SCAN}_] Scanning supermodule finished. output saved to: \`${jsonoutput}.bz2\`" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
