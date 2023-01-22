#!/bin/bash

DEFAULT_LOCALE="en_US.UTF-8"
APPUSER="thor"
SLEEPTIME=3

GREEN='\033[0;32m'
NC='\033[0m'

echo "Cjg4OGIgICAgIGQ4ODggIGQ4YiAgICAgICAgICA4ODggICAgICAgICAgZDhiICAgICAgICAgCjg4ODhiICAgZDg4ODggIFk4UCAgICAgICAgICA4ODggICAgICAgICAgWThQICAgICAgICAgCjg4ODg4Yi5kODg4ODggICAgICAgICAgICAgICA4ODggICAgICAgICAgICAgICAgICAgICAgCjg4OFk4ODg4OFA4ODggODg4OCAgLmQ4OGIuICA4ODggODg4ODhiLiAgODg4IDg4OGQ4ODggCjg4OCBZODg4UCA4ODggIjg4OCBkODgiIjg4YiA4ODggODg4ICI4OGIgODg4IDg4OFAiICAgCjg4OCAgWThQICA4ODggIDg4OCA4ODggIDg4OCA4ODggODg4ICA4ODggODg4IDg4OCAgICAgCjg4OCAgICIgICA4ODggIDg4OCBZODguLjg4UCA4ODggODg4ICA4ODggODg4IDg4OCAgICAgCjg4OCAgICAgICA4ODggIDg4OCAgIlk4OFAiICA4ODggODg4ICA4ODggODg4IDg4OCAgICAgCiAgICAgICAgICAgICAgIDg4OCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgZDg4UCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgIDg4OFAiCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAooIkJ1dCBmaW5lc3Qgb2YgdGhlbSBhbGwsIFRoZSBDcnVzaGVyIGl0IGlzIGNhbGxlZDogTWrDtmxuaXIhIEhhbW1lciBvZiBUaG9yISIp" | base64 -d
printf "\n\n"
printf "${GREEN}initiating...\n${NC}"
sleep $SLEEPTIME

printf "${GREEN}\n\n\n*****************************\n"
printf "apt update, dist-upgrade, install locales-all and set default locale\n"
printf "*****************************\n\n${NC}"
export DEBIAN_FRONTEND=noninteractive #useful for 100% unattended apt dist-upgrade
apt update
apt install locales-all
apt update && apt -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade && apt -y autoremove && apt -y clean
printf "LANG=$DEFAULT_LOCALE\nLC_ALL=$DEFAULT_LOCALE" > /etc/default/locale
printf "${GREEN}\nDone. packages and distro updated and default locale set to $DEFAULT_LOCALE\n${NC}"
sleep $SLEEPTIME

printf "${GREEN}\n\n\n*****************************\n"
printf "Creating '$APPUSER' user, preventing ssh login to it, and temporarily make it a passwordless sudo user (for the sake of unnatended setup)\n"
printf "*****************************\n\n${NC}"
if id "$APPUSER" &>/dev/null; then
  printf "${GREEN}user $APPUSER already exists. Skipping.\n${NC}"
else
  useradd -d /home/$APPUSER -m -G sudo -s /bin/bash -p "\$6\$MUqx/xpb7L4a1Yl2\$ClfzkoicrRyJsAiXRbLuG8NonKQI7cUgpwOhQr7QJnwt2mZkmQHDGisoBHiXfqzEM3DFscpHc6hDtMak1ff3H/" $APPUSER
  printf "${GREEN}\nDone. User $APPUSER added\n${NC}"
fi
grep -qxF "DenyUsers $APPUSER" /etc/ssh/sshd_config || echo "DenyUsers $APPUSER" >> /etc/ssh/sshd_config
echo "$APPUSER ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers
sleep $SLEEPTIME

printf "${GREEN}\n\n\nFinished. rebooting in $SLEEPTIME seconds...\n${NC}"
sleep $SLEEPTIME
reboot
