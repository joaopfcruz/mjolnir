#!/bin/bash

MJOLNIR_REPO="https://github.com/joaopfcruz/mjolnir.git"

MJOLNIR_HOME_ENVVAR_NAME="MJOLNIR_PATH"
MJOLNIR_HOME_ENVVAR_VALUE="$HOME/mjolnir"
SHELL_FILE="$HOME/.bashrc"

SLEEPTIME=3

GREEN='\033[0;32m'
NC='\033[0m'

RECON_NG_TMP_CMDS_FILE="/tmp/recon-ng.setup.cmds"

echo "ODg4YiAgICAgZDg4OCAgZDhiICAgICAgICAgIDg4OCAgICAgICAgICBkOGIKODg4OGIgICBkODg4OCAgWThQICAgICAgICAgIDg4OCAgICAgICAgICBZOFAKODg4ODhiLmQ4ODg4OCAgICAgICAgICAgICAgIDg4OAo4ODhZODg4ODhQODg4IDg4ODggIC5kODhiLiAgODg4IDg4ODg4Yi4gIDg4OCA4ODhkODg4Cjg4OCBZODg4UCA4ODggIjg4OCBkODgiIjg4YiA4ODggODg4ICI4OGIgODg4IDg4OFAiCjg4OCAgWThQICA4ODggIDg4OCA4ODggIDg4OCA4ODggODg4ICA4ODggODg4IDg4OAo4ODggICAiICAgODg4ICA4ODggWTg4Li44OFAgODg4IDg4OCAgODg4IDg4OCA4ODgKODg4ICAgICAgIDg4OCAgODg4ICAiWTg4UCIgIDg4OCA4ODggIDg4OCA4ODggODg4CiAgICAgICAgICAgICAgIDg4OAogICAgICAgICAgICAgIGQ4OFAKICAgICAgICAgICAgODg4UCIKCigiQnV0IGZpbmVzdCBvZiB0aGVtIGFsbCwgJ1RoZSBDcnVzaGVyJyBpdCBpcyBjYWxsZWQ6IE1qw7ZsbmlyISBIYW1tZXIgb2YgVGhvciEiKQ==" | base64 -d
printf "\n\n"
printf "${GREEN}initiating...\n${NC}"
sleep $SLEEPTIME

printf "${GREEN}\n\n\n*****************************\n"
printf "installing dependencies\n"
printf "*****************************\n\n${NC}"
sudo apt -y install python3 python3-pip git bzip2 recon-ng
pip3 install censys
printf "${GREEN}\nDone. Dependencies installed.\n${NC}"
sleep $SLEEPTIME

printf "${GREEN}\n\n\n*****************************\n"
printf "cloning and configuring mjolnir\n"
printf "*****************************\n\n${NC}"
rm -rf ${MJOLNIR_HOME_ENVVAR_VALUE}
printf "${GREEN}\n\nCloning repo...${NC}\n"
git clone ${MJOLNIR_REPO} ${MJOLNIR_HOME_ENVVAR_VALUE}
printf "${GREEN}\n\nchmoding executable files...${NC}\n"
find ${MJOLNIR_HOME_ENVVAR_VALUE} -name "*.sh" -exec chmod 700 {} \;
printf "${GREEN}\n\nSetting ${MJOLNIR_HOME_ENVVAR_NAME} env variable...${NC}\n"
if grep "export ${MJOLNIR_HOME_ENVVAR_NAME}=" "${SHELL_FILE}"; then
  printf "${GREEN}${MJOLNIR_HOME_ENVVAR_NAME} already set${NC}";
else
  echo "export ${MJOLNIR_HOME_ENVVAR_NAME}=${MJOLNIR_HOME_ENVVAR_VALUE}" >> "${SHELL_FILE}";
  printf "${GREEN}${MJOLNIR_HOME_ENVVAR_NAME} was set${NC}";
fi
printf "${GREEN}\n\n\nDone. mjolnir configured.\n${NC}"
sleep $SLEEPTIME

printf "${GREEN}\n\n\n*****************************\n"
printf "configuring recon-ng\n"
printf "*****************************\n\n${NC}"
printf "%s\n"\
  "marketplace install recon/domains-hosts/hackertarget"\
  "marketplace install recon/domains-hosts/certificate_transparency"\
  "marketplace install reporting/list"\
  "exit" > "${RECON_NG_TMP_CMDS_FILE}"
recon-ng -r ${RECON_NG_TMP_CMDS_FILE}
rm -f ${RECON_NG_TMP_CMDS_FILE}
printf "${GREEN}\nDone. recon-ng configured.\n${NC}"
sleep $SLEEPTIME

printf "${GREEN}\n\n\n*****************************\n"
printf "configuring censys\n"
printf "*****************************\n\n${NC}"
censys config
printf "${GREEN}\nDone. censys configured.\n${NC}"
sleep $SLEEPTIME
