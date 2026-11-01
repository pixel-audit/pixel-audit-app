-- The sample shop's events in ClickHouse, for a clickhouse_query data source.
-- One statement per file: the image's init runs each file as one query.
CREATE TABLE IF NOT EXISTS shop.events (
  name    LowCardinality(String),
  user_id UInt32,
  at      DateTime
) ENGINE = MergeTree ORDER BY (name, at)
