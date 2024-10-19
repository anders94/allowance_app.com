module.exports = {
    get: async (req, res) => {
	req.session.user = null;
	res.redirect('/');

    }

};
