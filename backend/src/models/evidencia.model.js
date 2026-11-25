const { pool } = require('../config/db');

const SELECT_EVIDENCIA = `
  SELECT id_evidencia, tipo, ruta_archivo, nombre_original, mime_type, fecha_subida
  FROM evidencias`;

// La BD guarda la ruta del archivo; el contrato responde la url pública
const formatear = (fila) => ({
  id_evidencia: fila.id_evidencia,
  tipo: fila.tipo,
  url: `/uploads/${fila.ruta_archivo}`,
  nombre_original: fila.nombre_original,
  mime_type: fila.mime_type,
  fecha_subida: fila.fecha_subida,
});

const listarPorIncidencia = async (idIncidencia) => {
  const [filas] = await pool.query(
    `${SELECT_EVIDENCIA} WHERE id_incidencia = ? ORDER BY fecha_subida ASC, id_evidencia ASC`,
    [idIncidencia]
  );
  return filas.map(formatear);
};

// Registra las imágenes en una transacción: se guardan todas o ninguna
const crear = async (idIncidencia, idUsuario, tipo, archivos) => {
  const ids = [];
  const conexion = await pool.getConnection();
  try {
    await conexion.beginTransaction();
    for (const archivo of archivos) {
      const [resultado] = await conexion.execute(
        `INSERT INTO evidencias
           (id_incidencia, id_usuario, tipo, ruta_archivo, nombre_original, mime_type)
         VALUES (?, ?, ?, ?, ?, ?)`,
        [
          idIncidencia,
          idUsuario,
          tipo,
          archivo.ruta_archivo,
          archivo.nombre_original,
          archivo.mime_type,
        ]
      );
      ids.push(resultado.insertId);
    }
    await conexion.commit();
  } catch (error) {
    await conexion.rollback();
    throw error;
  } finally {
    conexion.release();
  }

  const [filas] = await pool.query(
    `${SELECT_EVIDENCIA} WHERE id_evidencia IN (?) ORDER BY id_evidencia`,
    [ids]
  );
  return filas.map(formatear);
};

module.exports = { listarPorIncidencia, crear };
