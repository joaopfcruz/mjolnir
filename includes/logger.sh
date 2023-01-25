#!/bin/bash

source "$MJOLNIR_PATH/includes/vars.sh"

log_info(){
  printf "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] [mjolnir] [INFO] $1\n${NC}"
}

log_warn(){
  printf "${ORANGE}[$(date '+%Y-%m-%d %H:%M:%S')] [mjolnir] [WARN] $1\n${NC}"
}

log_err(){
  printf "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] [mjolnir] [ERROR] $1\n${NC}" >&2
}
