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
while IFS= read -r line
do
  log_info "    $line"
done < "${inputfile}"

rm -f ${output} ${TMP_FILE}
log_info "Running amass module (input file: ${inputfile} ; output file: {$output}; fleet: ${fleet})..."
axiom-scan ${inputfile} -m amass -o ${output} --quiet --fleet "${fleet}*" -brute -active > /dev/null 2>&1
grep -f ${inputfile} ${output} >> ${output}
rm -f ${TMP_FILE}
log_info "Running assetfinder module (input file: ${inputfile} ; output file: ${output}; fleet: ${fleet})..."
axiom-scan ${inputfile} -m assetfinder -o ${output} --fleet "${fleet}*" > /dev/null 2>&1
grep -f ${inputfile} ${output} >> ${output}
rm -f ${TMP_FILE}
log_info "Running cero module (input file: ${inputfile} ; output file: {$output}; fleet: ${fleet})..."
axiom-scan ${inputfile} -m cero -o ${output} --fleet "${fleet}*" > /dev/null 2>&1
grep -f ${inputfile} ${output} >> ${output}
rm -f ${TMP_FILE}
log_info "Running findomain module (input file: ${inputfile} ; output file: {$output}; fleet: ${fleet})..."
axiom-scan ${inputfile} -m findomain -o ${output} --fleet "${fleet}*" > /dev/null 2>&1
grep -f ${inputfile} ${output} >> ${output}
rm -f ${TMP_FILE}
log_info "Running subfinder module (input file: ${inputfile} ; output file: {$output}; fleet: ${fleet})..."
axiom-scan ${inputfile} -m subfinder -o ${output} --fleet "${fleet}*" > /dev/null 2>&1
grep -f ${inputfile} ${output} >> ${output}
rm -f ${TMP_FILE}

#finalize output: use grep to delete all unneeded output (like wildcard domains) and remove duplicates
grep -P "(?=^.{4,253}$)(^(?:[a-zA-Z0-9](?:(?:[a-zA-Z0-9\-]){0,61}[a-zA-Z0-9])?\.)+([a-zA-Z]{2,}|xn--[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])$)" ${output} | sort -u > ${TMP_FILE}
mv ${TMP_FILE} ${output}

#compress output
log_info "Compressing output"
bzip2 -z "${output}"
log_info "DONE. output saved to ${output}.bz2"
log_info "[END $0] Recon supermodule finished."
