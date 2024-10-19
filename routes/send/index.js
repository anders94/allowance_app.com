const db = require('../../db');

const post = async (req, res, next) => {
    if (req.session.user && req.session.user.id) {
	try {
            const { from, to, amount, message } = req.body;
	    console.log('from:', from, 'to:', to, 'amount:', amount, 'message:', message);

            if (!from || from == '' || !to || to == '' || !amount || amount == '')
		throw new Error('We didn\'t get all of the expected fields!');

	    if (Number(amount) <= 0)
		throw new Error('The amount can\'t be negative!');

            let accountRes;

	    accountRes = await db.query(
		'SELECT id FROM accounts WHERE id = $1 AND user_id = $2',
		[from, req.session.user.id]);

	    if (accountRes.rows.length != 1)
		throw new Error('That doesn\'t look like you are trying to send from an account you own!');

	    accountRes = await db.query(
		`SELECT a2.significant_digits
                 FROM accounts a1
                   LEFT JOIN assets a2 ON a1.symbol = a2.symbol
                 WHERE id = $1`,
		[to]);

	    if (accountRes.rows.length != 1)
		throw new Error('The account you are sending to doesn\'t seem to exist!');

	    if (Number(Number(amount).toFixed(accountRes.rows[0].significant_digits)) != Number(amount))
		throw new Error('You are specifying more than ' + accountRes.rows[0].significant_digits +
				' significant digits! You could try ' +
				Number(amount).toFixed(accountRes.rows[0].significant_digits) + ' instead.');

	    await db.query('BEGIN');
	    await db.query('SELECT lock_funds($1, $2)', [from, amount]);
	    await db.query('SELECT move_locked_funds($1, $2, $3, $4)', [from, to, amount, message]);
	    await db.query('COMMIT');

	    res.redirect('/account');

	}
	catch (e) {
	    await db.query('ROLLBACK');
	    res.render('error', {message: e});

	}

    }	
    else
        res.redirect('/');

};

module.exports = {
    post: post

};
