const express = require('express');
const router = express.Router();

const v1 = require('./v1');

router.get('/api/v1/accounts.json', v1.accounts);

module.exports = router;
