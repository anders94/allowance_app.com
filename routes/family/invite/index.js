const db = require('../../../db');
const { validationResult } = require('express-validator');
const bcrypt = require('bcrypt');

const get = async (req, res, next) => {
    const { familyID } = req.params;

    console.log(familyID);
    const familyRes = await db.query('SELECT * FROM families WHERE id = $1', [familyID]);

    if (familyRes.rows.length > 0)
	res.render('invite', {family: familyRes.rows[0]});
    else
	res.render('error', {message: 'Sorry, that link doesn\'t look right!'});

};

const post = async (req, res) => {
    try {
        const errors = validationResult(req);

        if (!errors.isEmpty())
            throw new Error(errors.array()[0].msg);

        const { familyID, name, email, password } = req.body;

        if (familyID, name && email && password)
            console.log('invite', familyID, name, email, 'xxx');
        else {
            console.log('Expected familyID, name, email, password but got', familyID, name, email, password);
            throw new Error('We didn\'t get all of the expected fields from you! We\'re expecting familyID, name, email, and password.');

        }

        const hashedPassword = await bcrypt.hash(password, 8);

        await db.query('BEGIN');

        const userResults = await db.query(
            `INSERT INTO users
               (full_name, family_id, email, hashed_password, attributes)
             VALUES
               ($1, $2, $3, $4, $5)
             RETURNING
               *;`,
            [name, familyID, email, hashedPassword, {}]);
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
            [email, 'USD', {name: 'Spending'}]);

        await db.query('COMMIT');

	const familyRes = await db.query('SELECT * FROM families WHERE id = $1', [familyID]);

        req.session.user = userResults.rows[0]; // TODO: we're logging the user in here - don't do this if email verification is a requirement
	req.session.user.moniker = familyRes.rows[0].moniker;

        console.log('user', req.session.user.id, '/', email, 'created');

        res.render('authenticate/signup/thanks', {
            title: 'Thanks ' + name + ', you are all signed up and logged in!'

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
    get: get,
    post: post

};
