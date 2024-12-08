const express = require('express');
const router = express.Router();

const authenticate = require('./authenticate');
const chat = require('./chat');
const api = require('./api');
const send = require('./send');
const admin = require('./admin');
const family = require('./family');
const profile = require('./profile');
const qrcode = require('./qrcode');

router.get('/', async (req, res) => {
    if (req.session.user && req.session.user.id)
	res.redirect('/chat');
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

router.get('/chat', chat.get);
router.post('/chat', chat.post);

router.get('/api/*', api);

router.post('/send', send.post);

router.get('/admin', admin.get);

router.get('/family', family.get);
router.post('/family/supply', family.supply.post);
router.get('/family/invite/:familyID', family.invite.get);
router.post('/family/invite', family.invite.post);

router.post('/authenticate/signup', authenticate.signup.post);
router.post('/authenticate/login', authenticate.login.post);
router.get('/authenticate/logout', authenticate.logout.get);
router.post('/authenticate/forgotPassword', authenticate.forgotPassword.post);

router.get('/qrcode/:data.svg', qrcode.get);

module.exports = router;
