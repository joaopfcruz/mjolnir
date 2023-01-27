#!/bin/bash

source "$MJOLNIR_PATH/includes/vars.sh"
source "$MJOLNIR_PATH/includes/logger.sh"
source "$MJOLNIR_PATH/includes/setup_out_folders.sh"

TMP_FILE="/tmp/recon.tmp"

usage() { log_err "Usage: $0 -f <fleet> -i <input file> -o <organization>"; exit 0; }

while getopts ":f:i:o:" flags; do
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
setup_output_folders $org $MJOLNIR_OUT_SUBFOLDER_RECON

log_info "[START $0] Recon supermodule starting..."
log_info "Input data:"
for dom in $(cat ${inputfile})
do
  log_info "    $dom"
done

rm -f ${output} ${TMP_FILE}
log_info "Running amass module (input file: ${inputfile} ; output file: ${TMP_FILE}; fleet: ${fleet})..."
#axiom-scan ${inputfile} -m amass -o ${TMP_FILE} --quiet --fleet "${fleet}*" -brute -active
grep -f ${inputfile} ${TMP_FILE} >> ${output}
log_info "Total results so far (still not cleaned up): $(wc -l < ${output})"
rm -f ${TMP_FILE}
log_info "Running assetfinder module (input file: ${inputfile} ; output file: ${TMP_FILE}; fleet: ${fleet})..."
axiom-scan ${inputfile} -m assetfinder -o ${TMP_FILE} --fleet "${fleet}*"
grep -f ${inputfile} ${TMP_FILE} >> ${output}
log_info "Total results so far (still not cleaned up): $(wc -l < ${output})"
rm -f ${TMP_FILE}
log_info "Running cero module (input file: ${inputfile} ; output file: ${TMP_FILE}; fleet: ${fleet})..."
axiom-scan ${inputfile} -m cero -o ${TMP_FILE} --fleet "${fleet}*"
grep -f ${inputfile} ${TMP_FILE} >> ${output}
log_info "Total results so far (still not cleaned up): $(wc -l < ${output})"
rm -f ${TMP_FILE}
log_info "Running findomain module (input file: ${inputfile} ; output file: ${TMP_FILE}; fleet: ${fleet})..."
axiom-scan ${inputfile} -m findomain -o ${TMP_FILE} --fleet "${fleet}*"
grep -f ${inputfile} ${TMP_FILE} >> ${output}
log_info "Total results so far (still not cleaned up): $(wc -l < ${output})"
rm -f ${TMP_FILE}
log_info "Running subfinder module (input file: ${inputfile} ; output file: ${TMP_FILE}; fleet: ${fleet})..."
axiom-scan ${inputfile} -m subfinder -o ${TMP_FILE} --fleet "${fleet}*"
grep -f ${inputfile} ${TMP_FILE} >> ${output}
log_info "Total results so far (still not cleaned up): $(wc -l < ${output})"
rm -f ${TMP_FILE}
log_info "Running censys 'subdomains' (input file: ${inputfile} ; output file: ${TMP_FILE}; fleet: N/A - running locally)..."
for dom in $(cat ${inputfile})
do
  censys subdomains $dom | grep -v "^Found" | perl -n -e '/\s+-\s+(\S+)/ && print "$1\n"' >> ${TMP_FILE}
done
grep -f ${inputfile} ${TMP_FILE} >> ${output}
log_info "Total results so far: $(wc -l < ${output})"
rm -f ${TMP_FILE}
log_info "Running recon-ng (input file: ${inputfile} ; output file: ${TMP_FILE}; fleet: N/A - running locally)..."
RECON_NG_CMDS_FILE="/tmp/recon-ng.cmds"
RECON_NG_DEL_TMPWORKSPACE_CMDS_FILE="/tmp/recon-ng_delwspace.cmds"
RECON_NG_TMPWORKSPACE="tmp_workspace"
for dom in $(cat ${inputfile})
do
  printf "%s\n"\
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
  cat ${TMP_FILE} >> ${output}
  rm -f ${RECON_NG_CMDS_FILE} ${TMP_FILE}

  printf "%s\n"\
  "workspaces remove ${RECON_NG_TMPWORKSPACE}"\
  "exit" > "${RECON_NG_DEL_TMPWORKSPACE_CMDS_FILE}"
  recon-ng -r ${RECON_NG_DEL_TMPWORKSPACE_CMDS_FILE}
  rm -f ${RECON_NG_DEL_TMPWORKSPACE_CMDS_FILE}
done

grep -f ${inputfile} ${TMP_FILE} >> ${output}
log_info "Total results so far: $(wc -l < ${output})"
rm -f ${TMP_FILE}
#clean up useless data (like duplicates and wildcards)
log_info "Cleaning up data..."
grep -P "(?=^.{4,253}$)(^(?:[a-zA-Z0-9](?:(?:[a-zA-Z0-9\-]){0,61}[a-zA-Z0-9])?\.)+([a-zA-Z]{2,}|xn--[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])$)" ${output} | sort -u > ${TMP_FILE}
mv ${TMP_FILE} ${output}
log_info "Total results so far (after clean up duplicates and other irrelevant data): $(wc -l < ${output})"

#this one doesn't need cleanup. Running after cleaning useless data
log_info "Running censys 'search' (input file: ${inputfile} ; output file: ${TMP_FILE}; fleet: N/A - running locally)..."
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

#compress output
log_info "Compressing output"
bzip2 -z ${output}
log_info "DONE. output saved to ${output}.bz2"
log_info "[END $0] Recon supermodule finished."
