FROM alpine:latest AS parallel
RUN apk add --no-cache parallel

FROM caddy:latest AS caddy
COPY Caddyfile ./
RUN caddy fmt --overwrite Caddyfile

FROM typesense/typesense:30.1

COPY --from=caddy /srv/Caddyfile ./
COPY --from=caddy /usr/bin/caddy /usr/bin/caddy
COPY --from=parallel /usr/bin/parallel /usr/bin/parallel

COPY --chmod=755 scripts/* ./

# Create non-root user and set up data directory
RUN groupadd -r typesense && useradd -r -g typesense -d /data -s /sbin/nologin typesense \
    && mkdir -p /data \
    && chown -R typesense:typesense /data \
    && chown typesense:typesense /opt/typesense-server \
    && chown typesense:typesense /*.sh \
    && chown typesense:typesense /Caddyfile

USER typesense

ENTRYPOINT ["/bin/sh"]

CMD ["start.sh"]
