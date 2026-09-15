-- Synthetic profiles have no credentials by design: nobody can sign in as one.
-- The original constraint assumed every row was a login, so relax it to cover
-- only real accounts.
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_has_identifier;

ALTER TABLE users ADD CONSTRAINT users_has_identifier
  CHECK (is_synthetic OR email IS NOT NULL OR phone IS NOT NULL);
