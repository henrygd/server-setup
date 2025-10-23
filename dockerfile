ARG CADDY_VERSION=2
FROM caddy:${CADDY_VERSION}-builder AS builder

RUN XCADDY_GO_BUILD_FLAGS="-ldflags '-w -s'" xcaddy build \
  --with github.com/lucaslorentz/caddy-docker-proxy/v2 \
  --with github.com/WeidiDeng/caddy-cloudflare-ip \
  --with github.com/caddyserver/transform-encoder \
  --with github.com/hslatman/caddy-crowdsec-bouncer/http \
  --with github.com/fvbommel/caddy-combine-ip-ranges \
  --with github.com/mholt/caddy-ratelimit
# --with github.com/hslatman/caddy-crowdsec-bouncer/appsec
# --with github.com/hslatman/caddy-crowdsec-bouncer/layer4

FROM caddy:${CADDY_VERSION}-alpine

COPY --from=builder /usr/bin/caddy /usr/bin/caddy

CMD ["caddy", "docker-proxy"]
