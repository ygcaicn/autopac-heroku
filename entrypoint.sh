#!/bin/bash
chmod +x /proccgi.sh

if [[ -z "${PAC_PATH}" ]]; then
  PAC_PATH="/autoproxy.pac"
fi
echo ${PAC_PATH}

if [[ -z "${PAC_PROXY}" ]]; then
  PAC_PROXY="SOCKS5 127.0.0.1:1080"
fi
echo ${PAC_PROXY}
cat <<-EOF > /pac/proxy.txt
${PAC_PROXY}
EOF

echo -e ${USER_RULE}

cat <<-EOF > /pac/user-rules.txt
${USER_RULE}
EOF
cat /pac/user-rules.txt
mkdir -p /pac/cache

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

/pac/update_gfwlist.sh > /dev/null 2>&1 &
caddy -conf="/Caddyfile"