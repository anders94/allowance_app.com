const qrcode = require('qrcode-svg');

const get = async (req, res) => {
    const { data } = req.params;

    if (data && data.length <= 2420) {
	const code = new qrcode({
	    content: data,
	    padding: 4,
	    width: 256,
	    height: 256,
	    color: '#000000',
	    background: '#ffffff',
	    ecl: 'Q'});

	res.set('Content-type', 'image/svg+xml');
	res.send(code.svg());

    }
    else
	res.render('error', {error: 'Missing or too much data!'});

};

module.exports = {
    get: get

};
