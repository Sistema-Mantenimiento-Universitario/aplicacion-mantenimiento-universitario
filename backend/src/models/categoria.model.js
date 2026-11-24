const { pool } = require('../config/db');

const formatear = (fila) => ({
  id_categoria: fila.id_categoria,
  nombre: fila.nombre,
  descripcion: fila.descripcion,
  activa: Boolean(fila.activa),
});

const listar = async ({ soloActivas }) => {
  const where = soloActivas ? 'WHERE activa = 1' : '';
  const [filas] = await pool.query(
    `SELECT id_categoria, nombre, descripcion, activa FROM categorias ${where} ORDER BY nombre`
  );
  return filas.map(formatear);
};

const buscarPorId = async (idCategoria) => {
  const [filas] = await pool.query(
    'SELECT id_categoria, nombre, descripcion, activa FROM categorias WHERE id_categoria = ?',
    [idCategoria]
  );
  return filas[0] ? formatear(filas[0]) : null;
};

const buscarActivaPorId = async (idCategoria) => {
  const [filas] = await pool.query(
    'SELECT id_categoria, nombre FROM categorias WHERE id_categoria = ? AND activa = 1',
    [idCategoria]
  );
  return filas[0] ?? null;
};

const crear = async ({ nombre, descripcion }) => {
  const [resultado] = await pool.execute(
    'INSERT INTO categorias (nombre, descripcion) VALUES (?, ?)',
    [nombre, descripcion]
  );
  return resultado.insertId;
};

const actualizar = async (idCategoria, { nombre, descripcion, activa }) => {
  await pool.execute(
    'UPDATE categorias SET nombre = ?, descripcion = ?, activa = ? WHERE id_categoria = ?',
    [nombre, descripcion, activa ? 1 : 0, idCategoria]
  );
};

module.exports = { listar, buscarPorId, buscarActivaPorId, crear, actualizar };
