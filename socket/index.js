const { Server } = require('socket.io');
const pgl = require('pg-listen');
const redis = require('redis');
const config = require('../config');

const pglSub = pgl(config.postgres);

process.on('exit', async () => {
    await pglSub.close();
    await rcPub.quit();

});

module.exports = async (http) => {
    await pglSub.connect();
    pglSub.events.on('error', async (error) => {
	console.error('pg-listen: Fatal database connection error:', error);
	await pglSub.close();
	setTimeout(async () => {
	    await pglSub.connect();
	    // TODO: check to make sure we connected and then re-establish all our listens

	}, 100);

    });

    const io = new Server(http);
    io.on('connection', async (socket) => {
	const rcSub = redis.createClient({socket: config.redis});
	await rcSub.connect();
	rcSub.on('error', error => {
            console.error(`Redis client error:`, error);

	});

	socket.on('sub', async (chan) => {
	    console.log('subscribe', chan);
	    if (!pglSub.notifications._events[chan]) {
		const rcPub = redis.createClient({socket: config.redis});
		await rcPub.connect();
		rcPub.on('error', error => {
		    console.error(`Redis client error:`, error);

		});

		await pglSub.notifications.on(chan, (payload) => {
		    console.log(chan, payload);
		    rcPub.publish(chan, 'updated');

		});
		await pglSub.listenTo(chan);

	    }
	    rcSub.subscribe(chan, (msg) => {
		socket.emit(chan, msg);

	    });

	});

	socket.on('unsub', async (chan) => {
	    // leave the publisher because someone else might still be listening
	    //pglSub.notifications._events[chan] = [];
	    //await pglSub.unlisten(chan);
	    await rcSub.quit();
	    console.log('unsubscribed from', chan);

	});

	socket.on('disconnect', async () => {
	    // leave the publisher because someone else might still be listening
	    //pglSub.notifications._events[accountId] = [];
	    //await pglSub.unlisten(accountId);
	    await rcSub.quit();
	    console.log('user disconnected');

	});

    });

};
