const db = require('../../db');
const bcrypt = require('bcrypt');

module.exports = {
    post: async (req, res) => {
        const { loginEmail, loginPassword } = req.body;

	let tmp = await db.query(
	    `SELECT u.*, f.moniker
             FROM users u
               LEFT JOIN families f ON u.family_id = f.id
             WHERE u.email = $1`,
	    [loginEmail]);

	if (tmp.rows.length != 1)
	    res.render('authenticate/emailPasswordIncorrect');

	else {
	    if (await bcrypt.compare(loginPassword, tmp.rows[0].hashed_password)) {
		req.session.user = tmp.rows[0];

		res.redirect('/chat');

	    }
	    else
		res.render('authenticate/emailPasswordIncorrect');

	}

    }

};
