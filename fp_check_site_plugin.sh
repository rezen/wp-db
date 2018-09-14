#!/bin/bash

set -euo pipefail

readonly here=$(pwd)
readonly url="${1:-}"
readonly plugin="${2:-events-manager}"
readonly plugin_dir='/wp-content/plugins'
readonly user_agent='User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/44.0.2403.89 Safari/537.36'

if [ ! -f "${plugin}.list" ]
then
   (>&2 echo '[!] You need to build the dictionary for the plugin')
  exit 1
fi

status_code=$(curl -H "${user_agent}" -sw "%{http_code}" "${url}" --output /dev/null)

if [ "$status_code" != '200' ]
  then
    (>&2 echo '[!] That site does not appear to work')
    exit 2
  fi

readonly files=$(cat "${plugin}.list" | grep -v 'i18')
readonly tmpfile=$(mktemp)

counter=0

for file in $files
do
  if [[ "$counter" -gt 40 ]]
  then
    (>&2 echo '[!] Too many consecutive bad requests')
    exit 3
  fi

  status_code=$(curl -H "${user_agent}" -sw "%{http_code}" "${url}/${plugin_dir}/${plugin}/${file}" --output "${tmpfile}")

  if [ "$status_code" != '200' ]
  then
    counter=$((counter+1))
    (>&2 echo "[!] No luck with $file")
    continue
  fi
   
  fingerprint=$(md5sum "$tmpfile" | cut -d' ' -f1)
  echo "${fingerprint} ${file}"
  counter=0
done


