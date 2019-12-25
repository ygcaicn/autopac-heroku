#!/bin/bash
PAC_PROXY=$(cat /pac/proxy.txt)
if [[ -z "${PAC_PROXY}" ]]; then
  PAC_PROXY="SOCKS5 127.0.0.1:1080"
fi

clean_cache(){
  MAX_SIZE=20000 #KB
  MAX_FILES=100
  MAX_TIME=10 #Days
  pushd $1
  size=$(du -s $1 |awk '{print $1}')
  if [[ $size -gt ${MAX_SIZE} ]]; then
    until [ $size -lt ${MAX_SIZE} ];
    do
      rm -rf $(ls -rt | head -n1) ;
      size=$(du -s $1 |awk '{print }') ;
    done
  fi

  if [ $(ls -1t | wc -l) -gt ${MAX_FILES} ]; then
      let del_num=$(ls -1t | wc -l)-MAX_FILES
      rm -r $(ls -rt | head -n ${del_num})
  fi

  find . -type f -mtime +${MAX_TIME} -exec rm -rf {} \;

  popd
  return 0
}
update_gfwlist(){
  if ! [[ -e "/pac/gfwlist.txt" ]];then
    /pac/update_gfwlist.sh > /dev/null 2>&1
  fi

  last=$(cat /pac/update.log | grep Check | grep -o -E [0-9]+-[0-9]+-.*)
  last_t=$(date -d "$last" +%s)
  #now=$(date -d "-1 day" '+%Y-%m-%d %H:%M:%S')
  now=$(date -d "-1 day" '+%s')
  if [[ $last_t -lt $now ]]; then
    /pac/update_gfwlist.sh > /dev/null 2>&1 &
  fi
  return 0
}

printf "Content-type: text/plain\n\n"

eval `/proccgi.sh $*`


if [[ -n "${FORM_u}" ]]; then
  USER_RULE_opt="--user-rule="${FORM_u}""
fi

if [[ -n "${FORM_pac_proxy}" ]]; then
  PAC_PROXY="SOCKS5 ${FORM_pac_proxy}"
fi

req_hash=$(echo "${FORM_u}&${FORM_pac_proxy}" | sha256sum | awk '{print $1}')
if ! [[ -e "/pac/cache/${req_hash}" ]]; then
  update_gfwlist
  clean_cache /pac/cache > /dev/null 2>&1
  if ! [[ -e "/pac/gfwlist.txt" ]]; then
    echo /pac/gfwlist.txt Not found!
    exit 404
  fi
  echo "$(genpac --format=pac --pac-proxy="${PAC_PROXY}" \
          ${USER_RULE_opt} \
          --gfwlist-url=- \
          --user-rule-from /pac/user-rules.txt \
          --gfwlist-local=/pac/gfwlist.txt)"\
          > /pac/cache/${req_hash}
fi

if [[ -e "/pac/cache/${req_hash}" ]] && [[ -e "/pac/update.log" ]] ; then
  cat /pac/update.log
  cat /pac/cache/${req_hash}
fi

exit 0
