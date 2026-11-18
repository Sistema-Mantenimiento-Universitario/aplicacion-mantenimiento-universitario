const { pool } = require('../config/db');

const obtenerPrueba = (req, res) => {
  res.json({
    mensaje: 'El backend está funcionando',
    fecha: new Date().toISOString(),
  });
};

const probarBD = async (req, res) => {
  try {
    const [filas] = await pool.query(
      'SELECT DATABASE() AS base_de_datos, NOW() AS fecha_servidor'
    );
    res.json({
      ok: true,
      mensaje: 'Conexión con la base de datos exitosa',
      ...filas[0],
    });
  } catch (error) {
    console.error(`Error de base de datos: ${error.code || error.message}`);
    res.status(500).json({
      ok: false,
      mensaje: 'No se pudo conectar con la base de datos. Intenta más tarde.',
    });
  }
};

module.exports = { obtenerPrueba, probarBD };