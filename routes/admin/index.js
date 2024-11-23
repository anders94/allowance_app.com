const db = require('../../db');
const config = require('../../config');

const get = async (req, res) => {
    if (!req.session.user || !req.session.user.id || !req.session.user.attributes || !req.session.user.attributes.administrator)
        res.redirect('/');

    else {
        const accountsRes = await db.query(
	    `SELECT *
             FROM accounts
             WHERE user_id = $1`,
	    [req.session.user.id]);
	const usersRes = await db.query(
	    `SELECT
               id, full_name, created, email
             FROM
               users 
             WHERE obsolete = FALSE
             ORDER BY created DESC;`);

	res.render('admin', {
	    page: 'admin',
	    accounts: accountsRes.rows,
	    users: usersRes.rows
	});

    }

};

module.exports = {
    get: get

};
