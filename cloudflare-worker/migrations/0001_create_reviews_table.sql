-- Unified review table for the /v1alpha "my festival" API.
--
-- One row per (bucket, festival, drink, device). The composite primary key
-- gives upsert semantics so re-reviewing never inflates counts.
--
-- star_rating and recommend are independently nullable: a caller can set
-- a star rating without answering the recommendation question, or vice versa.
--
-- `bucket` isolates data by environment ('test' vs 'prod'), so test traffic
-- never mixes with production data. A `RATINGS_BUCKET` worker var can pin it.
-- `user_id` is reserved for the sign-in upgrade (phase 3) and stays NULL
-- while the API is anonymous.

CREATE TABLE IF NOT EXISTS reviews (
  bucket      TEXT    NOT NULL,
  festival_id TEXT    NOT NULL,
  drink_id    TEXT    NOT NULL,
  device_id   TEXT    NOT NULL,
  user_id     TEXT,
  star_rating INTEGER CHECK (star_rating BETWEEN 1 AND 5),
  recommend   INTEGER CHECK (recommend IN (0, 1)),
  updated_at  INTEGER NOT NULL,
  PRIMARY KEY (bucket, festival_id, drink_id, device_id)
);

-- Aggregate reads always filter by (bucket, festival_id) and group by drink_id.
CREATE INDEX IF NOT EXISTS idx_reviews_aggregate
  ON reviews (bucket, festival_id, drink_id);
