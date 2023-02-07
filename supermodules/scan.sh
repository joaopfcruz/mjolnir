#!/bin/bash

source "$MJOLNIR_PATH/includes/vars.sh"
source "$MJOLNIR_PATH/includes/logger.sh"
source "$MJOLNIR_PATH/includes/setup_out_folders.sh"
source "$MJOLNIR_PATH/includes/slack.sh"

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

bzip2_test=$(file ${inputfile} | grep "${inputfile}: bzip2 compressed data")
if [ -z "${bzip2_test}" ]; then
  log_err "Input file is not a bzip2 file"; exit 1
fi

n_created=$($AXIOM_PATH/interact/axiom-ls | grep "active" | grep -E "${fleet}[0-9]*" | wc -l)
if [ $n_created -eq 0 ]; then
  log_err "Fleet was not found"; exit 1;
else
  log_info "Fleet ${fleet} was found. Number of instances in fleet: ${n_created}"
fi

#GO!
output="${MJOLNIR_OUT_FOLDER_PATH}/${org}/${MJOLNIR_OUT_SUBFOLDER_SCAN}/${MJOLNIR_OUT_SUBFOLDER_SCAN}.out.${org}.$(date +'%Y_%m_%dT%H_%M_%S').txt"
jsonoutput="${output::-4}.json"
setup_output_folders $org $MJOLNIR_OUT_SUBFOLDER_SCAN

log_info "[START $0] Scanning supermodule starting..."

scan_inputfile="/tmp/scaninput.txt"

input_jsondata=$(bzcat ${inputfile})
stage2_results_hosts=$(echo $input_jsondata | jq -c ".recon.stages.stage2.results.hostnames")
stage2_results_ips=$(echo $input_jsondata | jq -c ".recon.stages.stage2.results.ips")

rm -f ${scan_inputfile}
if [[ $stage2_results_hosts == "null" ]]; then
  echo "stage2_hosts is null"
else
  #collect hostnames from stage2 recon phase
  while IFS='' read -r doublequoted_hostname; do
    ips=$(echo $stage2_results_hosts | jq -c ".${doublequoted_hostname}")
    if [[ $ips != "\"Unable to resolve hostname\"" ]]; then
      hostname=$(echo $doublequoted_hostname | tr -d '"')
      echo "$hostname" >> ${scan_inputfile}
    fi
  done < <(echo $stage2_results_hosts | jq "keys[]")
fi

if [[ $stage2_results_ips == "null" ]]; then
  echo "stage2_ips is null"
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
  done < <(echo $stage2_results_ips | jq "keys[]")
fi

#rm -f ${scan_inputfile}
