#! /bin/bash
if [[ -e /pac/gfwlist.txt.tmp ]]; then
  return 1
fi
touch /pac/gfwlist.txt.tmp
curl -o /pac/gfwlist.txt.tmp -L https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt
touch /pac/gfwlist.txt
old_hash=$(cat "/pac/gfwlist.txt" | sha256sum | awk '{print $1}')
new_hash=$(cat "/pac/gfwlist.txt.tmp" | sha256sum | awk '{print $1}')
if [[ "${old_hash}" == "${new_hash}" ]]; then
  sed -i -r -e "s/(Check:).*/\1 $(date '+%Y-%m-%d %H:%M:%S')/g" /pac/update.log
else
  rm -rf /pac/cache/*
  if [[ $(du -s /pac/gfwlist.txt.tmp | awk '{print $1}') -gt 150 ]]; then
    cat /pac/gfwlist.txt.tmp > /pac/gfwlist.txt
    echo "/**" > /pac/update.log
    echo " * repository: https://github.com/ygcaicn/autopac-heroku" >> /pac/update.log
    echo " * /pac/gfwlist.txt Last-Modified: $(date '+%Y-%m-%d %H:%M:%S')" >> /pac/update.log
    echo " * /pac/gfwlist.txt Check: $(date '+%Y-%m-%d %H:%M:%S')" >> /pac/update.log
    echo "*/" >> /pac/update.log
    echo "" >> /pac/update.log
  fi
fi
rm -rf /pac/gfwlist.txt.tmp
