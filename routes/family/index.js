const db = require('../../db');
const config = require('../../config');
const supply = require('./supply');
const invite = require('./invite');

const get = async (req, res) => {
    if (!req.session.user || !req.session.user.id || !req.session.user.attributes || !req.session.user.attributes.familyAdministrator)
        res.redirect('/');

    else {
        const accountsRes = await db.query(
	    `SELECT *
             FROM accounts
             WHERE user_id = $1`,
	    [req.session.user.id]);

	if (accountsRes.rows.length == 0)
	    throw new Error('User '+ req.session.user.id + ' has no account.');

	const usersRes = await db.query(
	    `SELECT
               *
             FROM
               users 
             WHERE obsolete = FALSE
               AND family_id = $1
             ORDER BY created DESC`,
	    [req.session.user.family_id]);

	const familyRes = await db.query(
	    `SELECT *
             FROM families
             WHERE id = $1`,
	    [req.session.user.family_id]);

	if (familyRes.rows.length == 0)
	    throw new Error('User '+ req.session.user.id + ' has no family record.');

	res.render('family', {
	    page: 'family',
	    account: accountsRes.rows[0],
	    users: usersRes.rows,
	    family: familyRes.rows[0]
	});

    }

};

module.exports = {
    get: get,
    supply: supply,
    invite: invite
};
