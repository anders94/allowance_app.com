-- --------------------------------------------------------
-- -- Extensions
-- --------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- --------------------------------------------------------
-- -- Table: users
-- --------------------------------------------------------

CREATE TABLE users (
  id                 UUID            NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  created            TIMESTAMP       NOT NULL DEFAULT now(),
  full_name          TEXT            NOT NULL,
  email              TEXT            NOT NULL UNIQUE,
  hashed_password    TEXT            NOT NULL,
  attributes         JSONB           NOT NULL DEFAULT '{}'::JSONB,
  obsolete           BOOLEAN         NOT NULL DEFAULT FALSE,
  CONSTRAINT pk_users_email PRIMARY KEY (email)
) WITH (OIDS=FALSE);

CREATE INDEX idx_users_email ON users USING btree (email);

INSERT INTO users
  (full_name, email, hashed_password, attributes)
VALUES
  ('Treasury', 'treasury@andrs.dev',
  crypt('banker!', gen_salt('bf')),
  '{"administrator": true}'::JSONB),
  ('Administrator', 'admin@andrs.dev',
  crypt('banker!', gen_salt('bf')),
  '{"administrator": true, "emailVerified": true}'::JSONB);

-- Example usage:
--
-- INSERT INTO users (email, encrypted_password) VALUES ('a@b.com', crypt('something-secure', gen_salt('bf')));
-- SELECT id FROM users WHERE email = 'a@b.com' AND password = crypt('something-secure', password);
-- SELECT id FROM users WHERE email = 'a@b.com' AND password = crypt('something-incorrect', password);

-- --------------------------------------------------------
-- -- Table: sessions
-- --------------------------------------------------------

CREATE TABLE sessions (
  sid     TEXT          NOT NULL COLLATE "default",
  sess    JSONB         NOT NULL,
  expire  TIMESTAMP(6)  NOT NULL
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
  ((SELECT id FROM users WHERE email = 'treasury@andrs.dev'), 'USD', '{"name":"Treasury"}'::JSONB),
  ((SELECT id FROM users WHERE email = 'admin@andrs.dev'), 'USD', '{"name":"Default"}'::JSONB);

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
-- -- Function: Mint Funds
-- --------------------------------------------------------
--
-- SELECT * FROM mint_funds((SELECT id FROM accounts WHERE user_id = (SELECT id FROM users WHERE email = 'test1@example.com') AND symbol = 'USD'), 10.0);
--

CREATE FUNCTION mint_funds(_account_id UUID, _amount NUMERIC)
  RETURNS TABLE (available_amount NUMERIC)
AS $$
BEGIN
  RAISE NOTICE 'mint_funds(%, %)', _account_id, _amount;

  UPDATE accounts a
  SET
    available_amount = a.available_amount + _amount
  WHERE
    a.id = _account_id 
  RETURNING a.available_amount INTO available_amount;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'mint_funds(%, %): Account does not exist.', _account_id, _amount;
  END IF;

  INSERT INTO transactions
    (
      amount,
      from_account_id,
      from_account_new_balance,
      to_account_id,
      to_account_new_balance,
      transaction_type,
      attributes
    )
  VALUES
    (
      _amount,
      (SELECT a.id FROM accounts a LEFT JOIN users u ON a.user_id = u.id WHERE u.email = 'treasury@andrs.dev' AND a.symbol = 'USD' LIMIT 1),
      0.0,
      _account_id,
      available_amount,
      (SELECT id FROM transaction_types WHERE transaction_type = 'Mint'),
      '{"message":"Mint"}'::JSONB
    );

  RETURN QUERY SELECT available_amount;

END;
$$ LANGUAGE plpgsql;

-- --------------------------------------------------------
-- -- Function: Burn Funds
-- --------------------------------------------------------
--
-- SELECT * FROM burn_funds((SELECT id FROM accounts WHERE user_id = (SELECT id FROM users WHERE email = 'test1@example.com') AND symbol = 'USD'), 10.0);
--

CREATE FUNCTION burn_funds(_account_id UUID, _amount NUMERIC)
  RETURNS TABLE (available_amount NUMERIC)
AS $$
BEGIN
  RAISE NOTICE 'burn_funds(%, %)', _account_id, _amount;

  UPDATE accounts a
  SET
    available_amount = a.available_amount - _amount
  WHERE
    a.id = _account_id 
  RETURNING a.available_amount INTO available_amount;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'burn_funds(%, %): Account does not exist.', _account_id, _amount;
  END IF;

  IF available_amount < 0.0 THEN
    RAISE EXCEPTION 'burn_funds(%, %): Insufficient funds. Balance would be %.', _account_id, _amount, available_amount;
  END IF;

  INSERT INTO transactions
    (
      amount,
      from_account_id,
      from_account_new_balance,
      to_account_id,
      to_account_new_balance,
      transaction_type,
      attributes
    )
  VALUES
    (
      _amount,
      _account_id,
      available_amount,
      (SELECT a.id FROM accounts a LEFT JOIN users u ON a.user_id = u.id WHERE u.email = 'treasury@andrs.dev' AND a.symbol = 'USD' LIMIT 1),
      0.0,
      (SELECT id FROM transaction_types WHERE transaction_type = 'Burn'),
      '{"message":"Burn"}'::JSONB
    );

  RETURN QUERY SELECT available_amount;

END;
$$ LANGUAGE plpgsql;

-- --------------------------------------------------------
-- -- Function: Lock Funds
-- --------------------------------------------------------
--
-- SELECT * FROM lock_funds((SELECT id FROM accounts WHERE user_id = (SELECT id FROM users WHERE email = 'test1@example.com') AND symbol = 'USD'), 10.0);
--

CREATE FUNCTION lock_funds(_account_id UUID, _amount NUMERIC)
  RETURNS TABLE (locked_amount NUMERIC, available_amount NUMERIC)
AS $$
BEGIN
  RAISE NOTICE 'lock_funds(%, %)', _account_id, _amount;
  IF (SELECT a.available_amount FROM accounts a WHERE a.id = _account_id) < _amount THEN
    RAISE EXCEPTION 'lock_funds(%, %): Account lacks sufficient available funds.', _account_id, _amount;
  END IF;

  RETURN QUERY
  UPDATE accounts a
  SET
    available_amount = a.available_amount - _amount,
    locked_amount = a.locked_amount + _amount
  WHERE
    a.id = _account_id 
  RETURNING a.locked_amount, a.available_amount;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'lock_funds(%, %): Account does not exist.', _account_id, _amount;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- --------------------------------------------------------
-- -- Function: Unlock Funds
-- --------------------------------------------------------
--
-- SELECT * FROM unlock_funds((SELECT id FROM accounts WHERE user_id = (SELECT id FROM users WHERE email = 'test1@example.com') AND symbol = 'xUSD'), 10.0);
--

CREATE FUNCTION unlock_funds(_account_id UUID, _amount NUMERIC)
  RETURNS TABLE (locked_amount NUMERIC, available_amount NUMERIC)
AS $$
BEGIN
  RAISE NOTICE 'unlock_funds(%, %)', _account_id, _amount;
  IF (SELECT a.locked_amount FROM accounts a WHERE a.id = _account_id) < _amount THEN
    RAISE EXCEPTION 'unlock_funds(%, %): Account lacks sufficient locked funds.', _account_id, _amount;
  END IF;

  RETURN QUERY
  UPDATE accounts a
  SET
    available_amount = a.available_amount + _amount,
    locked_amount = a.locked_amount - _amount
  WHERE
    a.id = _account_id 
  RETURNING a.locked_amount, a.available_amount;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'unlock_funds(%, %): Account does not exist.', _account_id, _amount;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- --------------------------------------------------------
-- -- Function: Move Locked Funds
-- --------------------------------------------------------
--
-- Moves the requested amount from one user's account to another, creating the account if
-- necessary. Returns new account state including the reciever who's account may be newly
-- created.

CREATE FUNCTION move_locked_funds(_source_account_id UUID, _destination_account_id UUID, _amount NUMERIC, _message TEXT)
  RETURNS TABLE (account_id UUID, locked_amount NUMERIC, available_amount NUMERIC)
AS $$
DECLARE
  source_locked_amount NUMERIC;
  source_available_amount NUMERIC;
  destination_locked_amount NUMERIC;
  destination_available_amount NUMERIC;
BEGIN
  RAISE NOTICE 'move_locked_funds(%, %, %)', _source_account_id, _destination_account_id, _amount;
  IF _source_account_id = _destination_account_id THEN
    RAISE EXCEPTION 'move_locked_funds(%, %, %): Source and destination accounts are the same.', _source_account_id, _destination_account_id, _amount;
  END IF;

  IF (SELECT (SELECT symbol FROM accounts WHERE id = _source_account_id) != (SELECT symbol FROM accounts WHERE id = _source_account_id)) THEN
    RAISE EXCEPTION 'move_locked_funds(%, %, %): Source and destination account currencies differ.', _source_account_id, _destination_account_id, _amount;
  END IF;

  IF (SELECT a.locked_amount FROM accounts a WHERE a.id = _source_account_id) < _amount THEN
    RAISE EXCEPTION 'move_locked_funds(%, %, %): Source account lacks sufficient locked funds.', _source_account_id, _destination_account_id, _amount;
  END IF;

  UPDATE accounts
  SET
    locked_amount = accounts.locked_amount - _amount
  WHERE
    accounts.id = _source_account_id
  RETURNING accounts.locked_amount, accounts.available_amount INTO source_locked_amount, source_available_amount;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'move_locked_funds(%, %, %): Source account does not exist.', _source_account_id, _destination_account_id, _amount;
  END IF;

  UPDATE accounts
  SET
    available_amount = accounts.available_amount + _amount
  WHERE
    accounts.id = _destination_account_id
  RETURNING accounts.locked_amount, accounts.available_amount INTO destination_locked_amount, destination_available_amount;

  RAISE NOTICE 'destination_locked_amount %, destination_available_amount %', destination_locked_amount, destination_available_amount;

  INSERT INTO transactions
    (
      amount,
      from_account_id,
      from_account_new_balance,
      to_account_id,
      to_account_new_balance,
      transaction_type,
      attributes
    )
  VALUES
    (
      _amount,
      _source_account_id,
      source_available_amount,
      _destination_account_id,
      destination_available_amount,
      (SELECT id FROM transaction_types WHERE transaction_type = 'Payment'),
      json_build_object('message', _message)
    );

  RETURN QUERY SELECT _source_account_id, source_locked_amount, source_available_amount;
  RETURN QUERY SELECT _destination_account_id, destination_locked_amount, destination_available_amount;

END;
$$ LANGUAGE plpgsql;
