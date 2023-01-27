#!/bin/bash

source "$MJOLNIR_PATH/includes/vars.sh"
source "$MJOLNIR_PATH/includes/logger.sh"

#$1=organization name
#$2=supermodule output subfolder (e.g, recon, scan, exploit)
setup_output_folders(){
  if ! [ -d "${MJOLNIR_OUT_FOLDER_PATH}" ]; then
    log_warn "\"${MJOLNIR_OUT_FOLDER_PATH}\" does not exist. Creating."
    mkdir "${MJOLNIR_OUT_FOLDER_PATH}"
  fi

  output_org_folder="${MJOLNIR_OUT_FOLDER_PATH}/$1"
  if ! [ -d "${output_org_folder}" ]; then
    log_warn "\"${output_org_folder}\" does not exist. Creating."
    mkdir "${output_org_folder}"
  fi

  output_org_supermodule_folder="${output_org_folder}/$2"
  if ! [ -d "${output_org_supermodule_folder}" ]; then
    log_warn "\"${output_org_supermodule_folder}\" does not exist. Creating."
    mkdir "${output_org_supermodule_folder}"
  fi
}
