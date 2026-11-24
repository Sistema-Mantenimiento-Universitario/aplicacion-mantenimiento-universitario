const { pool } = require('../config/db');

const listarPorIncidencia = async (idIncidencia) => {
  const [filas] = await pool.query(
    `SELECT h.id_historial, h.accion, h.estado_anterior, h.estado_nuevo,
            h.comentario, h.fecha,
            u.id_usuario, u.nombre AS responsable_nombre
     FROM historial h
     JOIN usuarios u ON u.id_usuario = h.id_usuario
     WHERE h.id_incidencia = ?
     ORDER BY h.fecha ASC, h.id_historial ASC`,
    [idIncidencia]
  );

  return filas.map((fila) => ({
    id_historial: fila.id_historial,
    accion: fila.accion,
    estado_anterior: fila.estado_anterior,
    estado_nuevo: fila.estado_nuevo,
    comentario: fila.comentario,
    fecha: fila.fecha,
    responsable: { id_usuario: fila.id_usuario, nombre: fila.responsable_nombre },
  }));
};

module.exports = { listarPorIncidencia };
