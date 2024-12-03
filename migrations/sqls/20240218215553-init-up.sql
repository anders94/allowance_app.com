-- --------------------------------------------------------
-- -- Extensions
-- --------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- --------------------------------------------------------
-- -- Table: famlies
-- --------------------------------------------------------

CREATE TABLE families (
  id                 UUID            NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  created            TIMESTAMP       NOT NULL DEFAULT now(),
  moniker            TEXT            NOT NULL,
  attributes         JSONB           NOT NULL DEFAULT '{}'::JSONB,
  obsolete           BOOLEAN         NOT NULL DEFAULT FALSE
) WITH (OIDS=FALSE);

INSERT INTO families
  (moniker, attributes)
VALUES
  ('System', '{"administrator": true}'::JSONB);

-- --------------------------------------------------------
-- -- Table: users
-- --------------------------------------------------------

CREATE TABLE users (
  id                 UUID            NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  created            TIMESTAMP       NOT NULL DEFAULT now(),
  full_name          TEXT            NOT NULL,
  email              TEXT            NOT NULL UNIQUE,
  hashed_password    TEXT            NOT NULL,
  family_id          UUID            NOT NULL REFERENCES families(id),
  attributes         JSONB           NOT NULL DEFAULT '{}'::JSONB,
  obsolete           BOOLEAN         NOT NULL DEFAULT FALSE,
  CONSTRAINT pk_users_email PRIMARY KEY (email)
) WITH (OIDS=FALSE);

CREATE INDEX idx_users_email ON users USING btree (email);

INSERT INTO users
  (full_name, email, hashed_password, family_id, attributes)
VALUES
  ('Treasury', 'treasury@andrs.dev',
  crypt('banker!', gen_salt('bf')),
  (SELECT id FROM families WHERE attributes->>'administrator' = 'true'),
  '{"administrator": true}'::JSONB);

-- Example usage:
--
-- INSERT INTO users (email, encrypted_password) VALUES ('a@b.com', crypt('something-secure', gen_salt('bf')));
-- SELECT id FROM users WHERE email = 'a@b.com' AND password = crypt('something-secure', password);
-- SELECT id FROM users WHERE email = 'a@b.com' AND password = crypt('something-incorrect', password);

-- --------------------------------------------------------
-- -- Table: sessions
-- --------------------------------------------------------

CREATE TABLE sessions (
  sid                UUID            NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  sess               JSONB           NOT NULL,
  expire             TIMESTAMP(6)    NOT NULL
)
WITH (OIDS=FALSE);

ALTER TABLE sessions ADD CONSTRAINT sessions_pkey PRIMARY KEY (sid) NOT DEFERRABLE INITIALLY IMMEDIATE;

CREATE INDEX idx_sessions_expire ON sessions(expire);

-- --------------------------------------------------------
-- -- Table: Assets
-- --------------------------------------------------------

CREATE TABLE assets (
  symbol             TEXT            NOT NULL,  -- USD, USDC-ETH, USDC-SOL
  display_name       TEXT            NOT NULL,  -- USD Coin on Ethereum Layer 1
  created            TIMESTAMP       NOT NULL DEFAULT now(),
  significant_digits INT             NOT NULL,
  attributes         JSONB           NOT NULL DEFAULT '{}'::JSONB,
  obsolete           BOOLEAN         NOT NULL DEFAULT FALSE,
  CONSTRAINT pk_assets_symbol PRIMARY KEY (symbol)
) WITH (OIDS=FALSE);

INSERT INTO assets (symbol, display_name, significant_digits) VALUES ('USD', 'United States Dollar', 2);

-- --------------------------------------------------------
-- -- Table: Accounts
-- --------------------------------------------------------
--
-- Accounts track the amount of assets held by a particular user. The total claim held is
-- calculated by adding available_amount and locked_amount. In other words, when assets
-- are to be locked up in orders, they are moved from available_amount to locked_amount
-- and vice versa.

CREATE TABLE accounts (
  id                 UUID            NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  created            TIMESTAMP       NOT NULL DEFAULT now(),
  user_id            UUID            NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  symbol             TEXT            NOT NULL REFERENCES assets(symbol) ON DELETE RESTRICT,
  available_amount   NUMERIC(32, 16) NOT NULL DEFAULT 0.0,
  locked_amount      NUMERIC(32, 16) NOT NULL DEFAULT 0.0,
  attributes         JSONB           NOT NULL DEFAULT '{"name":"Default"}'::JSONB,
  obsolete           BOOLEAN         NOT NULL DEFAULT FALSE
) WITH (OIDS=FALSE);

INSERT INTO accounts
  (user_id, symbol, attributes)
VALUES
  ((SELECT id FROM users WHERE email = 'treasury@andrs.dev'), 'USD', '{"name":"Treasury"}'::JSONB);

-- --------------------------------------------------------
-- -- Table: Escrows
-- --------------------------------------------------------

CREATE TABLE escrows (
  id                 UUID            NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  created            TIMESTAMP       NOT NULL DEFAULT now(),
  account_id         UUID            NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
  amount             NUMERIC(32, 16) NOT NULL DEFAULT 0.0,
  attributes         JSONB           NOT NULL DEFAULT '{}'::JSONB,
  obsolete           BOOLEAN         NOT NULL DEFAULT FALSE
) WITH (OIDS=FALSE);

-- --------------------------------------------------------
-- -- Table: Transaction Types
-- --------------------------------------------------------

CREATE TABLE transaction_types (
  id                 UUID            NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  created            TIMESTAMP       NOT NULL DEFAULT now(),
  transaction_type   TEXT            NOT NULL UNIQUE,
  priveleged         BOOLEAN         NOT NULL DEFAULT FALSE,
  attributes         JSONB           NOT NULL DEFAULT '{}'::JSONB,
  obsolete           BOOLEAN         NOT NULL DEFAULT FALSE
) WITH (OIDS=FALSE);

INSERT INTO transaction_types
  (transaction_type, priveleged)
VALUES
  ('Mint', TRUE),
  ('Burn', TRUE),
  ('Lock', FALSE),
  ('Unlock', FALSE),
  ('Escrow', FALSE),
  ('Unescrow', FALSE),
  ('Payment', FALSE),
  ('Interest', FALSE);

-- --------------------------------------------------------
-- -- Table: Transactions
-- --------------------------------------------------------
--
-- Records money movements.

CREATE TABLE transactions (
  id                       UUID            NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  created                  TIMESTAMP       NOT NULL DEFAULT now(),
  amount                   NUMERIC(32, 16) NOT NULL DEFAULT 0.0,
  from_account_id          UUID            NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
  from_account_new_balance NUMERIC(32, 16) NOT NULL,
  to_account_id            UUID            NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
  to_account_new_balance   NUMERIC(32, 16) NOT NULL,
  transaction_type         UUID            NOT NULL REFERENCES transaction_types(id) ON DELETE RESTRICT,
  attributes               JSONB           NOT NULL DEFAULT '{}'::JSONB,
  obsolete                 BOOLEAN         NOT NULL DEFAULT FALSE
) WITH (OIDS=FALSE);

-- --------------------------------------------------------
-- -- Table: Groups
-- --------------------------------------------------------
--
-- Chat groups

CREATE TABLE groups (
  id                       UUID            NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  created                  TIMESTAMP       NOT NULL DEFAULT now(),
  title                    TEXT            NOT NULL,
  attributes               JSONB           NOT NULL DEFAULT '{}'::JSONB,
  obsolete                 BOOLEAN         NOT NULL DEFAULT FALSE
) WITH (OIDS=FALSE);

-- --------------------------------------------------------
-- -- Table: Users to Groups
-- --------------------------------------------------------

CREATE TABLE users2groups (
  created                  TIMESTAMP       NOT NULL DEFAULT now(),
  user_id                  UUID            NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  group_id                 UUID            NOT NULL REFERENCES groups(id) ON DELETE RESTRICT,
  obsolete                 BOOLEAN         NOT NULL DEFAULT FALSE,
  CONSTRAINT               pk_users2groups PRIMARY KEY (user_id, group_id)
) WITH (OIDS=FALSE);

-- --------------------------------------------------------
-- -- Table: Messages
-- --------------------------------------------------------
--
-- Chat messages associated with groups

CREATE TABLE messages (
  id                       UUID            NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  created                  TIMESTAMP       NOT NULL DEFAULT now(),
  group_id                 UUID            NOT NULL REFERENCES groups(id) ON DELETE RESTRICT,
  user_id                  UUID            NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  transaction_id           UUID            REFERENCES transaction_types(id) ON DELETE RESTRICT,
  message                  TEXT            NOT NULL,
  attributes               JSONB           NOT NULL DEFAULT '{}'::JSONB,
  obsolete                 BOOLEAN         NOT NULL DEFAULT FALSE
) WITH (OIDS=FALSE);

-- --------------------------------------------------------
-- -- Table: Magic Links
-- --------------------------------------------------------
--
-- Links that can be clicked a limited number of times (usually once) that logs a user in
-- and sends them to a specific page. This is useful for including in verification emails
-- or invites to new users.

CREATE TABLE magic_links (
  id                UUID                      NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  created_at        TIMESTAMP WITH TIME ZONE  NOT NULL DEFAULT now(),
  expires_at        TIMESTAMP WITH TIME ZONE  NOT NULL DEFAULT now() + INTERVAL '30 days',
  obsolete          BOOLEAN                   NOT NULL DEFAULT FALSE,
  destination       TEXT                      NOT NULL,
  user_id           UUID                      REFERENCES users(id),
  uses_remaining    INT                       NOT NULL DEFAULT 1,
  attributes        JSONB                     NOT NULL DEFAULT '{}'::JSONB
) WITH (OIDS=FALSE);
