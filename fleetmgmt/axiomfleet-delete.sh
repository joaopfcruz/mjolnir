#!/bin/bash

source "$MJOLNIR_PATH/includes/vars.sh"
source "$MJOLNIR_PATH/includes/logger.sh"

usage() { log_err "Usage: $0 -p <fleet prefix>"; exit 0; }

while getopts ":p:" flags; do
  case "${flags}" in
    p)
      prefix=${OPTARG}
      ;;
    *)
      usage
      ;;
  esac
done
shift $((OPTIND-1))
if [ -z "${prefix}" ]; then
  usage
fi

#input sanitization: remove special characters from prefix, just in case
#axiomfleet-spawn.sh also does this so it should be fine.
prefix=$(echo "${prefix}" | tr -dc '[:alnum:]')

log_info "[START $0] Deletion process starting. Will delete fleet $prefix..."
$AXIOM_PATH/interact/axiom-rm "${prefix}*" -f
log_info "Deletion command ran successfully. Waiting a few more seconds to let the process end..."
sleep 10

if ! [ $? -eq 0 ]; then
  log_err "An error occurred while deleting fleet"; exit 1;
else
  n_instances=$($AXIOM_PATH/interact/axiom-ls | grep "active" | grep -E "${prefix}[0-9]*" | wc -l)
if [ $n_instances -eq 0 ]; then
    log_info "Fleet ${prefix} should have been deleted successfully (or no instances matched the prefix supplied)"
  else
    log_warn "Fleet ${prefix} still have undeleted instances. Please delete them manually. Run axiom-ls or check DigitalOcean dashboard"
  fi
fi
log_info "[END $0] Finished deletion process"
