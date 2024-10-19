const db = require('../../db');

const index = async (req, res) => {
    const marketsRes = await db.query(`SELECT * FROM markets`);
    res.render('exchange', {
	page: 'exchange',
	markets: marketsRes.rows
    });

};

const market = async (req, res) => {
    const { base_symbol, quote_symbol } = req.params;

    const marketRes = await db.query(
	`SELECT *
         FROM markets
         WHERE base_symbol = $1
           AND quote_symbol = $2`,
	[base_symbol, quote_symbol]);

    if (marketRes.rows.length != 1)
	res.render('error', {message: 'Market not found!'});

    else {
	let accountsRes = [];
	if (req.session.user)
	    accountsRes = await db.query(
		`SELECT *
                 FROM accounts
                 WHERE user_id = $1
                 ORDER BY symbol DESC`,
		[req.session.user.id]
	    );

	let offersRes = [];
	if (req.session.user)
	    offersRes = offersRes = await db.query(
		`SELECT *
                 FROM offers
                 WHERE
                   (
                     base_account_id IN (SELECT id FROM accounts WHERE user_id = $1) OR 
                     quote_account_id IN (SELECT id FROM accounts WHERE user_id = $1)
                   )
                   AND market_id = $2
                   AND active = TRUE
                 ORDER BY created DESC`,
		[req.session.user.id, marketRes.rows[0].id]
	    );

	let fillsRes;
	if (req.session.user)
	    fillsRes = await db.query(
		`SELECT *
                 FROM fills
                 WHERE
                   (
                     base_account_id IN (SELECT id FROM accounts WHERE user_id = $1) OR 
                     quote_account_id IN (SELECT id FROM accounts WHERE user_id = $1)
                   )
                   AND market_id = $2
                 ORDER BY created DESC
                 LIMIT 50`,
		[req.session.user.id, marketRes.rows[0].id]
	    );
	else
	    fillsRes = await db.query(
		`SELECT *
                 FROM fills
                 WHERE
                   market_id = $1
                 ORDER BY created DESC
                 LIMIT 50`,
		[marketRes.rows[0].id]
	    );

	const bookRes = await db.query(
	    `SELECT
               side, price, SUM(unfilled) AS amount
             FROM offers
             WHERE market_id = $1
               AND active = true
             GROUP BY side, price
             ORDER BY price DESC`,
	    [marketRes.rows[0].id]);

	res.render('exchange/market', {
	    page: 'exchange',
	    market: marketRes.rows[0],
	    book: bookRes.rows,
	    accounts: accountsRes.rows,
	    offers: offersRes.rows,
	    fills: fillsRes.rows
	});

    }

};

const trade = async (req, res) => {
    const { base_symbol, quote_symbol } = req.params;
    const { side, price, amount } = req.body;

    if (!base_symbol || !quote_symbol || !side || !price || !amount) {
        console.log('Missing parameters. Got:', base_symbol, quote_symbol, side, price, amount);
        throw new Error('Sorry, we didn\'t get the parameters we were expecting. (side, price, amount)');
    }

    let fills, order;
    try {
        await db.query('BEGIN');
        await db.query(
	    `SELECT limit_order(
               (SELECT a.id 
                FROM accounts a 
                WHERE a.user_id = $1 
                  AND a.symbol = $2),
               (SELECT a.id 
                FROM accounts a 
                WHERE a.user_id = $1 
                  AND a.symbol = $3),
               (SELECT m.id 
                FROM markets m 
                WHERE m.base_symbol = $2 
                  AND m.quote_symbol = $3),
             $4, $5, $6, 'fills', 'order')`,
	    [req.session.user.id, base_symbol, quote_symbol, side, price, amount]
        );
        fills = await db.query('FETCH ALL IN "fills"');
        order = await db.query('FETCH ALL IN "order"');
        await db.query('COMMIT');

	// TODO: hint this back to the UI rather than reloading the page
	//console.log('fills', fills.rows);
	//console.log('order', order.rows);
	res.redirect('/exchange/' + base_symbol + '/' + quote_symbol);

    }
    catch(e) {
        db.query('ROLLBACK');
	console.log(e);
	res.render('error', {message: 'That trade isn\'t allowed!'});

    }

};

const cancel = async (req, res) => {
    const { base_symbol, quote_symbol, offer_id } = req.params;

    const offerRes = await db.query(
	`SELECT *
         FROM offers o
           LEFT JOIN accounts a ON o.base_account_id = a.id
         WHERE o.id = $1
           AND a.user_id = $2
           AND o.active = TRUE`,
	[offer_id, req.session.user.id]
    );

    if (offerRes.rows.length == 1) {
	await db.query('SELECT * FROM cancel_offer($1)', [offer_id]);
	res.redirect('/exchange/' + base_symbol + '/' + quote_symbol);

    }
    else
	res.render('error', {message: 'Offer not found!'});

};

module.exports = {
    index: index,
    market: market,
    trade: trade,
    cancel: cancel

};
