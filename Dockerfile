FROM alpine:latest

RUN apk update \
        && apk upgrade \
        && apk add --no-cache bash \
           python3 curl coreutils \
        && pip3 install --upgrade pip \
        && pip install -U genpac \
        && rm -rf /var/cache/apk/* \
        && curl -o /proccgi.sh http://www.fpx.de/fp/Software/proccgi.sh \
        && curl https://getcaddy.com | bash -s personal http.cgi


ADD wwwroot.tar.gz /wwwroot/
COPY pac /pac
COPY entrypoint.sh /entrypoint.sh

CMD '/entrypoint.sh'
