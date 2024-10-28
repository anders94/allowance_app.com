const db = require('../../../db');

const get = async (req, res, next) => {
    if (req.session.user && req.session.user.id) {
	const accountRes = await db.query('SELECT * FROM accounts WHERE user_id = $1 ORDER BY created ASC', [req.session.user.id]);

	res.send(accountRes.rows);

    }
    else
        res.send({error: 'unauthorized'});

};

module.exports = {
    get: get

};
