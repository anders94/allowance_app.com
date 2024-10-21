const http = require('http');
const express = require('express');
const bodyParser = require('body-parser');
const session = require('express-session');
const datefns = require('date-fns');
const git = require('isomorphic-git');
const fs = require('fs');
const { v4 } = require('uuid');

const app = express();
const port = process.env.PORT ? process.env.PORT : 3000;
const host = process.env.HOST ? process.env.HOST : '0.0.0.0';

const routes = require('./routes');

(async () => {
    const commit = process.env.GIT_COMMIT ? process.env.GIT_COMMIT : await git.log({fs, dir: '.', depth: 1, ref: 'main'});

    app.set('view engine', 'pug');
    app.set('trust proxy', true);
    app.use(express.static('public'));
    app.use(bodyParser.json());
    app.use(bodyParser.urlencoded({extended: true}));

    app.use(session({
	store: new (require('connect-pg-simple')(session))({tableName: 'sessions'}),
	secret: process.env.COOKIE_SECRET || '9494bf79b057c96fbeb4f3e1c8037551',
	genid: req => v4(),
	resave: false,
	saveUninitialized: false,
	cookie: {
	    maxAge: 30 * 24 * 60 * 60 * 1000,       // 30 days
	    sameSite: app.get('env') === 'production' ? 'none' : 'lax',
	    secure: app.get('env') === 'production' // require https in production

	}

    }));

    const httpServer = http.createServer(app);
    const socket = require('./socket')(httpServer);

    app.use((req, res, next) => {
	res.locals.session = req.session;
	res.locals.datefns = datefns;
	res.locals.formatter = new Intl.NumberFormat('en-US', {style: 'currency', currency: 'USD'});
	res.locals.commit = commit[0].oid;
	console.log(req.ip, req.method, req.url);
	next();

    });

    app.use('/', routes);

    httpServer.listen(port, host, () => {
	console.log(`Listening on ${host}:${port}`)

    });

})();
