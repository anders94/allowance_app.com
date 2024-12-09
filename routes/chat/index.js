const db = require('../../db');

/*
CREATE TABLE groups (
  id                       UUID            NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  created                  TIMESTAMP       NOT NULL DEFAULT now(),
  title                    TEXT            NOT NULL,
  attributes               JSONB           NOT NULL DEFAULT '{}'::JSONB,
  obsolete                 BOOLEAN         NOT NULL DEFAULT FALSE
) WITH (OIDS=FALSE);

CREATE TABLE users2groups (
  created                  TIMESTAMP       NOT NULL DEFAULT now(),
  user_id                  UUID            NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  group_id                 UUID            NOT NULL REFERENCES groups(id) ON DELETE RESTRICT,
  obsolete                 BOOLEAN         NOT NULL DEFAULT FALSE,
  CONSTRAINT               pk_users2groups PRIMARY KEY (user_id, group_id)
) WITH (OIDS=FALSE);

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

 */

const get = async (req, res, next) => {
    if (req.session.user && req.session.user.id) {
	const accountRes = await db.query('SELECT * FROM accounts WHERE user_id = $1 ORDER BY created ASC', [req.session.user.id]);
	const transactionRes = await db.query(
	    `WITH transactions AS (
               SELECT
                 t.id, t.created, t.amount, t.attributes,
                 tt.transaction_type AS transaction_type_word,
                 fu.full_name AS from_full_name,
                 tu.full_name AS to_full_name,
                 tu.id != $1 AS withdrawal
               FROM transactions t
                 LEFT JOIN transaction_types tt ON t.transaction_type = tt.id
                 LEFT JOIN accounts fa ON t.from_account_id = fa.id
                 LEFT JOIN users fu ON fa.user_id = fu.id
                 LEFT JOIN accounts ta ON t.to_account_id = ta.id
                 LEFT JOIN users tu ON ta.user_id = tu.id
               WHERE
                 t.from_account_id IN (SELECT id FROM accounts WHERE user_id = $1) OR
                 t.to_account_id IN (SELECT id FROM accounts WHERE user_id = $1)
               ORDER BY t.created ASC
             )
             SELECT *
             FROM transactions
             OFFSET (
               CASE WHEN (SELECT count(*) FROM transactions) <= 10
                 THEN 10
                 ELSE (SELECT count(*) FROM transactions)
               END
             ) - 10
             LIMIT 10`,
	    [req.session.user.id]);
	const usersRes = await db.query(
	    `WITH txs AS (
               SELECT DISTINCT CASE
                 WHEN from_account_id IN (SELECT id FROM accounts WHERE user_id = $1)
                 THEN
                   to_account_id
                 ELSE
                   from_account_id
                 END AS account_id
               FROM transactions
               WHERE
                 from_account_id IN (SELECT id FROM accounts WHERE user_id = $1) OR
                 to_account_id IN (SELECT id FROM accounts WHERE user_id = $1)
             )
             SELECT
               a.id AS id,
               CONCAT(u.full_name, ' - ', a.attributes->>'name') AS name
             FROM txs
               LEFT JOIN accounts a ON txs.account_id = a.id
               LEFT JOIN users u ON a.user_id = u.id
             ORDER BY u.full_name ASC`,
	    [req.session.user.id]);

	res.render('chat', {
	    page: 'chat',
	    account: accountRes.rows[0],
	    users: usersRes.rows,
	    transactions: transactionRes.rows
	});

    }
    else
        res.redirect('/');

};

const post = async (req, res, next) => {
    if (req.session.user && req.session.user.id) {
	try {
            const { accountAction, accountID,
		    accountSymbol, accountName } = req.body;

            if (!accountAction || accountAction == '' ||
		!accountSymbol || accountSymbol == '' ||
		!accountName)
		throw new Error('We didn\'t get all of the expected fields from you!');

	    if (accountAction == 'create') {
		await db.query(
		    `INSERT INTO accounts
                       (user_id, symbol, attributes)
                     VALUES
                       ($1, $2, $3)`,
		    [req.session.user.id, accountSymbol, {name: accountName}]
		);

	    }
	    else if (accountAction == 'update') {
		await db.query(
		    `UPDATE accounts
                     SET attributes = $1
                     WHERE id = $2
                       AND user_id = $3`,
		    [{name: accountName}, accountID, req.session.user.id]
		);

	    }
	    res.redirect('/chat');

	}
	catch (e) {
	    res.render('error', {message: e});

	}

    }	
    else
        res.redirect('/');

};

module.exports = {
    get: get,
    post: post

};
