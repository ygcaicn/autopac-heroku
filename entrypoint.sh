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

mkdir -p /pac
cat <<-EOF > /pac/update_gfwlist.sh
#! /bin/bash
curl -o /pac/gfwlist.txt -L https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt
EOF
chmod +x /pac/update_gfwlist.sh
/pac/update_gfwlist.sh
echo "0 0 * * * bash /pac/update_gfwlist.sh" > /etc/crontabs/root
genpac --format=pac --pac-proxy="${PAC_PROXY}" --user-rule-from /user-rules.txt > "/wwwroot/${PAC_PATH}/index.txt"

cat <<-EOF > /pac/cgi.sh
#! /bin/bash
genpac --format=pac --pac-proxy="${PAC_PROXY}" --user-rule-from /user-rules.txt > "/wwwroot/${PAC_PATH}/index.txt"
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