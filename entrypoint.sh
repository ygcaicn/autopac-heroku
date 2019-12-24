#! /bin/bash

if [[ -z "${PAC_PATH}" ]]; then
  PAC_PATH="/autoproxy.pac"
fi
echo ${PAC_PATH}

if [[ -z "${PAC_PROXY}" ]]; then
  PAC_PROXY="SOCKS5 127.0.0.1:1080"
fi
echo ${PAC_PROXY}

cat <<-EOF > /user-rules.txt
${USER_RULE}
EOF
echo "user-rules"
cat /user-rules.txt


C_VER=`wget -qO- "https://api.github.com/repos/mholt/caddy/releases/latest" | grep 'tag_name' | cut -d\" -f4`
mkdir /caddybin
cd /caddybin
CADDY_URL="https://github.com/mholt/caddy/releases/download/$C_VER/caddy_${C_VER}_linux_amd64.tar.gz"
echo ${CADDY_URL}
wget --no-check-certificate -qO 'caddy.tar.gz' ${CADDY_URL}
tar xvf caddy.tar.gz
rm -rf caddy.tar.gz
chmod +x caddy

cd /wwwroot
tar xvf wwwroot.tar.gz
rm -rf wwwroot.tar.gz
mkdir -p "/wwwroot/${PAC_PATH}"

genpac --format=pac --pac-proxy="${PAC_PROXY}" --user-rule-from /user-rules.txt > "/wwwroot/${PAC_PATH}/index.txt"

cat <<-EOF > /genpac.sh
#! /bin/bash
genpac --format=pac --pac-proxy="${PAC_PROXY}" --user-rule-from /user-rules.txt > "/wwwroot/${PAC_PATH}/index.txt"
EOF
echo "0 0 * * * bash /genpac.sh" > /etc/crontabs/root

chmod +x /genpac.sh

cat <<-EOF > /caddybin/Caddyfile
http://0.0.0.0:${PORT}
{
	root /wwwroot
	index index.html index.txt
	timeouts none
  errors {
    404 404.html # Not Found
    500 50x.html # Internal Server Error
  }
}
EOF

crond

cd /caddybin
./caddy -conf="Caddyfile"