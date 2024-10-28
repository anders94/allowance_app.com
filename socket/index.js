const { Server } = require('socket.io');

const pgl = require('pg-listen');
const config = require('../config');

const pglSub = pgl(config.postgres);

pglSub.events.on('error', (error) => {
    console.error('pg-listen: Fatal database connection error:', error);
    pglSub.close();
    pglSub.connect();

});

process.on('exit', () => {
    pglSub.close();

});

module.exports = async (http) => {
    await pglSub.connect();

    const io = new Server(http);

    io.on('connection', (socket) => {
	let accountId;

	socket.on('sub', async (chan) => {
	    pglSub.notifications._events[chan] = [];
	    pglSub.notifications.on(chan, (payload) => {
		console.log(chan, payload);
		socket.emit(chan, payload);

	    });
	    await pglSub.listenTo(chan);
	    accountId = chan;
	    console.log('subscribed to', chan);

	});

	socket.on('unsub', async (chan) => {
	    pglSub.notifications._events[chan] = [];
	    await pglSub.unlisten(chan);
	    accountId = null;
	    console.log('unsubscribed from', chan);

	});

	socket.on('disconnect', async () => {
	    pglSub.notifications._events[accountId] = [];
	    await pglSub.unlisten(accountId);
	    console.log('user disconnected');

	});

    });

};
