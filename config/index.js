module.exports = {
    postgres: {
	host: process.env.PGHOST || 'localhost',
	database: process.env.PGDATABASE || 'allowance_app_dev',
	user: process.env.PGUSER || 'allowance_app',
	port: process.env.PGPORT || 5432,
	password: process.env.PGPASSWORD || 'supersecretpassword',
	ssl: false,
	debug: false

    },
    redis: {
	host: process.env.REDISHOST || 'localhost',
	port: process.env.REDISPORT || 6379

    }

}
