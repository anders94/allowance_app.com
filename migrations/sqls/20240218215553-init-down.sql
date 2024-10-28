DROP FUNCTION IF EXISTS move_locked_funds(_source_account_id UUID, _destination_account_id UUID, _amount NUMERIC, _message TEXT);
DROP FUNCTION IF EXISTS unlock_funds(_account_id UUID, _amount NUMERIC);
DROP FUNCTION IF EXISTS lock_funds(_account_id UUID, _amount NUMERIC);
DROP FUNCTION IF EXISTS burn_funds(_account_id UUID, _amount NUMERIC);
DROP FUNCTION IF EXISTS mint_funds(_account_id UUID, _amount NUMERIC);

DROP TABLE IF EXISTS magic_links;
DROP TABLE IF EXISTS messages;
DROP TABLE IF EXISTS users2groups;
DROP TABLE IF EXISTS groups;
DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS transaction_types;
DROP TABLE IF EXISTS accounts;
DROP TABLE IF EXISTS assets;
DROP TABLE IF EXISTS sessions;
DROP TABLE IF EXISTS users;
