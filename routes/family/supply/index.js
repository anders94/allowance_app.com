const db = require('../../../db');
const bcrypt = require('bcrypt');

const post = async (req, res, next) => {
    try {
	if (!req.session.user || !req.session.user.id)
	    throw new Error('Not authorized!');
	    
        const { accountID, symbol, amount, activity, password } = req.body;

        const userRes = await db.query(
	    `SELECT *
             FROM users
             WHERE id = $1
               AND (
                 attributes->>'administrator' = 'true'
                 OR
                 attributes->>'familyAdministrator' = 'true'
               )`,
	    [req.session.user.id]);

        if (userRes.rows.length != 1)
	    throw new Error('User not authorized!');

	if (await bcrypt.compare(password, userRes.rows[0].hashed_password)) {
	    const accountRes = await db.query(
		`SELECT *
                 FROM accounts
                 WHERE id = $1
                   AND user_id = $2;`,
		[accountID, req.session.user.id]);

	    if (accountRes.rows.length != 1)
		throw new Error('Invalid account ID!');

	    // looks good, let's mint / burn
	    if (activity == 'mint') {
		console.log('minting', amount, symbol, accountID);
		await db.query('SELECT mint_funds($1, $2);', [accountID, amount]);

	    }
	    else if (activity == 'burn') {
		console.log('burning', amount, symbol, accountID);
		await db.query('SELECT burn_funds($1, $2)', [acountID, amount]);

	    }
	    res.redirect('/admin');

	}
	else
	    throw new Error('Incorrect password!');

    }
    catch (e) {
	res.render('error', {message: e});

    }

};

module.exports = {
    post: post

};
