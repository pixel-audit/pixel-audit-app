-- A shop's events for the last 60 days, so a postgres_query data source has
-- something to count. The step counts shrink down the funnel.
CREATE TABLE events (
  id         bigserial PRIMARY KEY,
  name       text        NOT NULL,
  user_id    integer     NOT NULL,
  created_at timestamptz NOT NULL
);

INSERT INTO events (name, user_id, created_at)
SELECT step.name, (random() * 100000)::int, day + (random() * interval '1 day')
FROM generate_series(now() - interval '60 days', now(), interval '1 day') AS day
CROSS JOIN LATERAL (
  SELECT 'page_view'    AS name, 1000 + (random() * 200)::int AS n UNION ALL
  SELECT 'view_content', 600 + (random() * 100)::int UNION ALL
  SELECT 'add_to_cart',  150 + (random() * 40)::int  UNION ALL
  SELECT 'purchase',     40 + (random() * 15)::int
) AS step
CROSS JOIN LATERAL generate_series(1, step.n);

CREATE INDEX ON events (name, created_at);
