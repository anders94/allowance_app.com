const { Server } = require('socket.io');

module.exports = async (http) => {
    const io = new Server(http);

    io.on('connection', (socket) => {
        socket.on('ping', async (msg) => {
	    console.log(msg);
	    socket.emit('pong', msg);
	    //io.emit('cmd', 'update');

	});

	socket.on('disconnect', () => {
	    console.log('user disconnected');

	});

    });

};
