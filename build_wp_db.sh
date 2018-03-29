#!/bin/bash

# v2 will analyze source code of changed files

set -e

add_git_attrs()
{
  mkdir -p wordpress/wp-includes/
  ignore_file='wordpress/wp-includes/.gitignore'
  echo > "$ignore_file"
  echo 'IXR/*' >>  "$ignore_file"
  echo 'Text/*' >>  "$ignore_file"
  echo 'pomo/*' >>  "$ignore_file"
  echo 'ID3/*' >>  "$ignore_file"
  echo 'SimplePie/*' >>  "$ignore_file"
}

verify_changes()
{
  local changes="$1"
  local prefx="$2"

  echo functions: >> "${here}/data/apis.vspec"
  echo $IFS
  IFS=$'\n'
  for change in ${changes[*]}
  do
    operator="${change:0:1}"
    method="${change:2}"

    if [ "$method" == "" ]
    then
      continue
    fi

    if [ $operator == '-' ]
    then
      if !(grep -r --include \*.php "function $method")
      then
        echo "$change" >> "${here}/data/apis.vspec"
      fi

    else
      if !(git --no-pager grep "function $method(" $(git rev-parse HEAD^1) -- '*.php' > /dev/null)
      then
        echo "$change" >> "${here}/data/apis.vspec"
      fi
    fi
  done
  IFS=' '
}

download_wp()
{
  local here=$(pwd)

  echo "[i] Downloading all the WP versions"

  # @todo limit versions that are downloaded
  readonly all_downloads=$(curl -s  https://wordpress.org/download/release-archive/ | sed 's/href/\n/g' | grep ".zip'" | grep -v 'mu-\|RC\|beta\|IIS' | cut -d"'" -f2 | head -n-30 | tac)
  readonly total_versions=$(echo "$all_downloads" | wc -l)

  echo "[i] There are [$total_versions] possible versions"

  mkdir -p downloads

  # @todo parallelize
  counter=0
  local download_list=()

  for dl in $all_downloads
  do
    counter=$((counter + 1))
    filename=$(basename $dl)
    prefix=$(printf "%05d" $counter)
    
    if [ ! -f "downloads/${prefix}-${filename}" ]
    then
      download_list+=("curl -s -o downloads/${prefix}-${filename} $dl")
      echo "[i] Adding to download queue ${prefix}-${filename}"
    fi
  done
  ( IFS=$'\n'; echo "${download_list[*]}" | xargs -P10 -r -I{} sh -c "{}")
}

add_wordpress_package()
{ 
  local file="$1"
  unzip -oq "$file"
  add_git_attrs
  pushd $(pwd) > /dev/null
  cd wordpress
  version=$(cat wp-includes/version.php | grep '$wp_version =' | cut -d"'" -f2)
  echo $version
  git add . > /dev/null
  git commit -m "$version" > /dev/null
}

main()
{

 local here=$(pwd)
 mkdir -p "$here/{data,diffs,wordpress,downloads}"
 download_wp

if [ -d "wordpress/.git" ]
then
  echo 'Killing old git history'
  rm -rf "wordpress/.git"
fi

readonly files=$(ls downloads/*-wordpress*.zip | sed 's/ /\n/g' | sort -V)


rm -rf "wordpress/*"
mkdir -p "wordpress"
mkdir -p diffs

git init "wordpress"
add_git_attrs

echo '' > "${here}/data/wordpress.vspec"
echo '' > "${here}/data/apis.vspec"

for f in $files
do
  add_wordpress_package "$f"

  set +e
  echo "v: $version" >> "${here}/data/wordpress.vspec"
  echo "v: $version" >> "${here}/data/apis.vspec"
  
  git --no-pager diff --diff-filter=d --name-only | egrep '[js|txt|md|css]$' \
    | xargs -I{} md5sum {} \
    | tr -s ' ' >> "${here}/data/wordpress.vspec"

  diff_temp="$here/diffs/diff-for-$version.txt"
  touch "$diff_temp"
  echo > "$diff_temp"
  echo $diff_temp
  
  git --no-pager diff --name-only   HEAD^1 HEAD -- '*.php' ':!wp-content' \
    | xargs -I{} git diff HEAD^1 HEAD  {} >> "$diff_temp"

  changed_methods=$(cat "$diff_temp" | egrep '^[-+]' | grep -v 'public \|private ' \
    | awk '{$1=$1};1' | egrep '^[\+\-]\s?function' \
    | sed 's/(.*//g;s/function//;s/&//g' | tr -s ' ' \
    | sort -k2 | uniq -f1 -u)

  verify_changes "$changed_methods"
      
  echo  >> "${here}/data/apis.vspec"
  if [ "$version" == "9.7" ]
  then
    exit
  fi

  #echo actions: >> "${here}/apis.vspec"
  changed_actions=$(cat "$diff_temp" | egrep '^[-+]' | grep 'do_action(' | sed 's/do_action(//g' \
    | grep -v ' function ' | awk '{$1=$1};1' | cut -d',' -f1 \
    | sed 's/);.*//' | sort -k2 | uniq -f1 -u)
  # echo  >> "${here}/apis.vspec"


  # echo filters >> "${here}/apis.vspec"
  changed_filters=$(cat "$diff_temp"  | egrep '^[-+]' | grep 'apply_filter' \
    | awk '{$1=$1};1' | egrep -v '^[+-] \*' | sed -e 's/\([-+]\).*apply_filter/\1 apply_filter/g'  \
    | cut -d',' -f1 | cut -d' ' -f1,3 | sort -k2 | uniq -f1 -u)
  # echo  >> "${here}/apis.vspec"

  set -e
  echo >> "${here}/data/wordpress.vspec"
  popd > /dev/null

  # rm $diff_temp
done

# @todo find different file extensions

# pushd $(pwd) > /dev/null
# cd "wordpress"
}

main