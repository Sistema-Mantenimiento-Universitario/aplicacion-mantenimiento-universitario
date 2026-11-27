const { pool } = require("../config/db");

const COLUMNAS = "id_usuario, nombre, correo, password_hash, rol, activo";

const buscarPorCorreo = async (correo) => {
  const [filas] = await pool.query(`SELECT ${COLUMNAS} FROM usuarios WHERE correo = ?`, [correo]);
  return filas[0] ?? null;
};

const buscarPorId = async (idUsuario) => {
  const [filas] = await pool.query(`SELECT ${COLUMNAS} FROM usuarios WHERE id_usuario = ?`, [idUsuario]);
  return filas[0] ?? null;
};

module.exports = { buscarPorCorreo, buscarPorId };
