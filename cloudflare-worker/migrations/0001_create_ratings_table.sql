-- Aggregate drink ratings (first step towards online "my festival").
--
-- One row per (bucket, festival, drink, device). The composite primary key
-- gives upsert semantics: a device re-rating a drink updates its existing row
-- rather than inserting a duplicate, so aggregate counts never inflate.
--
-- `bucket` isolates data by environment ('test' vs 'prod') so we can exercise
-- the system end to end without polluting real festival data. `user_id` is
-- reserved for the sign-in upgrade (phase 3) and stays NULL while anonymous.

CREATE TABLE IF NOT EXISTS ratings (
  bucket      TEXT    NOT NULL,
  festival_id TEXT    NOT NULL,
  drink_id    TEXT    NOT NULL,
  device_id   TEXT    NOT NULL,
  user_id     TEXT,
  rating      INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  updated_at  INTEGER NOT NULL,
  PRIMARY KEY (bucket, festival_id, drink_id, device_id)
);

-- Aggregate reads always filter by (bucket, festival_id) and group by drink_id.
CREATE INDEX IF NOT EXISTS idx_ratings_aggregate
  ON ratings (bucket, festival_id, drink_id);
