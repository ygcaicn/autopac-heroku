FROM alpine:latest

COPY wwwroot.tar.gz /wwwroot/wwwroot.tar.gz
COPY entrypoint.sh /entrypoint.sh

RUN apk update \
        && apk upgrade \
        && apk add --no-cache bash \
        && apk add --no-cache python3 \
        && apk add --no-cache curl \
        && pip3 install --upgrade pip \
        && pip install -U genpac \
        && rm -rf /var/cache/apk/* \
        && curl -o /proccgi.sh http://www.fpx.de/fp/Software/proccgi.sh \
        && curl https://getcaddy.com | bash -s personal http.cgi \
        && chmod +x /entrypoint.sh \
        && chmod +x /proccgi.sh

CMD '/entrypoint.sh'
