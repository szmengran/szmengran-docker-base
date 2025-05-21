#!/bin/bash

set -x

#set +e
#if [[ "$APP_PORT" == "8080" ]]; then
#  shell/api-offline.sh
#elif [[ "$APP_PORT" == "9090" ]]; then
#  shell/provider-offline.sh
# else
  # shell/api-offline.sh
  # shell/provider-offline.sh
#fi
#set -e

pkill java
