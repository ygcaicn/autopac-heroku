#! /bin/bash

if [[ -z "${PAC_PATH}" ]]; then
  PAC_PATH="/autoproxy.pac"
fi
echo ${PAC_PATH}

if [[ -z "${PAC_PROXY}" ]]; then
  PAC_PROXY="SOCKS5 127.0.0.1:1080"
fi
echo ${PAC_PROXY}

echo -e ${USER_RULE}

mkdir -p /pac/cache

cat <<-EOF > /pac/user-rules.txt
${USER_RULE}
EOF
cat /pac/user-rules.txt


cd /wwwroot
tar xvf wwwroot.tar.gz
rm -rf wwwroot.tar.gz


cat <<-EOF > /pac/update_gfwlist.sh
#! /bin/bash
if [[ -e /pac/gfwlist.txt.tmp ]]; then
  return 1
fi
touch /pac/gfwlist.txt.tmp
curl -o /pac/gfwlist.txt.tmp -L https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt
touch /pac/gfwlist.txt
old_hash=\$(cat "/pac/gfwlist.txt" | sha256sum | awk '{print \$1}')
new_hash=\$(cat "/pac/gfwlist.txt.tmp" | sha256sum | awk '{print \$1}')
if [[ "\${old_hash}" == "\${new_hash}" ]]; then
  sed -i -r -e "s/(Check:).*/\1 \$(date '+%Y-%m-%d %H:%M:%S')/g" /pac/update.log
else
  rm -rf /pac/cache/*
  if [[ \$(du -s /pac/gfwlist.txt.tmp | awk '{print \$1}') -gt 150 ]]; then
    cat /pac/gfwlist.txt.tmp > /pac/gfwlist.txt
    echo "/**" > /pac/update.log
    echo " * repository: https://github.com/ygcaicn/autopac-heroku" >> /pac/update.log
    echo " * /pac/gfwlist.txt Last-Modified: \$(date '+%Y-%m-%d %H:%M:%S')" >> /pac/update.log
    echo " * /pac/gfwlist.txt Check: \$(date '+%Y-%m-%d %H:%M:%S')" >> /pac/update.log
    echo "*/" >> /pac/update.log
    echo "" >> /pac/update.log
  fi
fi
rm -rf /pac/gfwlist.txt.tmp
EOF

chmod +x /pac/update_gfwlist.sh
/pac/update_gfwlist.sh
#echo "* * * * * bash /pac/update_gfwlist.sh > /dev/null 2>&1" >> /etc/crontabs/root

cat <<-EOF > /pac/cgi.sh
#! /bin/bash
clean_cache(){
  MAX_SIZE=20000 #KB
  MAX_FILES=100
  MAX_TIME=10 #Days
  pushd \$1
  size=\$(du -s \$1 |awk '{print \$1}')
  if [[ \$size -gt \${MAX_SIZE} ]]; then
    until [ \$size -lt \${MAX_SIZE} ];
    do
      rm -rf \$(ls -rt | head -n1) ;
      size=\$(du -s \$1 |awk '{print $1}') ;
    done
  fi

  if [ \$(ls -1t | wc -l) -gt \${MAX_FILES} ]; then
      let del_num=\$(ls -1t | wc -l)-MAX_FILES
      rm -r \$(ls -rt | head -n \${del_num})
  fi

  find . -type f -mtime +\${MAX_TIME} -exec rm -rf {} \;

  popd
  return 0
}
update_gfwlist(){
  last=\$(cat /pac/update.log | grep Check | grep -o -E [0-9]+-[0-9]+-.*)
  last_t=\$(date -d "\$last" +%s)
  #now=\$(date -d "-1 day" '+%Y-%m-%d %H:%M:%S')
  now=\$(date -d "-1 day" '+%s')
  if [[ \$last_t -lt \$now ]]; then
    /pac/update_gfwlist.sh > /dev/null 2>&1 &
  fi
  return 0
}

printf "Content-type: text/plain\n\n"

eval \`/proccgi.sh $*\`
if [[ -n "\${FORM_u}" ]]; then
  USER_RULE_opt="--user-rule="\${FORM_u}""
fi

PAC_PROXY="${PAC_PROXY}"
if [[ -n "\${FORM_pac_proxy}" ]]; then
  PAC_PROXY="SOCKS5 \${FORM_pac_proxy}"
fi

if ! [[ -e "/pac/gfwlist.txt" ]]; then
  echo /pac/gfwlist.txt Not found！
  exit 404
fi

req_hash=\$(echo "\${FORM_u}&\${FORM_pac_proxy}" | sha256sum | awk '{print \$1}')
if ! [[ -e "/pac/cache/\${req_hash}" ]]; then
  clean_cache /pac/cache > /dev/null 2>&1
  echo "\$(genpac --format=pac --pac-proxy="\${PAC_PROXY}" \
        \${USER_RULE_opt} \
        --gfwlist-url=- \
        --user-rule-from /pac/user-rules.txt \
        --gfwlist-local=/pac/gfwlist.txt)" \
        > /pac/cache/\${req_hash}
  
fi

if [[ -e "/pac/cache/\${req_hash}" ]] && [[ -e "/pac/update.log" ]] ; then
  update_gfwlist
  cat /pac/update.log
  cat /pac/cache/\${req_hash}
fi

exit 0
EOF

chmod +x /pac/cgi.sh


cat <<-EOF > /Caddyfile
http://0.0.0.0:${PORT}
{
	root /wwwroot
	index index.html index.txt
  cgi ${PAC_PATH} /pac/cgi.sh
	timeouts none
  errors {
    404 404.html # Not Found
    500 50x.html # Internal Server Error
  }
}
EOF

#crond


caddy -conf="/Caddyfile"