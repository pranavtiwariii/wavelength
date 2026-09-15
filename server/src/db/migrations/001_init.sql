-- Wavelength initial schema. Shape follows spec section 6, with auth/OTP and
-- swipe tables added (implied by 3.1/3.6 but not enumerated there).

CREATE TABLE IF NOT EXISTS users (
  id                        UUID PRIMARY KEY,
  email                     TEXT UNIQUE,
  phone                     TEXT UNIQUE,
  name                      TEXT,
  age                       INT CHECK (age IS NULL OR age BETWEEN 18 AND 120),
  gender                    TEXT,
  interested_in             JSONB NOT NULL DEFAULT '[]'::jsonb,
  intent                    TEXT CHECK (intent IN ('dating','friends','both')),
  city                      TEXT,
  lat                       DOUBLE PRECISION,
  lng                       DOUBLE PRECISION,
  bio                       TEXT,
  onboarding_stage          TEXT NOT NULL DEFAULT 'basics',
  taste_profile_completeness INT NOT NULL DEFAULT 0
                            CHECK (taste_profile_completeness BETWEEN 0 AND 100),
  domain_priority           JSONB NOT NULL DEFAULT '{"music":1,"movie":1,"book":1}'::jsonb,
  created_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT users_has_identifier CHECK (email IS NOT NULL OR phone IS NOT NULL)
);

-- Coarse location only: lat/lng are the CITY centroid, never device GPS (NFR 9).
COMMENT ON COLUMN users.lat IS 'City centroid latitude - never precise device GPS';
COMMENT ON COLUMN users.lng IS 'City centroid longitude - never precise device GPS';

CREATE TABLE IF NOT EXISTS auth_otp_codes (
  id           UUID PRIMARY KEY,
  identifier   TEXT NOT NULL,              -- normalised email or E.164 phone
  channel      TEXT NOT NULL CHECK (channel IN ('email','phone')),
  code_hash    TEXT NOT NULL,              -- sha256(code + identifier); never store raw
  expires_at   TIMESTAMPTZ NOT NULL,
  consumed_at  TIMESTAMPTZ,
  attempts     INT NOT NULL DEFAULT 0,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS auth_otp_identifier_idx ON auth_otp_codes (identifier, created_at DESC);

CREATE TABLE IF NOT EXISTS user_photos (
  id         UUID PRIMARY KEY,
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  url        TEXT NOT NULL,
  position   INT NOT NULL DEFAULT 0,
  moderation_status TEXT NOT NULL DEFAULT 'pending'
                    CHECK (moderation_status IN ('pending','approved','rejected')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, position)
);

CREATE TABLE IF NOT EXISTS music_profile (
  user_id                UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  top_artists            JSONB NOT NULL DEFAULT '[]'::jsonb,
  top_tracks             JSONB NOT NULL DEFAULT '[]'::jsonb,
  genre_distribution     JSONB NOT NULL DEFAULT '{}'::jsonb,
  audio_feature_centroid JSONB NOT NULL DEFAULT '{}'::jsonb,
  source                 TEXT,
  last_synced_at         TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS movie_profile (
  user_id            UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  favorite_films     JSONB NOT NULL DEFAULT '[]'::jsonb,
  watched_films      JSONB NOT NULL DEFAULT '[]'::jsonb,
  genre_distribution JSONB NOT NULL DEFAULT '{}'::jsonb,
  era_distribution   JSONB NOT NULL DEFAULT '{}'::jsonb,
  mood_distribution  JSONB NOT NULL DEFAULT '{}'::jsonb,
  source             TEXT,
  last_synced_at     TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS book_profile (
  user_id                UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  favorite_books         JSONB NOT NULL DEFAULT '[]'::jsonb,
  currently_reading      JSONB NOT NULL DEFAULT '[]'::jsonb,
  genre_distribution     JSONB NOT NULL DEFAULT '{}'::jsonb,
  fiction_nonfiction_ratio DOUBLE PRECISION,
  source                 TEXT,
  last_synced_at         TIMESTAMPTZ
);

-- Platform-wide favourite counts, for the inverse-popularity weighting in 5.2.
CREATE TABLE IF NOT EXISTS item_popularity (
  domain      TEXT NOT NULL CHECK (domain IN ('music','movie','book')),
  item_key    TEXT NOT NULL,
  user_count  INT NOT NULL DEFAULT 0,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (domain, item_key)
);

CREATE TABLE IF NOT EXISTS compatibility_scores (
  user_a_id            UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_b_id            UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  overall_score        INT NOT NULL CHECK (overall_score BETWEEN 0 AND 100),
  music_score          INT,
  movie_score          INT,
  book_score           INT,
  shared_highlights    JSONB NOT NULL DEFAULT '[]'::jsonb,
  divergence_highlights JSONB NOT NULL DEFAULT '[]'::jsonb,
  narrative_text       TEXT,
  narrative_inputs_hash TEXT,  -- regenerate narrative only when this changes (3.5)
  computed_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_a_id, user_b_id),
  -- Store each pair once, canonically ordered, to halve the precompute table.
  CONSTRAINT compat_pair_ordered CHECK (user_a_id < user_b_id)
);
CREATE INDEX IF NOT EXISTS compat_a_score_idx ON compatibility_scores (user_a_id, overall_score DESC);
CREATE INDEX IF NOT EXISTS compat_b_score_idx ON compatibility_scores (user_b_id, overall_score DESC);

CREATE TABLE IF NOT EXISTS swipes (
  id          UUID PRIMARY KEY,
  actor_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  target_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  direction   TEXT NOT NULL CHECK (direction IN ('like','pass')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (actor_id, target_id),
  CONSTRAINT swipe_not_self CHECK (actor_id <> target_id)
);

CREATE TABLE IF NOT EXISTS matches (
  id         UUID PRIMARY KEY,
  user_a_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_b_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status     TEXT NOT NULL DEFAULT 'active'
             CHECK (status IN ('active','unmatched','blocked')),
  matched_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_a_id, user_b_id),
  CONSTRAINT match_pair_ordered CHECK (user_a_id < user_b_id)
);

CREATE TABLE IF NOT EXISTS messages (
  id         UUID PRIMARY KEY,
  match_id   UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  sender_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content    TEXT NOT NULL,
  sent_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  read_at    TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS messages_match_idx ON messages (match_id, sent_at DESC);

CREATE TABLE IF NOT EXISTS taste_rooms (
  id                 UUID PRIMARY KEY,
  name               TEXT NOT NULL,
  description        TEXT,
  taste_cluster_tags JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS taste_room_members (
  room_id   UUID NOT NULL REFERENCES taste_rooms(id) ON DELETE CASCADE,
  user_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (room_id, user_id)
);

CREATE TABLE IF NOT EXISTS collaborative_blends (
  id         UUID PRIMARY KEY,
  match_id   UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  type       TEXT NOT NULL CHECK (type IN ('playlist','watchlist','readlist')),
  items      JSONB NOT NULL DEFAULT '[]'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (match_id, type)
);

-- 4.8: per-domain visibility. 'hidden' still feeds matching, just never renders.
CREATE TABLE IF NOT EXISTS privacy_settings (
  user_id          UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  music_visibility TEXT NOT NULL DEFAULT 'full'
                   CHECK (music_visibility IN ('full','aggregate','hidden')),
  movie_visibility TEXT NOT NULL DEFAULT 'full'
                   CHECK (movie_visibility IN ('full','aggregate','hidden')),
  book_visibility  TEXT NOT NULL DEFAULT 'full'
                   CHECK (book_visibility IN ('full','aggregate','hidden'))
);

CREATE TABLE IF NOT EXISTS reports (
  id           UUID PRIMARY KEY,
  reporter_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reported_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason       TEXT NOT NULL,
  detail       TEXT,
  status       TEXT NOT NULL DEFAULT 'open'
               CHECK (status IN ('open','reviewing','actioned','dismissed')),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS blocks (
  blocker_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id)
);
