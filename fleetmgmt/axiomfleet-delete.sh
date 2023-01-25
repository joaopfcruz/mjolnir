#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

AXIOM_PATH="$HOME/.axiom"

usage() { printf "${RED}Usage: $0 -p <fleet prefix>${NC}\n" 1>&2; exit 0; }

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
  >&2 printf "${RED}error: An error occurred while deleting fleet.${NC}\n"; exit 1;
else
  printf "${GREEN}Fleet should have been deleted with success.${NC}\n"
fi
