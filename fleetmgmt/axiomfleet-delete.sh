#!/bin/bash

source "$MJOLNIR_PATH/includes/vars.sh"
source "$MJOLNIR_PATH/includes/logger.sh"

usage() { log_err "Usage: $0 -p <fleet prefix>" 1>&2; exit 0; }

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
$AXIOM_PATH/interact/axiom-rm "${prefix}*" -f

if ! [ $? -eq 0 ]; then
  >&2 log_err "An error occurred while deleting fleet."; exit 1;
else
  log_info "Fleet should have been deleted with success."
fi
