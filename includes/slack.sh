#!/bin/bash
source "$HOME/.slackenv"

SCRIPTNAME_SLACK="slack.sh"

slack_notification() {
  if [ "$1" = true ] ; then
    log_info "Sending Slack notification to channel $3. API answer:" "${SCRIPTNAME_SLACK}"
    curl_output=$(curl -s -d "text=$2" -d "channel=$3" -H "Authorization: Bearer ${SLACK_API_TOKEN}" -X POST https://slack.com/api/chat.postMessage)
    printf "${curl_output}\n"
  fi
}
