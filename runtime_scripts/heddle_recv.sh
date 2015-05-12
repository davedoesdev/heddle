#!/bin/bash
stty -echo
IFS=':'
echo recv_heddle
let i=0
prev=
outf=./__in_heddle.sh
rm -f "$outf"
touch "$outf"
chmod +x "$outf"
while true; do
  if read -r n h data; then
    #echo "READ: $n:$h:$data" 1>&2
    if [ "$n" = "$i" -o "$n" = "${i}F" ]; then
      sum="$(echo "$n:$data" | md5sum | awk '{print $1}')"
      if [ "$sum" = "$h" ]; then
        tmp="$(mktemp)"
        echo "$data" | base64 -d > "$tmp"
        len="$(stat -c %s "$tmp")"
        cat "$tmp" >> "$outf"
        rm -f "$tmp"
        prev="$n:$(echo "$n:$len" | md5sum | awk '{print $1}'):$len"
        echo "$prev"
        #echo "SENT: $prev" 1>&2
        if [ "$n" = "${i}F" ]; then
          "$outf"
          echo "heddle_status:$?"
          rm -f "$outf"
          exec reboot
        else
          let i+=1
        fi
      fi
    elif [ -n "$prev" ]; then
      echo "$prev"
      #echo "SENT: $prev" 1>&2
    fi   
  fi
done
