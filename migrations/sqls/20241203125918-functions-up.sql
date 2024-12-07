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

  IF _amount <= 0 THEN
    RAISE EXCEPTION 'mint_funds(%, %): Amount must be a positive number.', _account_id, _amount;
  END IF;

  UPDATE accounts a
  SET
    available_amount = a.available_amount + _amount
  WHERE
    a.id = _account_id 
  RETURNING a.available_amount INTO available_amount;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'mint_funds(%, %): Account does not exist.', _account_id, _amount;
  END IF;

  EXECUTE FORMAT('NOTIFY "%s"', _account_id);

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

  IF _amount <= 0 THEN
    RAISE EXCEPTION 'burn_funds(%, %): Amount must be a positive number.', _account_id, _amount;
  END IF;

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

  EXECUTE FORMAT('NOTIFY "%s"', _account_id);

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

  IF _amount <= 0 THEN
    RAISE EXCEPTION 'lock_funds(%, %): Amount must be a positive number.', _account_id, _amount;
  END IF;


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

  EXECUTE FORMAT('NOTIFY "%s"', _account_id);

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

  IF _amount <= 0 THEN
    RAISE EXCEPTION 'unlock_funds(%, %): Amount must be a positive number.', _account_id, _amount;
  END IF;

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

  EXECUTE FORMAT('NOTIFY "%s"', _account_id);

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

  IF _amount <= 0 THEN
    RAISE EXCEPTION 'move_locked_funds(%, %, %): Amount must be a positive number.', _source_account_id, _destination_account_id, _amount;
  END IF;

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
    locked_amount = accounts.locked_amount + _amount
  WHERE
    accounts.id = _destination_account_id
  RETURNING accounts.locked_amount, accounts.available_amount INTO destination_locked_amount, destination_available_amount;

  RAISE NOTICE 'destination_locked_amount %, destination_available_amount %', destination_locked_amount, destination_available_amount;

  EXECUTE FORMAT('NOTIFY "%s"', _destination_account_id);

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
  -- NOTE: this records source and destination AVAILABLE amount in the
  -- transaction table. there can be discrepancies if the funds remain
  -- locked for a long time so this should be treated as informational.

  RETURN QUERY SELECT _source_account_id, source_locked_amount, source_available_amount;
  RETURN QUERY SELECT _destination_account_id, destination_locked_amount, destination_available_amount;

END;
$$ LANGUAGE plpgsql;

-- --------------------------------------------------------
-- -- Function: Escrow Funds
-- --------------------------------------------------------

CREATE FUNCTION escrow_funds(_account_id UUID, _amount NUMERIC)
  RETURNS TABLE (escrow_id UUID)
AS $$
BEGIN
  RAISE NOTICE 'escrow_funds(%, %)', _account_id, _amount;

  IF _amount <= 0 THEN
    RAISE EXCEPTION 'escrow_funds(%, %): Amount must be a positive number.', _account_id, _amount;
  END IF;

  IF _amount <= 0 THEN
    RAISE EXCEPTION 'escrow_funds(%, %): Amount must be above 0.', _account_id, _amount;
  END IF;

  IF (SELECT a.available_amount FROM accounts a WHERE a.id = _account_id) < _amount THEN
    RAISE EXCEPTION 'escrow_funds(%, %): Account lacks sufficient available funds.', _account_id, _amount;
  END IF;

  UPDATE accounts a
  SET
    available_amount = a.available_amount - _amount
  WHERE
    a.id = _account_id;

  RETURN QUERY
  INSERT INTO escrows
    (account_id, amount)
  VALUES
    (_account_id, _amount)
  RETURNING id;

END;
$$ LANGUAGE plpgsql;

-- --------------------------------------------------------
-- -- Function: Unescrow Funds
-- --------------------------------------------------------
CREATE FUNCTION unescrow_funds(_escrow_id UUID)
  RETURNS TABLE (account_id UUID, available_amount NUMERIC, locked_amount NUMERIC)
AS $$
DECLARE
  _amount NUMERIC;
  _account_id UUID;
BEGIN
  RAISE NOTICE 'unescrow_funds(%)', _escrow_id;

  SELECT
    e.account_id, e.amount
  FROM escrows e
  WHERE
    e.id = _escrow_id
  INTO _account_id, _amount;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'unescrow_funds(%): Escrow does not exist!', _escrow_id;
  END IF;

  UPDATE accounts a
  SET
    available_amount = a.available_amount + _amount
  WHERE
    id = _account_id;

  DELETE FROM escrows WHERE id = _escrow_id;

  RETURN QUERY SELECT a.id, a.available_amount, a.locked_amount FROM accounts a WHERE a.id = _account_id;

END;
$$ LANGUAGE plpgsql;

-- --------------------------------------------------------
-- -- Function: Move Escrowed Funds
-- --------------------------------------------------------
--
-- Changes ownership of an escrow to a new account

CREATE FUNCTION move_escrowed_funds(_escrow_id UUID, _destination_account_id UUID, _message TEXT)
  RETURNS void
AS $$
DECLARE
  source_account_id UUID;
BEGIN
  RAISE NOTICE 'move_escrowed_funds(%, %)', _escrow_id, _destination_account_id;

  IF (SELECT
    (SELECT a.symbol
     FROM escrows e
       LEFT JOIN accounts a ON e.account_id = a.id
     WHERE e.id = _escrow_id) !=
    (SELECT symbol
     FROM accounts
     WHERE id = _destination_account_id))
  THEN
    RAISE EXCEPTION 'move_locked_funds(%, %, %): Source and destination account currencies differ.', _source_account_id, _destination_account_id, _amount;
  END IF;

  UPDATE escrows
  SET
    account_id = _destination_account_id
  WHERE
    id = _escrow_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'move_escrowed_funds(%, %): Source account does not exist.', _escrow_id, _destination_account_id;
  END IF;

END;
$$ LANGUAGE plpgsql;
