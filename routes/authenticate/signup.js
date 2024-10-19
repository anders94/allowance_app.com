const db = require('../../db');
const bcrypt = require('bcrypt');
const config = require('../../config');
//const email = require('../../helpers/email');
const { validationResult } = require('express-validator');

const post = async (req, res) => {
    try {
	const errors = validationResult(req);

	if (!errors.isEmpty())
	    throw new Error(errors.array()[0].msg);

        const { fullName, signupEmail, signupPassword } = req.body;

	if (fullName && signupEmail && signupPassword)
	    console.log('signup', fullName, signupEmail, 'xxx');
	else {
	    console.log('Expected fullName, signupEmail, signupPassword but got', fullName, signupEmail, signupPassword);
	    throw new Error('We didn\'t get all of the expected fields from you! We\'re expecting fullName, signupEmail, and signupPassword.');

	}

	const hashedPassword = await bcrypt.hash(signupPassword, 8);

	await db.query('BEGIN');
	const userResults = await db.query(
	    `INSERT INTO users
               (full_name, email, hashed_password, attributes)
             VALUES
               ($1, $2, $3, $4)
             RETURNING
               *;`,
	    [fullName, signupEmail, hashedPassword, {emailVerified: true}]);
	// TODO: update emailVerified to true above and uncomment the magic stuff below when email is working

	/*
	const magicResults = await db.query(
	    `INSERT INTO magic_links
               (destination, user_id)
             VALUES
               ($1, $2)
             RETURNING
               id;`,
	    ['/email/verify', userResults.rows[0].id]);

	console.log('user has to verify their email by hitting: /magic/'+magicResults.rows[0].id);
	//email.send('"Radius Support" <support@gl1.com>', signupEmail, 'signup', {name: name, link: 'https://gl1.com/magic/'+magicResults.rows[0].id});
	*/

	await db.query(
	    `INSERT INTO accounts
               (created, user_id, symbol, attributes)
             VALUES
               (now() - '1 second'::interval, (SELECT id FROM users WHERE email=$1), $2, $3)`,
	    [signupEmail, 'USD', {name: 'Spending'}]);

	await db.query('COMMIT');

	req.session.user = userResults.rows[0]; // TODO: we're logging the user in here - don't do this if email verification is a requirement

	console.log('user', req.session.user.id, '/', signupEmail, 'created');

	res.render('authenticate/signup/thanks', {
	    title: 'Thanks ' + fullName + ', you are all signed up and logged in!'

	});

    }
    catch (e) {
	await db.query('ROLLBACK');

	console.log(e);

	if (e.code === '23505') // duplicate key
	    res.render('error', {message: 'Email address already signed up!'});
	else
	    res.render('error', {message: e});

    }

};

module.exports = {
    post: post
};
