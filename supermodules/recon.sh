#!/bin/bash

source "$MJOLNIR_PATH/includes/vars.sh"
source "$MJOLNIR_PATH/includes/logger.sh"
source "$MJOLNIR_PATH/includes/setup_out_folders.sh"
source "$MJOLNIR_PATH/includes/slack.sh"

TMP_FILE="/tmp/recon.tmp"

SCRIPTNAME_RECON="recon.sh"

MAX_FLEET_NUMBER=10

usage() { log_err "Usage: ${SCRIPTNAME_RECON} -f <fleet> -i <input file> -o <organization> [-s (notify activity on Slack)] [-n number of elements of axiom fleet (override defaults)]" "${SCRIPTNAME_RECON}"; exit 0; }

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
  log_err "Input file not found" "${SCRIPTNAME_RECON}"; exit 1
fi

if ! [[ $(file ${inputfile}) = "${inputfile}: ASCII text" ]]; then
  log_err "Input file is not a text file or is an empty file" "${SCRIPTNAME_RECON}"; exit 1
fi

n_created=$($AXIOM_PATH/interact/axiom-ls | grep "active" | grep -E "${fleet}[0-9]*" | wc -l)
if ! [ $n_created -eq 0 ]; then
  log_err "Fleet members are still alive. Please delete the fleet first or set a different fleet name to be created" "${SCRIPTNAME_RECON}"; exit 1;
fi

if ! [ -z "${number_fleet_override}" ] && ! [[ "${number_fleet_override}" =~ ^[0-9]+$ ]]; then
  log_err "-n parameter should be an integer number" "${SCRIPTNAME_AXIOMFLEET_SPAWN}"; exit 1;
fi

#GO!
output="${MJOLNIR_OUT_FOLDER_PATH}/${org}/${MJOLNIR_OUT_SUBFOLDER_RECON}/${MJOLNIR_OUT_SUBFOLDER_RECON}.out.${org}.$(date +'%Y_%m_%dT%H_%M_%S').txt"
jsonoutput="${output::-4}.json"
setup_output_folders $org $MJOLNIR_OUT_SUBFOLDER_RECON

log_info "[START ${SCRIPTNAME_RECON}] Recon supermodule starting..." "${SCRIPTNAME_RECON}"
log_info "Input data:" "${SCRIPTNAME_RECON}"
slack_notif_text="${SLACK_EMOJI_START_PROCESS} [_${SCRIPTNAME_RECON}_] *Recon supermodule starting*. Input data:"$'\n'
d=0
for dom in $(cat ${inputfile})
do
  log_info "    $dom" "${SCRIPTNAME_RECON}"
  slack_notif_text="${slack_notif_text}        :dart:\`$dom\`"$'\n'
  d=$((d+1))
done
slack_notification "${notify_flag}" "${slack_notif_text}" "${SLACK_CHANNEL_ID_FULLACTIVITY}"

if ! [ -z "${number_fleet_override}" ]; then
  fleet_count=${number_fleet_override}
else
  fleet_count=${MAX_FLEET_NUMBER}
  if [[ ${d} -lt ${MAX_FLEET_NUMBER} ]]; then
    fleet_count=${d}
  fi
fi

${MJOLNIR_PATH}/fleetmgmt/axiomfleet-spawn.sh -p "${fleet}" -n ${fleet_count} "${notify_flag_fleet_cmd}"

rm -f ${output} ${TMP_FILE}
log_info "Running amass module (input file: ${inputfile} ; output file: ${TMP_FILE}; fleet: ${fleet})..." "${SCRIPTNAME_RECON}"
slack_notification "${notify_flag}" "${SLACK_EMOJI_GREEN_CIRCLE} [_${SCRIPTNAME_RECON}_] Running \`amass\` module on fleet \`${fleet}\`" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
axiom-scan ${inputfile} -m amass -o ${TMP_FILE} --fleet "${fleet}*" -brute -active
grep -f ${inputfile} ${TMP_FILE} >> ${output}
log_info "Total results so far (still not cleaned up): $(wc -l < ${output})" "${SCRIPTNAME_RECON}"
rm -f ${TMP_FILE}
log_info "Running assetfinder module (input file: ${inputfile} ; output file: ${TMP_FILE}; fleet: ${fleet})..." "${SCRIPTNAME_RECON}"
slack_notification "${notify_flag}" "${SLACK_EMOJI_GREEN_CIRCLE} [_${SCRIPTNAME_RECON}_] Running \`assetfinder\` module on fleet \`${fleet}\`" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
axiom-scan ${inputfile} -m assetfinder -o ${TMP_FILE} --fleet "${fleet}*"
grep -f ${inputfile} ${TMP_FILE} >> ${output}
log_info "Total results so far (still not cleaned up): $(wc -l < ${output})" "${SCRIPTNAME_RECON}"
rm -f ${TMP_FILE}
log_info "Running cero module (input file: ${inputfile} ; output file: ${TMP_FILE}; fleet: ${fleet})..." "${SCRIPTNAME_RECON}"
slack_notification "${notify_flag}" "${SLACK_EMOJI_GREEN_CIRCLE} [_${SCRIPTNAME_RECON}_] Running \`cero\` module on fleet \`${fleet}\`" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
axiom-scan ${inputfile} -m cero -o ${TMP_FILE} --fleet "${fleet}*"
grep -f ${inputfile} ${TMP_FILE} >> ${output}
log_info "Total results so far (still not cleaned up): $(wc -l < ${output})" "${SCRIPTNAME_RECON}"
rm -f ${TMP_FILE}
log_info "Running findomain module (input file: ${inputfile} ; output file: ${TMP_FILE}; fleet: ${fleet})..." "${SCRIPTNAME_RECON}"
slack_notification "${notify_flag}" "${SLACK_EMOJI_GREEN_CIRCLE} [_${SCRIPTNAME_RECON}_] Running \`findomain\` module on fleet \`${fleet}\`" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
axiom-scan ${inputfile} -m findomain -o ${TMP_FILE} --fleet "${fleet}*"
grep -f ${inputfile} ${TMP_FILE} >> ${output}
log_info "Total results so far (still not cleaned up): $(wc -l < ${output})" "${SCRIPTNAME_RECON}"
rm -f ${TMP_FILE}
log_info "Running subfinder module (input file: ${inputfile} ; output file: ${TMP_FILE}; fleet: ${fleet})..." "${SCRIPTNAME_RECON}"
slack_notification "${notify_flag}" "${SLACK_EMOJI_GREEN_CIRCLE} [_${SCRIPTNAME_RECON}_] Running \`subfinder\` module on fleet \`${fleet}\`" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
axiom-scan ${inputfile} -m subfinder -o ${TMP_FILE} --fleet "${fleet}*"
grep -f ${inputfile} ${TMP_FILE} >> ${output}
log_info "Total results so far (still not cleaned up): $(wc -l < ${output})" "${SCRIPTNAME_RECON}"
rm -f ${TMP_FILE}
log_info "Running censys 'subdomains' (input file: ${inputfile} ; output file: ${TMP_FILE}; fleet: N/A - running locally)..." "${SCRIPTNAME_RECON}"
slack_notification "${notify_flag}" "${SLACK_EMOJI_GREEN_CIRCLE} [_${SCRIPTNAME_RECON}_] Running \`censys subdomains\` (locally)" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
for dom in $(cat ${inputfile})
do
  censys subdomains $dom | grep -v "^Found" | perl -n -e '/\s+-\s+(\S+)/ && print "$1\n"' >> ${TMP_FILE}
done
grep -f ${inputfile} ${TMP_FILE} >> ${output}
log_info "Total results so far: $(wc -l < ${output})" "${SCRIPTNAME_RECON}"
rm -f ${TMP_FILE}
log_info "Running recon-ng (input file: ${inputfile} ; output file: ${TMP_FILE}; fleet: N/A - running locally)..." "${SCRIPTNAME_RECON}"
slack_notification "${notify_flag}" "${SLACK_EMOJI_GREEN_CIRCLE} [_${SCRIPTNAME_RECON}_] Running \`recon-ng\` submodules (locally)" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
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
log_info "Total results so far: $(wc -l < ${output})" "${SCRIPTNAME_RECON}"
rm -f ${TMP_FILE}
log_info "Running input domain permutations (input file: ${inputfile} ; output file: ${TMP_FILE}; fleet: N/A - running locally)..." "${SCRIPTNAME_RECON}"
slack_notification "${notify_flag}" "${SLACK_EMOJI_GREEN_CIRCLE} [_${SCRIPTNAME_RECON}_] Running \`input domain permutations\` internal module (locally)" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
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
log_info "Total results so far (still not cleaned up): $(wc -l < ${output})" "${SCRIPTNAME_RECON}"
rm -f ${TMP_FILE}

#clean up useless data (like duplicates and wildcards)
log_info "Cleaning up data..." "${SCRIPTNAME_RECON}"
grep -P "(?=^.{4,253}$)(^(?:[a-zA-Z0-9](?:(?:[a-zA-Z0-9\-]){0,61}[a-zA-Z0-9])?\.)+([a-zA-Z]{2,}|xn--[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])$)" ${output} | sort -u > ${TMP_FILE}
mv ${TMP_FILE} ${output}
log_info "Total results so far (after clean up duplicates and other irrelevant data): $(wc -l < ${output})" "${SCRIPTNAME_RECON}"

#this one doesn't need cleanup. Running after cleaning useless data
log_info "Running censys 'search' (input file: ${inputfile} ; output file: ${TMP_FILE}; fleet: N/A - running locally)..." "${SCRIPTNAME_RECON}"
slack_notification "${notify_flag}" "${SLACK_EMOJI_GREEN_CIRCLE} [_${SCRIPTNAME_RECON}_] Running \`censys search\` (locally)" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
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

log_info "Total number of results: $(wc -l < ${output})" "${SCRIPTNAME_RECON}"
slack_notification "${notify_flag}" "${SLACK_EMOJI_GREEN_CIRCLE} [_${SCRIPTNAME_RECON}_] Total number of results after cleanup: \`$(wc -l < ${output})\`" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
#converting output to json and execute 2nd stage of recon
python3 - << EOF
import json
import socket
import ipaddress
import ssl
from cryptography import x509
from cryptography.hazmat.backends import default_backend

def is_valid_ipv4_address(ip):
  try:
    ipaddress.IPv4Address(ip)
    return True
  except ipaddress.AddressValueError:
    return False

def is_valid_ipv6_address(ip):
  try:
    ipaddress.IPv6Address(ip)
    return True
  except ipaddress.AddressValueError:
    return False

def resolve_ip(i):
  try:
    return socket.gethostbyaddr(i)[0]
  except:
    return "Unable to reverse resolve IP"

def resolve_name(n):
  try:
    addr_info = socket.getaddrinfo(n, None, socket.AF_UNSPEC)
    ip_addresses = set()
    for addr in addr_info:
      ip_addresses.add(addr[4][0])
    return ip_addresses
  except:
    return "Unable to resolve hostname"

#a few results could not be related with the input domains (common in public cloud infrastructures)
#as we don't want to scan foreign assets, for these cases we're doing what we can in order to check if
#a given untrusted result is really related with any of the input domains
#we're querying the TLS certificate on port 443 (falling back to 8443 if 443 is closed).
#if the common name includes any of the input domains we can trust the asset
#if not, we mark the asset as untrusted
def double_check_untrusted_result(result, input_domains):
  TIMEOUT = 3
  def get_cert_subject_cn():
    try:
      with context.wrap_socket(sock, server_hostname=result) as ssock:
        cert_data = ssock.getpeercert(True)
        cert = x509.load_der_x509_certificate(cert_data, default_backend())
        return cert.subject.get_attributes_for_oid(x509.NameOID.COMMON_NAME)[0].value
    except:
      return None
  context = ssl.create_default_context()
  context.check_hostname = False
  context.verify_mode = ssl.CERT_NONE
  try:
    with socket.create_connection((result, 443), timeout = TIMEOUT) as sock:
      common_name = get_cert_subject_cn()
      return common_name and any(s in common_name for s in input_domains)
  except:
    try:
      with socket.create_connection((result, 8443), timeout = TIMEOUT) as sock:
        common_name = get_cert_subject_cn()
        return common_name and any(s in common_name for s in input_domains)
    except:
      return False

data={"recon":{"stages":{"stage1":{"description":"The first stage of reconnaissance process crawls and queries multiple sources in order to retrieve all known IP addresses and hosts related to the top-level domains provided"}}}}
with open("${output}") as fin:
  with open("${inputfile}") as f:
   input_domains = [domain.rstrip("\n") for domain in f]
  results = [result.rstrip("\n") for result in fin]
  data["recon"]["stages"]["stage1"]["results"] = results
  data["recon"]["stages"]["stage2"] = {}
  stage2 = data["recon"]["stages"]["stage2"]
  stage2["description"]="The second stage of reconnaissance process takes the output of previous stage and evaluates what hosts are alive and what IP addresses they resolve to (or reverse DNS in case of IP to name resolution). As an extra precaution measure, for the cases where the resolved DNS name for any result doesn't include any of the domain names given on the input file, the tool tries to fetch a TLS certificate from common ports for HTTPS (443 and 8443) and evaluates the subject common name. If it doesn't find any certificate or if it doesn't appears to be related with any of the domains given as input the result will be recorded on the 'untrustedresults' list."
  stage2["results"]={"hostnames":{},"ips":{}, "untrustedresults":[]}
  stage2_hostnames = stage2["results"]["hostnames"]
  stage2_ips = stage2["results"]["ips"]
  untrusted = stage2["results"]["untrustedresults"]
  for r in results:
    if is_valid_ipv4_address(r) or is_valid_ipv6_address(r):
      name = resolve_ip(r)
      if not any(s in name for s in input_domains):
        if not double_check_untrusted_result(r, input_domains):
          untrusted.append(r)
        else:
          stage2_ips[r] = name
      else:
        stage2_ips[r] = name
    else:
      if not any(s in r for s in input_domains):
        if not double_check_untrusted_result(r, input_domains):
          untrusted.append(r)
        else:
          resolutions = resolve_name(r)
          resolutions_output = []
          if resolutions != "Unable to resolve hostname":
            for res in resolutions:
              resolutions_output.append(f"{res}|{resolve_ip(res)}")
              stage2_hostnames[r] = resolutions_output
          else:
            stage2_hostnames[r] = "Unable to resolve hostname"
      else:
        resolutions = resolve_name(r)
        resolutions_output = []
        if resolutions != "Unable to resolve hostname":
          for res in resolutions:
            resolutions_output.append(f"{res}|{resolve_ip(res)}")
            stage2_hostnames[r] = resolutions_output
        else:
          stage2_hostnames[r] = "Unable to resolve hostname"
  with open("${jsonoutput}", "w") as fout:
    json.dump(data, fout, indent=2)
EOF
rm -f ${output}

#compress output
log_info "Compressing output" "${SCRIPTNAME_RECON}"
bzip2 -z ${jsonoutput}
log_info "DONE. output saved to ${jsonoutput}.bz2" "${SCRIPTNAME_RECON}"

${MJOLNIR_PATH}/fleetmgmt/axiomfleet-delete.sh -p "${fleet}" "${notify_flag_fleet_cmd}"

log_info "[END ${SCRIPTNAME_RECON}] Recon supermodule finished." "${SCRIPTNAME_RECON}"
slack_notification "${notify_flag}" "${SLACK_EMOJI_FINISH_PROCESS} [_${SCRIPTNAME_RECON}_] Recon supermodule finished. output saved to: \`${jsonoutput}.bz2\`" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
