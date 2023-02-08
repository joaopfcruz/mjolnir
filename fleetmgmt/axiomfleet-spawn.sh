#!/bin/bash

source "$MJOLNIR_PATH/includes/vars.sh"
source "$MJOLNIR_PATH/includes/logger.sh"
source "$MJOLNIR_PATH/includes/slack.sh"

SCRIPTNAME="axiomfleet-spawn.sh"

usage() { log_err "Usage: ${SCRIPTNAME} -p <fleet prefix> -n <number of instances to spawn> [-s (notify activity on Slack)]" "${SCRIPTNAME}"; exit 0; }

notify_flag=false
while getopts "p:n:s" flags; do
  case "${flags}" in
    p)
      prefix=${OPTARG}
      ;;
    n)
      n_instances=${OPTARG}
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
if [ -z "${prefix}" ] || [ -z "${n_instances}" ]; then
  usage
fi

#input validation: check if n_instances is a number
if ! [[ "${n_instances}" =~ ^[0-9]+$ ]]; then
  log_err "-n parameter should be an integer number" "${SCRIPTNAME}"; exit 1;
fi

#input sanitization: remove special characters from prefix, just in case
prefix=$(echo "${prefix}" | tr -dc '[:alnum:]')

log_info "[START ${SCRIPTNAME}] Spawning process started. Will create ${n_instances} instances in fleet ${prefix}..." "${SCRIPTNAME}"
slack_notification "${notify_flag}" "${SLACK_EMOJI_START_PROCESS} [_${SCRIPTNAME}_] *Fleet spawning process started*. Will create \`${n_instances}\` instances in fleet \`${prefix}\`" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
$AXIOM_PATH/interact/axiom-fleet $prefix -i $n_instances

if ! [ $? -eq 0 ]; then
  log_err "An error occurred while initializing fleet" "${SCRIPTNAME}"
  slack_notification "${notify_flag}" "${SLACK_EMOJI_RED_CIRCLE} [_${SCRIPTNAME}_] An error occurred while initializing fleet" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
  exit 1
else
  log_info "Fleet should have been initialized with success. Waiting a few more seconds to let the process end..." "${SCRIPTNAME}"
  sleep 120
  n_created=$($AXIOM_PATH/interact/axiom-ls | grep "active" | grep -E "${prefix}[0-9]*" | wc -l)
  if [ $n_created -eq $n_instances ]; then
    log_info "${n_created} instances were created successfully (${n_instances} were requested)" "${SCRIPTNAME}"
    slack_notification "${notify_flag}" "${SLACK_EMOJI_GREEN_CIRCLE} [_${SCRIPTNAME}_] \`${n_created}\` instances were created successfully (\`${n_instances}\` were requested)" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
  else
    log_warn "Number of created instances (${n_created}) differs from number of requested instances (${n_instances})" "${SCRIPTNAME}"
    log_warn "run axiom-ls to check created instances, or check DigitalOcean dashboard" "${SCRIPTNAME}"
    slack_notification "${notify_flag}" "${SLACK_EMOJI_ORANGE_CIRCLE} [_${SCRIPTNAME}_] Number of created instances (\`${n_created}\`) differs from number of requested instances (\`${n_instances}\`). Run axiom-ls to check created instances, or check DigitalOcean dashboard" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
  fi
fi
log_info "[END ${SCRIPTNAME}] Finished spawning process" "${SCRIPTNAME}"
slack_notification "${notify_flag}" "${SLACK_EMOJI_FINISH_PROCESS} [_${SCRIPTNAME}_] Finished fleet spawning process" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
