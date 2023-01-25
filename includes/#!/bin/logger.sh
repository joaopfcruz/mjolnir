#!/bin/bash

RED="\033[0;31m"
ORANGE="\033[0;33m"
GREEN="\033[0;32m"
NC="\033[0m"

log_info(){
  printf "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] [mjolnir] [INFO] $1\n${NC}"
}

log_warn(){
  printf "${ORANGE}[$(date '+%Y-%m-%d %H:%M:%S')] [mjolnir] [WARN] $1\n${NC}"
}

log_err(){
  printf "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] [mjolnir] [ERROR] $1\n${NC}"
}
