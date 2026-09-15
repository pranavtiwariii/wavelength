-- Proposal 4.1: opt-in bidirectional connections, Content Drops, Communities.

-- ---------------------------------------------------------------------------
-- Connections: request/accept, not one-directional following. Private content
-- stays gated behind a mutual connection.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS connection_requests (
  id           UUID PRIMARY KEY,
  requester_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  recipient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status       TEXT NOT NULL DEFAULT 'pending'
               CHECK (status IN ('pending','accepted','declined','withdrawn')),
  message      TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  responded_at TIMESTAMPTZ,
  UNIQUE (requester_id, recipient_id),
  CONSTRAINT connection_not_self CHECK (requester_id <> recipient_id)
);
CREATE INDEX IF NOT EXISTS connection_inbox_idx
  ON connection_requests (recipient_id, status, created_at DESC);

-- ---------------------------------------------------------------------------
-- Content Drops: lightweight posts tagging something the user likes.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS drops (
  id          UUID PRIMARY KEY,
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  domain      TEXT NOT NULL CHECK (domain IN ('music','movie','book')),
  item_key    TEXT NOT NULL,
  item_label  TEXT NOT NULL,
  item_subtitle TEXT,
  item_image  TEXT,
  caption     TEXT,
  community_id UUID,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS drops_recent_idx ON drops (created_at DESC);
CREATE INDEX IF NOT EXISTS drops_user_idx ON drops (user_id, created_at DESC);

-- One row per user per drop per reaction kind.
CREATE TABLE IF NOT EXISTS drop_reactions (
  drop_id    UUID NOT NULL REFERENCES drops(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kind       TEXT NOT NULL CHECK (kind IN ('like','save')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (drop_id, user_id, kind)
);

-- ---------------------------------------------------------------------------
-- Communities: niche, tag-based groups.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS communities (
  id          UUID PRIMARY KEY,
  slug        TEXT NOT NULL UNIQUE,
  name        TEXT NOT NULL,
  description TEXT,
  domain      TEXT CHECK (domain IS NULL OR domain IN ('music','movie','book')),
  -- Taste keywords that pull a user toward this community.
  tags        JSONB NOT NULL DEFAULT '[]'::jsonb,
  accent      TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS community_members (
  community_id UUID NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
  user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  joined_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (community_id, user_id)
);
CREATE INDEX IF NOT EXISTS community_members_user_idx ON community_members (user_id);

ALTER TABLE drops
  ADD CONSTRAINT drops_community_fk
  FOREIGN KEY (community_id) REFERENCES communities(id) ON DELETE SET NULL;
