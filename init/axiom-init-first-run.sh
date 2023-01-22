#!/bin/bash
SLEEPTIME=3

GREEN='\033[0;32m'
NC='\033[0m'

echo "Cjg4OGIgICAgIGQ4ODggIGQ4YiAgICAgICAgICA4ODggICAgICAgICAgZDhiICAgICAgICAgCjg4ODhiICAgZDg4ODggIFk4UCAgICAgICAgICA4ODggICAgICAgICAgWThQICAgICAgICAgCjg4ODg4Yi5kODg4ODggICAgICAgICAgICAgICA4ODggICAgICAgICAgICAgICAgICAgICAgCjg4OFk4ODg4OFA4ODggODg4OCAgLmQ4OGIuICA4ODggODg4ODhiLiAgODg4IDg4OGQ4ODggCjg4OCBZODg4UCA4ODggIjg4OCBkODgiIjg4YiA4ODggODg4ICI4OGIgODg4IDg4OFAiICAgCjg4OCAgWThQICA4ODggIDg4OCA4ODggIDg4OCA4ODggODg4ICA4ODggODg4IDg4OCAgICAgCjg4OCAgICIgICA4ODggIDg4OCBZODguLjg4UCA4ODggODg4ICA4ODggODg4IDg4OCAgICAgCjg4OCAgICAgICA4ODggIDg4OCAgIlk4OFAiICA4ODggODg4ICA4ODggODg4IDg4OCAgICAgCiAgICAgICAgICAgICAgIDg4OCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgZDg4UCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgIDg4OFAiCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAooIkJ1dCBmaW5lc3Qgb2YgdGhlbSBhbGwsIFRoZSBDcnVzaGVyIGl0IGlzIGNhbGxlZDogTWrDtmxuaXIhIEhhbW1lciBvZiBUaG9yISIp" | base64 -d
printf "\n\n"
printf "${GREEN}Configuring axiom for the very first time...\n${NC}"
sleep $SLEEPTIME

usage() { echo "Usage: $0 -e <dev|prod> -t <digital ocean API token>" 1>&2; exit 0; }

while getopts ":e:t:" flags; do
  case "${flags}" in
    e)
      env=${OPTARG}
      ;;
    t)
      do_token=${OPTARG}
      ;;
    *)
      usage
      ;;
  esac
done
shift $((OPTIND-1))
if [ -z "${env}" ] || [ -z "${do_token}" ]; then
        usage
fi
if [[ "${env}" != "dev" ]] && [[ "${env}" != "prod" ]]; then
  usage
fi

AXIOM_PATH="$HOME/.axiom"
#DigitalOcean config stuff for DEV environment
DIGOCN_API_TOKEN="${do_token}" #WARNING! WE SHOULD REPLACE THIS WITH DOPPLER OR ANY OTHER SECRETS MANAGER!
if [[ "${env}" == "dev" ]]; then
  DIGOCN_DFLT_REGION="fra1"
  DIGOCN_DFLT_DROPLETSIZE="s-1vcpu-512mb-10gb"
else
  DIGOCN_DFLT_REGION="lon1"
  DIGOCN_DFLT_DROPLETSIZE="s-4vcpu-8gb"
fi

printf "\n\n\n${GREEN}${env} environment was selected.\n\tDefault DigitalOcean region: ${DIGOCN_DFLT_REGION};\n\tDefault droplet size: ${DIGOCN_DFLT_DROPLETSIZE}\n${NC}\n"
sleep $SLEEPTIME

OP_PWD=$(cat /dev/urandom | tr -dc '[:alpha:]' | fold -w ${1:-96} | head -n 1)
GOLDEN_IMAGE_NAME="axiom-goldenimage-${env}-$(cat /proc/sys/kernel/random/uuid)"

#create a new SSH key to embed on the golden image (force overwite if other key already exists)
printf "${GREEN}\n\n\n*****************************\n"
printf "Creating a new SSH key to embed on the golden image\n"
printf "*****************************\n\n${NC}"
KEYFILE="axiom_${env}key"
echo -e "y\n" | ssh-keygen -t ed25519 -C "axiom-${env}-$(date +%Y%m%d_%H%M%S)" -f "$HOME/.ssh/${KEYFILE}" -N ""
printf "${GREEN}\nDone. SSH key stored in $HOME/.ssh/${KEYFILE}\n${NC}"
sleep $SLEEPTIME

AXIOM_CONFIG="{\"do_key\":\"${DIGOCN_API_TOKEN}\",\"region\":\"${DIGOCN_DFLT_REGION}\",\"provider\":\"do\",\"default_size\":\"${DIGOCN_DFLT_DROPLETSIZE}\",\"appliance_name\":\"\",\"appliance_key\":\"\",\"appliance_url\":\"\",\"email\":\"\",\"sshkey\":\"${KEYFILE}\",\"op\":\"${OP_PWD}\",\"imageid\":\"${GOLDEN_IMAGE_NAME}\",\"provisioner\":\"default\"}"
AXIOM_PROFILE_NAME="axiom_conf_${env}"
AXIOM_CONFIG_OUTPUT_FILE="${AXIOM_PATH}/accounts/${AXIOM_PROFILE_NAME}.json"

printf "${GREEN}\n\n\n*****************************\n"
printf "Executing axiom-configure\n"
printf "*****************************\n\n${NC}"
rm -f "${AXIOM_PATH}/axiom.json"
curl -fsSL https://raw.githubusercontent.com/pry0cc/axiom/master/interact/axiom-configure | bash -s -- --shell bash --unattended --config ${AXIOM_CONFIG}
#copy profile config to correct folder and meaningful name
rm -f ${AXIOM_PATH}/accounts/*
cp "${AXIOM_PATH}/axiom.json" "${AXIOM_CONFIG_OUTPUT_FILE}"
printf "${GREEN}\nDone. Account configuration stored in ${AXIOM_CONFIG_OUTPUT_FILE}\n${NC}"
sleep $SLEEPTIME

printf "${GREEN}\n\n\n*****************************\n"
printf "Installing doctl\n"
printf "*****************************\n\n${NC}"
#install doctl while https://github.com/pry0cc/axiom/issues/672 is not fixed
wget -O /tmp/doctl.tar.gz https://github.com/digitalocean/doctl/releases/download/v1.66.0/doctl-1.66.0-linux-amd64.tar.gz && tar -xvzf /tmp/doctl.tar.gz && sudo mv doctl /usr/bin/doctl && rm /tmp/doctl.tar.gz
printf "${GREEN}\nDone. doctl installed.\n${NC}"
sleep $SLEEPTIME

printf "'op' user password is: ${OP_PWD}\n"
printf "SSH key to access axiom boxes stored in ~/.ssh/${KEYFILE}\n"
printf "WARNING: YOU MAY WANT TO SAVE THE PASSWORD AND SSH PRIVATE KEY IF YOU WANT TO ACCESS AXIOM BOXES!!!!\n"

printf "\nConfig file stored in ${AXIOM_CONFIG_OUTPUT_FILE}\n"

printf "Finishing configuring and enabling this account...\n${NC}"
sleep $SLEEPTIME

printf "${GREEN}\n\n\n*****************************\n"
printf "Executing axiom-account\n"
printf "*****************************\n\n${NC}"
bash ${AXIOM_PATH}/interact/axiom-account ${AXIOM_PROFILE_NAME}

printf "${GREEN}\n\n\n'op' user password is: ${OP_PWD}\n"
printf "SSH key to access axiom boxes stored in ~/.ssh/${KEYFILE}\n"
printf "WARNING: YOU MAY WANT TO SAVE THE PASSWORD AND SSH PRIVATE KEY IF YOU WANT TO ACCESS AXIOM BOXES!!!!\n${NC}"
