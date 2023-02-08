#!/bin/bash

source "$MJOLNIR_PATH/includes/vars.sh"

log_info(){
  printf "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] [mjolnir] [$2] [INFO] $1\n${NC}"
}

log_warn(){
  printf "${ORANGE}[$(date '+%Y-%m-%d %H:%M:%S')] [mjolnir] [$2] [WARN] $1\n${NC}"
}

log_err(){
  printf "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] [mjolnir] [$2] [ERROR] $1\n${NC}" >&2
