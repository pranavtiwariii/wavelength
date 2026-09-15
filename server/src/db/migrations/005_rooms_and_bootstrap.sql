-- Group chat inside communities, and a flag for pool bootstrapping.

CREATE TABLE IF NOT EXISTS room_messages (
  id           UUID PRIMARY KEY,
  community_id UUID NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
  sender_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content      TEXT NOT NULL,
  sent_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS room_messages_idx ON room_messages (community_id, sent_at DESC);

-- Set once the pool has been generated around this user's taste, so the
-- bootstrap runs on first entry and never again.
ALTER TABLE users ADD COLUMN IF NOT EXISTS pool_bootstrapped BOOLEAN NOT NULL DEFAULT FALSE;
