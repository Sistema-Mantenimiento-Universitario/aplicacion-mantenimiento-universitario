const mysql = require('mysql2/promise');


const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT) || 3306,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  connectTimeout: 10000,
  decimalNumbers: true,
  // Las fechas viajan en UTC (la app las convierte con toLocal)
  timezone: 'Z',
});

// NOW() y CURRENT_TIMESTAMP también en UTC, sin importar la zona del servidor MySQL
pool.on('connection', (conexion) => {
  conexion.query("SET time_zone = '+00:00'");
});

const probarConexion = async () => {
  try {
    const conexion = await pool.getConnection();
    await conexion.ping();
    conexion.release();
    console.log(
      `Conexión con MySQL exitosa (base "${process.env.DB_NAME}" en ${process.env.DB_HOST || 'localhost'}:${process.env.DB_PORT || 3306})`
    );
    return true;
  } catch (error) {
    console.error(`No se pudo conectar con MySQL: ${error.code || error.message}`);
    console.error(
      'Revisa que MySQL esté encendido, que la base exista y que las variables DB_* del archivo .env sean correctas.'
    );
    return false;
  }
};

module.exports = { pool, probarConexion };
