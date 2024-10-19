const db = require('../../db');

module.exports = async (req, res, next) => {
    try {
	const { uuid } = req.params;

	const magicResults = await db.query(
	    `UPDATE magic_links
               SET uses_remaining = uses_remaining - 1
             WHERE id = $1
               AND obsolete = false
               AND uses_remaining > 0
               AND expires_at > now()
             RETURNING *;`,
	    [uuid]);

	if (magicResults.rows.length !== 1) {
	    throw new Error('The URL you are using is no longer active.');
	}

	// log this session in if user_id defined
	if (magicResults.rows[0].user_id) {
	    const userResults = await db.query(
		`SELECT *
                 FROM users
                 WHERE id = $1
                   AND obsolete = FALSE`,
		[magicResults.rows[0].user_id]);

	    if (userResults.rows.length != 1)
		throw new Error('User not found!');

	    req.session.user = userResults.rows[0];
	}

	res.redirect(magicResults.rows[0].destination);

    }
    catch (e) {
	console.log(e);
	res.render('error', {error: e});
    }
    finally {
	return next;
    }
};
