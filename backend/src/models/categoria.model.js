const { pool } = require('../config/db');

// Devuelve la categoría solo si existe y está activa
const buscarActivaPorId = async (idCategoria) => {
  const [filas] = await pool.query(
    'SELECT id_categoria, nombre FROM categorias WHERE id_categoria = ? AND activa = 1',
    [idCategoria]
  );
  return filas[0] ?? null;
};

module.exports = { buscarActivaPorId };
