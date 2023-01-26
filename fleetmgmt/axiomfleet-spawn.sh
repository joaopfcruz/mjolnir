#!/bin/bash

source "$MJOLNIR_PATH/includes/vars.sh"
source "$MJOLNIR_PATH/includes/logger.sh"

usage() { log_err "Usage: $0 -p <fleet prefix> -n <number of instances to spawn>"; exit 0; }

while getopts ":p:n:" flags; do
  case "${flags}" in
    p)
      prefix=${OPTARG}
      ;;
    n)
      n_instances=${OPTARG}
      ;;
    *)
      usage
      ;;
  esac
done
shift $((OPTIND-1))
if [ -z "${prefix}" ] || [ -z "${n_instances}" ]; then
  usage
fi

#input validation: check if n_instances is a number
if ! [[ "${n_instances}" =~ ^[0-9]+$ ]]; then
  log_err "-n parameter should be an integer number"; exit 1;
fi

#input sanitization: remove special characters from prefix, just in case
prefix=$(echo "${prefix}" | tr -dc '[:alnum:]')

log_info "[START $0] Spawning process started. Will create ${n_instances} instances in fleet ${prefix}..."
$AXIOM_PATH/interact/axiom-fleet $prefix -i $n_instances

if ! [ $? -eq 0 ]; then
  log_err "An error occurred while initializing fleet"; exit 1;
else
  log_info "Fleet should have been initialized with success. Waiting a few more seconds to let the process end..."
  sleep 120
  n_created=$($AXIOM_PATH/interact/axiom-ls | grep "active" | grep -E "${prefix}[0-9]*" | wc -l)
  if [ $n_created -eq $n_instances ]; then
    log_info "${n_created} instances were created successfully (${n_instances} were requested)}"
  else
    log_warn "Number of created instances (${n_created}) differs from number of requested instances (${n_instances})"
    log_warn "run axiom-ls to check created instances, or check DigitalOcean dashboard"
  fi
fi
log_info "[END $0] Finished spawning process"
