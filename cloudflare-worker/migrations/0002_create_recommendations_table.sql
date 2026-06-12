-- "Would recommend" — a yes/no signal per (bucket, festival, drink, device),
-- separate from the star rating so we can surface a "% would recommend".
--
-- Shares the same upsert/bucket model as the ratings table. `recommend` is
-- stored as 0/1 because SQLite has no native boolean. `user_id` is reserved
-- for the sign-in upgrade and stays NULL while anonymous.

CREATE TABLE IF NOT EXISTS recommendations (
  bucket      TEXT    NOT NULL,
  festival_id TEXT    NOT NULL,
  drink_id    TEXT    NOT NULL,
  device_id   TEXT    NOT NULL,
  user_id     TEXT,
  recommend   INTEGER NOT NULL CHECK (recommend IN (0, 1)),
  updated_at  INTEGER NOT NULL,
  PRIMARY KEY (bucket, festival_id, drink_id, device_id)
);

CREATE INDEX IF NOT EXISTS idx_recommendations_aggregate
  ON recommendations (bucket, festival_id, drink_id);
