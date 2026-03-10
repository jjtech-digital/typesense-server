FROM caddy:latest AS caddy
COPY Caddyfile ./
RUN caddy fmt --overwrite Caddyfile

FROM typesense/typesense:30.1

COPY --from=caddy /srv/Caddyfile ./
COPY --from=caddy /usr/bin/caddy /usr/bin/caddy

RUN apt-get update && apt-get install -y --no-install-recommends gosu \
    && rm -rf /var/lib/apt/lists/* \
    && gosu nobody true

# Create non-root user
RUN groupadd -r typesense && useradd -r -g typesense -d /data -s /sbin/nologin typesense \
    && mkdir -p /data /data/backups \
    && chown -R typesense:typesense /data

COPY --chmod=755 scripts/* ./

HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD curl -sf http://127.0.0.1:8118/health || exit 1

ENTRYPOINT ["/bin/sh"]

CMD ["start.sh"]
