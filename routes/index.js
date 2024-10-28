const express = require('express');
const router = express.Router();

const authenticate = require('./authenticate');
const account = require('./account');
const api = require('./api');
const send = require('./send');
const admin = require('./admin');
const profile = require('./profile');
const qrcode = require('./qrcode');

router.get('/', async (req, res) => {
    if (req.session.user && req.session.user.id)
	res.redirect('/account');
    else
	res.render('index', {
	    page: 'home'
	});
});

router.get('/stats', (req, res) => {
    res.json({commit: res.locals.commit});
});

router.get('/profile', profile.get);
router.post('/profile', profile.post);

router.get('/account', account.get);
router.post('/account', account.post);

router.get('/api/*', api);

router.post('/send', send.post);

router.get('/admin', admin.get);
router.post('/admin/supply', admin.supply.post);

router.post('/authenticate/signup', authenticate.signup.post);
router.post('/authenticate/login', authenticate.login.post);
router.get('/authenticate/logout', authenticate.logout.get);
router.post('/authenticate/forgotPassword', authenticate.forgotPassword.post);

router.get('/qrcode/:data.svg', qrcode.get);

module.exports = router;
