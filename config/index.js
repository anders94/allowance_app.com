module.exports = {
    postgres: {
	host: process.env.PGHOST || 'localhost',
	database: process.env.PGDATABASE || 'bnk_dev',
	user: process.env.PGUSER || 'bnk',
	port: process.env.PGPORT || 5432,
	password: process.env.PGPASSWORD || 'supersecretpassword',
	ssl: false,
	debug: false
    }

}
