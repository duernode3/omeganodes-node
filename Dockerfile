# Route B — multi-stage: official xray image -> Alpine + Node front
# The Node front (server.js) listens on $PORT, serves the honest status
# page at / (www/index.html), and proxies WebSocket upgrades to xray on
# loopback (127.0.0.1:10000). xray's own inbound "fallbacks" cannot serve
# a page to a browser: for a WS inbound the WS handler answers 404 for
# any non-WebSocket HTTP request before fallback is consulted (verified
# locally 2026-11-25 against xray 26.11.9 — nothing ever reached the
# fallback server), so the front is required for a visible interface.
#
# Build:  docker build -t xray-vless-ws .
# Run:    docker run -e PORT=8080 -e UUID=<uuid> -e WS_PATH=/ws -p 8080:8080 xray-vless-ws
# The xray binary is pre-seeded at /tmp/xray-core/xray, so the front
# never downloads it at runtime; adm-zip is only needed for the
# download fallback, so no npm install is required at image build time.
# If the ghcr tag/path changes on a platform, pin XRAY_IMAGE to a known tag.

ARG XRAY_IMAGE=ghcr.io/xtls/xray-core:latest
FROM ${XRAY_IMAGE} AS xray-src

FROM alpine:3.21
RUN apk add --no-cache ca-certificates tzdata nodejs \
 && adduser -D -H xray 2>/dev/null || true
COPY --from=xray-src /usr/local/bin/xray /tmp/xray-core/xray
COPY entrypoint.sh /app/entrypoint.sh
COPY server.js package.json /app/
COPY www/ /app/www/
RUN chmod +x /tmp/xray-core/xray /app/entrypoint.sh
WORKDIR /app
# PORT is NOT baked in; platforms inject it at runtime. 8080 is only a
# local default used by the front when PORT is unset.
EXPOSE 8080
ENV XRAY_BIN=/tmp/xray-core/xray \
    XRAY_CONFIG=/tmp/config.json
ENTRYPOINT ["node", "server.js"]
