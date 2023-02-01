#!/bin/bash

source "$MJOLNIR_PATH/includes/vars.sh"
source "$MJOLNIR_PATH/includes/logger.sh"
source "$MJOLNIR_PATH/includes/slack.sh"

usage() { log_err "Usage: $0 -f <fleet prefix> -n <number of instances to spawn> [-s (notify activity on Slack)]"; exit 0; }

notify_flag=false
while getopts "f:n:s" flags; do
  case "${flags}" in
    f)
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
  log_err "-n parameter should be an integer number"; exit 1;
fi

#input sanitization: remove special characters from prefix, just in case
prefix=$(echo "${prefix}" | tr -dc '[:alnum:]')

log_info "[START $0] Spawning process started. Will create ${n_instances} instances in fleet ${prefix}..."
slack_notification "${notify_flag}" "${SLACK_EMOJI_START_PROCESS} [_$0_] *Fleet spawning process started*. Will create \`${n_instances}\` instances in fleet \`${prefix}\`" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
$AXIOM_PATH/interact/axiom-fleet $prefix -i $n_instances

if ! [ $? -eq 0 ]; then
  log_err "An error occurred while initializing fleet"
  slack_notification "${notify_flag}" "${SLACK_EMOJI_RED_CIRCLE} [_$0_] An error occurred while initializing fleet" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
  exit 1
else
  log_info "Fleet should have been initialized with success. Waiting a few more seconds to let the process end..."
  sleep 120
  n_created=$($AXIOM_PATH/interact/axiom-ls | grep "active" | grep -E "${prefix}[0-9]*" | wc -l)
  if [ $n_created -eq $n_instances ]; then
    log_info "${n_created} instances were created successfully (${n_instances} were requested)"
    slack_notification "${notify_flag}" "${SLACK_EMOJI_GREEN_CIRCLE} [_$0_] \`${n_created}\` instances were created successfully (\`${n_instances}\` were requested)" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
  else
    log_warn "Number of created instances (${n_created}) differs from number of requested instances (${n_instances})"
    log_warn "run axiom-ls to check created instances, or check DigitalOcean dashboard"
    slack_notification "${notify_flag}" "${SLACK_EMOJI_ORANGE_CIRCLE} [_$0_] Number of created instances (\`${n_created}\`) differs from number of requested instances (\`${n_instances}\`). Run axiom-ls to check created instances, or check DigitalOcean dashboard" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
  fi
fi
log_info "[END $0] Finished spawning process"
slack_notification "${notify_flag}" "${SLACK_EMOJI_FINISH_PROCESS} [_$0_] Finished fleet spawning process" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
