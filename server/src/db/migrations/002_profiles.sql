-- Gender, orientation preference, demo bots, and connection requests.

ALTER TABLE users ADD COLUMN IF NOT EXISTS photo_url TEXT;

-- Who this person wants shown to them. Only meaningful for dating intent;
-- friends mode deliberately ignores it and shows everyone.
ALTER TABLE users ADD COLUMN IF NOT EXISTS seeking TEXT
  CHECK (seeking IS NULL OR seeking IN ('men','women','everyone'));

-- Synthetic profiles created in-app for the pilot (proposal 6.3 calls for a
-- curated set of synthetic profiles to beat the cold-start problem).
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_synthetic BOOLEAN NOT NULL DEFAULT FALSE;

-- A synthetic profile can answer messages so the matching loop is demoable
-- end to end without a second human.
ALTER TABLE users ADD COLUMN IF NOT EXISTS auto_reply BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS users_discovery_idx
  ON users (intent, gender) WHERE name IS NOT NULL;
