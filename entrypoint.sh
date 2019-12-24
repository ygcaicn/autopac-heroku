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

cat <<-EOF > /pac/user-rules.txt
${USER_RULE}
EOF
cat /pac/user-rules.txt


cd /wwwroot
tar xvf wwwroot.tar.gz
rm -rf wwwroot.tar.gz

mkdir -p /pac
cat <<-EOF > /pac/update_gfwlist.sh
#! /bin/bash
curl -o /pac/gfwlist.txt -L https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt
EOF
chmod +x /pac/update_gfwlist.sh
/pac/update_gfwlist.sh
echo "0 0 * * * bash /pac/update_gfwlist.sh" > /etc/crontabs/root

cat <<-EOF > /pac/cgi.sh
#! /bin/bash

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

echo "\$(genpac --format=pac --pac-proxy="\${PAC_PROXY}" \
      \${USER_RULE_opt} \
      --gfwlist-url=- \
      --user-rule-from /pac/user-rules.txt \
      --gfwlist-local=/pac/gfwlist.txt)"
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

crond


caddy -conf="/Caddyfile"