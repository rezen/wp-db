#!/bin/bash

set -euo pipefail

readonly plugin="${1:-events-manager}"
readonly revisions="${2:-}"
readonly here=$(pwd)

echo "[i] Downloading [$plugin] with [$revisions] revisions"

readonly all_downloads=$(curl -s --fail "https://api.wordpress.org/plugins/info/1.0/${plugin}/" | grep '//downloads' | sed 's/;/\n/g' | grep 'https://download' | cut -d'"' -f2)
readonly total_versions=$(echo "$all_downloads" | wc -l)

if [ -z "$all_downloads" ]
then
  echo '[!] This does not seem to be a valid plugin'
  exit 1
fi

if [ -z "$revisions" ]
then
  readonly downloads=$(echo "$all_downloads")
else 
  readonly downloads=$(echo "$all_downloads" | tail -n"${revisions}")
fi

echo "[i] There are [$total_versions] possible versions"

# @todo parallelize
for dl in $downloads
do
  filename=$(basename $dl)
  if [ ! -f "${filename}" ]
  then
    echo "[i] Downloading $filename"
    curl -s -O "$dl"
  fi
done

if [ -f "$plugin.zip" ]
then
  rm "$plugin.zip"
fi

if [ -d "$plugin/.git" ]
then
  echo 'Killing old git history'
  rm -rf "$plugin/.git"
fi


readonly files=$(ls ${plugin}*.zip | sed 's/ /\n/g' | sort -V)

mkdir -p "$plugin"
git init "$plugin"

echo '' > "${here}/${plugin}.vspec"

for f in $files
do
  version="${f/$plugin./}"
  version="${version/.zip/}"
  
  rm -rf "${plugin}/*"
  unzip -oq "$f"
  pushd $(pwd) > /dev/null
  cd "$plugin"
 
  git add . > /dev/null
  set +e
  echo "v: $version" >> "${here}/${plugin}.vspec"
  git --no-pager diff --diff-filter=d --name-only --cached | egrep '[js|txt|md|css]$' | xargs -I{} md5sum {} | tr -s ' ' >> "${here}/${plugin}.vspec"
  set -e
  echo >> "${here}/${plugin}.vspec"
  git commit -m "$version" > /dev/null
  popd > /dev/null
done

pushd $(pwd) > /dev/null
cd "$plugin"

readonly static_current=$(find  -type f \( -name '*.js' -o -name '*.css' -o -name '*.md' -o -name '*.txt' \) -printf "%d %p\n" | sort -n | cut -d' ' -f2)

echo '' > "${here}/${plugin}.list"
echo "${static_current//.\//}" >> "${here}/${plugin}.list"

exit
