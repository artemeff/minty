FROM alpine:3.10.3

ENV auth=

RUN apk add --no-cache tinyproxy \
 && mkdir -p /home/var/log/tinyproxy \
 && mkdir -p /home/var/run/tinyproxy

WORKDIR /home

COPY ./tinyproxy.conf /home/etc/tinyproxy/tinyproxy.conf
COPY ./tinyproxy_auth.conf /home/etc/tinyproxy/tinyproxy_auth.conf

CMD trap 'exit 0' SIGTERM \
  ; if [ "x$auth" = "x" ]; then CONFIG=tinyproxy; else CONFIG=tinyproxy_auth; fi \
  ; echo "config=${CONFIG}" \
  ; tinyproxy -d -c /home/etc/tinyproxy/${CONFIG}.conf
