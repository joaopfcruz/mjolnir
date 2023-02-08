#!/bin/bash

source "$MJOLNIR_PATH/includes/vars.sh"
source "$MJOLNIR_PATH/includes/logger.sh"
source "$MJOLNIR_PATH/includes/slack.sh"

SCRIPTNAME_AXIOMFLEET_DELETE="axiomfleet-delete.sh"

usage() { log_err "Usage: ${SCRIPTNAME_AXIOMFLEET_DELETE} -p <fleet prefix> [-s (notify activity on Slack)]" "${SCRIPTNAME_AXIOMFLEET_DELETE}"; exit 0; }

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

log_info "[START ${SCRIPTNAME_AXIOMFLEET_DELETE}] Deletion process starting. Will delete fleet $prefix..." "${SCRIPTNAME_AXIOMFLEET_DELETE}"
slack_notification "${notify_flag}" "${SLACK_EMOJI_START_PROCESS} [_${SCRIPTNAME_AXIOMFLEET_DELETE}_] *Fleet deletion process started*. Will delete fleet \`${prefix}\`" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
$AXIOM_PATH/interact/axiom-rm "${prefix}*" -f
log_info "Deletion command ran successfully. Waiting a few more seconds to let the process end..." "${SCRIPTNAME_AXIOMFLEET_DELETE}"
sleep 10

if ! [ $? -eq 0 ]; then
  log_err "An error occurred while deleting fleet" "${SCRIPTNAME_AXIOMFLEET_DELETE}"
  slack_notification "${notify_flag}" "${SLACK_EMOJI_RED_CIRCLE} [_${SCRIPTNAME_AXIOMFLEET_DELETE}_] An error occurred while deleting fleet \`${prefix}\`" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
  exit 1
else
  n_instances=$($AXIOM_PATH/interact/axiom-ls | grep "active" | grep -E "${prefix}[0-9]*" | wc -l)
if [ $n_instances -eq 0 ]; then
    log_info "Fleet ${prefix} should have been deleted successfully (or no instances matched the prefix supplied)" "${SCRIPTNAME_AXIOMFLEET_DELETE}"
    slack_notification "${notify_flag}" "${SLACK_EMOJI_GREEN_CIRCLE} [_${SCRIPTNAME_AXIOMFLEET_DELETE}_] Fleet \`${prefix}\` should have been deleted successfully (or no instances matched the prefix supplied)" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
  else
    log_warn "Fleet ${prefix} still have undeleted instances. Please delete them manually. Run axiom-ls or check DigitalOcean dashboard" "${SCRIPTNAME_AXIOMFLEET_DELETE}"
    slack_notification "${notify_flag}" "${SLACK_EMOJI_ORANGE_CIRCLE} [_${SCRIPTNAME_AXIOMFLEET_DELETE}_] Fleet \`${prefix}\` still have undeleted instances. Please delete them manually. Run axiom-ls or check DigitalOcean dashboard" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
  fi
fi
log_info "[END ${SCRIPTNAME_AXIOMFLEET_DELETE}] Finished deletion process" "${SCRIPTNAME_AXIOMFLEET_DELETE}"
slack_notification "${notify_flag}" "${SLACK_EMOJI_FINISH_PROCESS} [_${SCRIPTNAME_AXIOMFLEET_DELETE}_] Finished fleet deletion process" "${SLACK_CHANNEL_ID_FULLACTIVITY}"
