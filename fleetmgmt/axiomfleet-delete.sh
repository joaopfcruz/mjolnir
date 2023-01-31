#!/bin/bash

source "$MJOLNIR_PATH/includes/vars.sh"
source "$MJOLNIR_PATH/includes/logger.sh"
source "$MJOLNIR_PATH/includes/slack.sh"

usage() { log_err "Usage: $0 -p <fleet prefix> [-s (notify activity on Slack)]"; exit 0; }

notify_flag=false
while getopts "p:s" flags; do
  case "${flags}" in
    p)
      prefix=${OPTARG}
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
if [ -z "${prefix}" ]; then
  usage
fi

#input sanitization: remove special characters from prefix, just in case
#axiomfleet-spawn.sh also does this so it should be fine.
prefix=$(echo "${prefix}" | tr -dc '[:alnum:]')

log_info "[START $0] Deletion process starting. Will delete fleet $prefix..."
slack_notification "${notify_flag}" "${SLACK_EMOJI_START_PROCESS} [_$0_] *Fleet deletion process started*. Will delete fleet \`${prefix}\`" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
$AXIOM_PATH/interact/axiom-rm "${prefix}*" -f
log_info "Deletion command ran successfully. Waiting a few more seconds to let the process end..."
sleep 10

if ! [ $? -eq 0 ]; then
  log_err "An error occurred while deleting fleet"
  slack_notification "${notify_flag}" "${SLACK_EMOJI_RED_CIRCLE} [_$0_] An error occurred while deleting fleet \`${prefix}\`" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
  exit 1
else
  n_instances=$($AXIOM_PATH/interact/axiom-ls | grep "active" | grep -E "${prefix}[0-9]*" | wc -l)
if [ $n_instances -eq 0 ]; then
    log_info "Fleet ${prefix} should have been deleted successfully (or no instances matched the prefix supplied)"
    slack_notification "${notify_flag}" "${SLACK_EMOJI_GREEN_CIRCLE} [_$0_] Fleet \`${prefix}\` should have been deleted successfully (or no instances matched the prefix supplied)" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
  else
    log_warn "Fleet ${prefix} still have undeleted instances. Please delete them manually. Run axiom-ls or check DigitalOcean dashboard"
    slack_notification "${notify_flag}" "${SLACK_EMOJI_ORANGE_CIRCLE} [_$0_] Fleet \`${prefix}\` still have undeleted instances. Please delete them manually. Run axiom-ls or check DigitalOcean dashboard" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
  fi
fi
log_info "[END $0] Finished deletion process"
slack_notification "${notify_flag}" "${SLACK_EMOJI_FINISH_PROCESS} [_$0_] Finished fleet deletion process" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
