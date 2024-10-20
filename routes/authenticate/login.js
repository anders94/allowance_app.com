const db = require('../../db');
const bcrypt = require('bcrypt');

module.exports = {
    post: async (req, res) => {
        const { loginEmail, loginPassword } = req.body;

	let tmp = await db.query('SELECT * FROM users WHERE email=$1', [loginEmail]);

	if (tmp.rows.length != 1)
	    res.render('authenticate/emailPasswordIncorrect');

	else {
	    if (await bcrypt.compare(loginPassword, tmp.rows[0].hashed_password)) {
		req.session.user = tmp.rows[0];

		res.redirect('/account');

	    }
	    else
		res.render('authenticate/emailPasswordIncorrect');

	}

    }

};
