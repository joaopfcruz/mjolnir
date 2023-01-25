#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

AXIOM_PATH="$HOME/.axiom"

usage() { printf "${RED}Usage: $0 -p <fleet prefix> -n <number of instances to spawn>${NC}\n" 1>&2; exit 0; }

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
if ! [[ "$n_instances" =~ ^[0-9]+$ ]]; then
  >&2 printf "${RED}error: -n parameter should be an integer number${NC}\n"; exit 1;
fi

#input sanitization: remove special characters from prefix, just in case
prefix=$(echo "${prefix}" | tr -dc '[:alnum:]')

$AXIOM_PATH/interact/axiom-fleet $prefix -i $n_instances

if ! [ $? -eq 0 ]; then
  >&2 printf "${RED}error: An error occurred while initializing fleet.${NC}\n"; exit 1;
else
  printf "${GREEN}Fleet should have been initialized with success. Waiting a few more seconds to let the process end...${NC}\n"
  sleep 120
  printf "${GREEN}Fleet ${prefix} details:{NC}\n"
  $AXIOM_PATH/interact/axiom-ls | grep $prefix
fi
