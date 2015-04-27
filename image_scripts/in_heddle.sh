#!/bin/bash
HERE="$(dirname "$0")"
tmpf="$(mktemp)"

append=
while getopts a: opt
do
  case $opt in
    a)
      append="$OPTARG"
      ;;
  esac
done
shift $((OPTIND-1))

(
while [ -f "$tmpf" ]; do
  sleep 1
done
cat
echo poweroff
) | "$HERE/kboot_heddle.sh" -s -a "heddle_serial_autologin=root heddle_serial_prompt=heddle_serial_autologin\n $append" "$@" | (
IFS=''
deleted=0
while read -r data; do
  data="$(echo "$data" | perl -pe 's/\e\[?.*?[\@-~]//g')"
  if [ "$data" = $'heddle_serial_autologin\r' ]; then
    if [ $deleted -eq 0 ]; then
      rm -f "$tmpf"
      deleted=1
    fi
    echo -n '$ '
  else
    echo "$data"
  fi
done
)
