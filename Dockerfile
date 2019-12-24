FROM alpine:latest

COPY wwwroot.tar.gz /wwwroot/wwwroot.tar.gz
COPY entrypoint.sh /entrypoint.sh

RUN apk update \
        && apk upgrade \
        && apk add --no-cache bash \
        && apk add --no-cache python3 \
        && pip3 install --upgrade pip \
        && pip install -U genpac \
        && rm -rf /var/cache/apk/* \
        && chmod +x /entrypoint.sh

CMD '/entrypoint.sh'
