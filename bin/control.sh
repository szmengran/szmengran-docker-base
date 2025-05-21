#!/bin/bash

if [ $# != 2 ]
then
  echo "Miss arg! usage: control.sh [http|dubbo] [online|offline]"
  exit 1
fi

echo "$2 $POD_NAME ..."

if [[ "$1" == "http" ]]; then
  shell/api-$2.sh
elif [[ "$1" == "dubbo" ]]; then
  shell/provider-$2.sh
else
  echo "usage: control.sh [http|dubbo] [online|offline]"
  exit 2
fi



