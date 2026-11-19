# ClickHouse for Hexclave's analytics. 25.10 is the version Hexclave's own docs and compose file use.
FROM clickhouse/clickhouse-server:25.10.7.6@sha256:f9892befd74a031d7ff9c0410613480b77b728c2ea9d4950b8ef282f5dade87b

# Hexclave's migration script creates databases, views, a limited user, grants and row
# policies, so the admin user needs SQL access management.
ENV CLICKHOUSE_DB=analytics \
    CLICKHOUSE_USER=stackframe \
    CLICKHOUSE_DEFAULT_ACCESS_MANAGEMENT=1

# IPv4 + IPv6 listening (Railway's private network) and low-resource settings.
COPY listen.xml logs.xml low-resources.xml /etc/clickhouse-server/config.d/
COPY default-profile-low-resources-overrides.xml /etc/clickhouse-server/users.d/
