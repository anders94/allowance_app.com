const db = require('../../db');
const helpers = require('../../helpers');
const bcrypt = require('bcrypt');

const get = async (req, res, next) => {
    if (req.session.user && req.session.user.id) {
	res.render('profile', {page: 'profile'});

    }
    else
        res.redirect('/');

};

const post = async (req, res, next) => {
    if (req.session.user && req.session.user.id) {
	try {
            const { fullName, password } = req.body;

            if (!fullName)
		throw new Error('We didn\'t get all of the expected fields from you! We\'re expecting fullName and password.');

	    if (fullName == '')
		throw new Error('You\'re name can\'t be blank.');

            await db.query(
		`UPDATE users 
                 SET full_name = $2 
                 WHERE id = $1;`,
		[req.session.user.id, fullName]);

	    req.session.user.full_name = fullName;

	    if (password) {
		const hashedPassword = await bcrypt.hash(password, 8);
		await db.query(
                    `UPDATE users 
                     SET hashed_password = $2 
                     WHERE id = $1;`,
		    [req.session.user.id, hashedPassword]);

	    }
	    res.redirect('/profile');

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
