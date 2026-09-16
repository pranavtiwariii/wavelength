-- Proposal 5.2: notification service — in-app notifications for connections,
-- likes and new matches.
CREATE TABLE IF NOT EXISTS notifications (
  id         UUID PRIMARY KEY,
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kind       TEXT NOT NULL CHECK (kind IN (
               'connection_request','connection_accepted','new_match',
               'message','drop_like','room_message')),
  actor_id   UUID REFERENCES users(id) ON DELETE CASCADE,
  -- Where tapping the notification should land, e.g. /requests or /chat/<id>.
  target     TEXT,
  body       TEXT NOT NULL,
  read_at    TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS notifications_inbox_idx
  ON notifications (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS notifications_unread_idx
  ON notifications (user_id) WHERE read_at IS NULL;

-- Proposal 6.2: explainability satisfaction — pilot users rate the
-- "why you matched" explanation 1-5 for clarity/usefulness.
CREATE TABLE IF NOT EXISTS explanation_ratings (
  id         UUID PRIMARY KEY,
  rater_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subject_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  rating     INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (rater_id, subject_id)
);
