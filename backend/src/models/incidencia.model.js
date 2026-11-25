const { pool } = require('../config/db');
const { transicionPermitida } = require('../services/estado.service');

// Consulta base: incidencia con el nombre de su categoría, de quien reporta
// y del operador que la atiende (si ya tiene uno)
const SELECT_INCIDENCIA = `
  SELECT i.id_incidencia, i.titulo, i.descripcion, i.estado,
         i.id_usuario, i.id_categoria, i.id_operador,
         i.ubicacion_texto, i.latitud, i.longitud,
         i.solucion_descripcion,
         i.fecha_creacion, i.fecha_actualizacion, i.fecha_finalizacion,
         c.nombre AS categoria_nombre,
         u.nombre AS reportado_nombre,
         o.nombre AS operador_nombre
  FROM incidencias i
  JOIN categorias c ON c.id_categoria = i.id_categoria
  JOIN usuarios u ON u.id_usuario = i.id_usuario
  LEFT JOIN usuarios o ON o.id_usuario = i.id_operador`;

// Arma los objetos anidados definidos en docs/api.md
const formatearBase = (fila) => ({
  id_incidencia: fila.id_incidencia,
  titulo: fila.titulo,
  estado: fila.estado,
  categoria: { id_categoria: fila.id_categoria, nombre: fila.categoria_nombre },
  reportado_por: { id_usuario: fila.id_usuario, nombre: fila.reportado_nombre },
  operador: fila.id_operador
    ? { id_usuario: fila.id_operador, nombre: fila.operador_nombre }
    : null,
  ubicacion_texto: fila.ubicacion_texto,
});

// Elemento del listado
const formatearListado = (fila) => ({
  ...formatearBase(fila),
  fecha_creacion: fila.fecha_creacion,
});

// Detalle completo
const formatearDetalle = (fila) => ({
  ...formatearBase(fila),
  descripcion: fila.descripcion,
  latitud: fila.latitud,
  longitud: fila.longitud,
  solucion_descripcion: fila.solucion_descripcion,
  fecha_creacion: fila.fecha_creacion,
  fecha_actualizacion: fila.fecha_actualizacion,
  fecha_finalizacion: fila.fecha_finalizacion,
});

const buscarPorId = async (idIncidencia) => {
  const [filas] = await pool.query(
    `${SELECT_INCIDENCIA} WHERE i.id_incidencia = ?`,
    [idIncidencia]
  );
  return filas[0] ? formatearDetalle(filas[0]) : null;
};

// Crea la incidencia en estado pendiente y registra la creación en el historial.
// Las dos operaciones van en una transacción: o se guardan las dos o ninguna.
const crear = async (datos) => {
  const conexion = await pool.getConnection();
  try {
    await conexion.beginTransaction();

    const [resultado] = await conexion.execute(
      `INSERT INTO incidencias
         (titulo, descripcion, id_usuario, id_categoria, ubicacion_texto, latitud, longitud)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [
        datos.titulo,
        datos.descripcion,
        datos.id_usuario,
        datos.id_categoria,
        datos.ubicacion_texto,
        datos.latitud,
        datos.longitud,
      ]
    );

    await conexion.execute(
      `INSERT INTO historial (id_incidencia, id_usuario, accion, estado_anterior, estado_nuevo)
       VALUES (?, ?, 'creacion', NULL, 'pendiente')`,
      [resultado.insertId, datos.id_usuario]
    );

    await conexion.commit();
    return resultado.insertId;
  } catch (error) {
    await conexion.rollback();
    throw error;
  } finally {
    conexion.release();
  }
};

// Lista incidencias con filtros opcionales.
// Si viene idUsuario solo devuelve las de ese usuario (rol "usuario").
const listar = async ({ idUsuario, estado, idCategoria, q }) => {
  const condiciones = [];
  const parametros = [];

  if (idUsuario) {
    condiciones.push('i.id_usuario = ?');
    parametros.push(idUsuario);
  }
  if (estado) {
    condiciones.push('i.estado = ?');
    parametros.push(estado);
  }
  if (idCategoria) {
    condiciones.push('i.id_categoria = ?');
    parametros.push(idCategoria);
  }
  if (q) {
    // Se escapan % y _ para que se busquen como texto normal
    const patron = `%${q.replace(/[\\%_]/g, '\\$&')}%`;
    condiciones.push('(i.titulo LIKE ? OR i.descripcion LIKE ?)');
    parametros.push(patron, patron);
  }

  const where = condiciones.length ? `WHERE ${condiciones.join(' AND ')}` : '';

  const [filas] = await pool.query(
    `${SELECT_INCIDENCIA} ${where} ORDER BY i.fecha_creacion DESC, i.id_incidencia DESC`,
    parametros
  );
  return filas.map(formatearListado);
};

// Edita una incidencia. Solo se puede mientras esté pendiente; se comprueba
// dentro de la transacción (FOR UPDATE) para evitar cambios simultáneos.
const actualizar = async (idIncidencia, idUsuario, datos) => {
  const conexion = await pool.getConnection();
  try {
    await conexion.beginTransaction();

    const [filas] = await conexion.execute(
      'SELECT estado FROM incidencias WHERE id_incidencia = ? FOR UPDATE',
      [idIncidencia]
    );
    if (!filas[0] || filas[0].estado !== 'pendiente') {
      await conexion.rollback();
      return { ok: false };
    }

    await conexion.execute(
      `UPDATE incidencias
         SET titulo = ?, descripcion = ?, id_categoria = ?,
             ubicacion_texto = ?, latitud = ?, longitud = ?
       WHERE id_incidencia = ?`,
      [
        datos.titulo,
        datos.descripcion,
        datos.id_categoria,
        datos.ubicacion_texto,
        datos.latitud,
        datos.longitud,
        idIncidencia,
      ]
    );

    await conexion.execute(
      `INSERT INTO historial (id_incidencia, id_usuario, accion)
       VALUES (?, ?, 'edicion')`,
      [idIncidencia, idUsuario]
    );

    await conexion.commit();
    return { ok: true };
  } catch (error) {
    await conexion.rollback();
    throw error;
  } finally {
    conexion.release();
  }
};

// Cancela una incidencia pendiente (cancelación lógica: cambia el estado)
const cancelar = async (idIncidencia, idUsuario) => {
  const conexion = await pool.getConnection();
  try {
    await conexion.beginTransaction();

    const [filas] = await conexion.execute(
      'SELECT estado FROM incidencias WHERE id_incidencia = ? FOR UPDATE',
      [idIncidencia]
    );
    if (!filas[0] || filas[0].estado !== 'pendiente') {
      await conexion.rollback();
      return { ok: false };
    }

    await conexion.execute(
      "UPDATE incidencias SET estado = 'cancelada' WHERE id_incidencia = ?",
      [idIncidencia]
    );

    await conexion.execute(
      `INSERT INTO historial (id_incidencia, id_usuario, accion, estado_anterior, estado_nuevo)
       VALUES (?, ?, 'cambio_estado', 'pendiente', 'cancelada')`,
      [idIncidencia, idUsuario]
    );

    await conexion.commit();
    return { ok: true };
  } catch (error) {
    await conexion.rollback();
    throw error;
  } finally {
    conexion.release();
  }
};

// Conteo de incidencias por estado (solo las del usuario si viene idUsuario)
const resumen = async ({ idUsuario }) => {
  const where = idUsuario ? 'WHERE id_usuario = ?' : '';
  const [filas] = await pool.query(
    `SELECT estado, COUNT(*) AS total FROM incidencias ${where} GROUP BY estado`,
    idUsuario ? [idUsuario] : []
  );

  const conteo = { pendiente: 0, asignada: 0, en_proceso: 0, finalizada: 0, cancelada: 0 };
  let total = 0;
  for (const fila of filas) {
    conteo[fila.estado] = Number(fila.total);
    total += Number(fila.total);
  }
  return { ...conteo, total };
};

// Cambia el estado de una incidencia y lo registra en el historial.
const cambiarEstado = async (idIncidencia, idOperador, datos) => {
  const conexion = await pool.getConnection();
  try {
    await conexion.beginTransaction();

    // FOR UPDATE bloquea la fila: si dos operadores la cambian al mismo
    // tiempo, el segundo espera y ve el estado ya actualizado
    const [filas] = await conexion.execute(
      'SELECT estado FROM incidencias WHERE id_incidencia = ? FOR UPDATE',
      [idIncidencia]
    );
    if (!filas[0]) {
      await conexion.rollback();
      return { resultado: 'no_encontrada' };
    }

    const estadoAnterior = filas[0].estado;
    if (!transicionPermitida(estadoAnterior, datos.estado)) {
      await conexion.rollback();
      return { resultado: 'no_permitida', estadoAnterior };
    }

    if (datos.estado === 'asignada') {
      // El operador que la asigna queda como responsable
      await conexion.execute(
        "UPDATE incidencias SET estado = 'asignada', id_operador = ? WHERE id_incidencia = ?",
        [idOperador, idIncidencia]
      );
    } else if (datos.estado === 'finalizada') {
      // Regla del sistema: la solucion y la fecha de finalizacion van juntas
      await conexion.execute(
        `UPDATE incidencias
           SET estado = 'finalizada', solucion_descripcion = ?, fecha_finalizacion = NOW()
         WHERE id_incidencia = ?`,
        [datos.solucion_descripcion, idIncidencia]
      );
    } else {
      await conexion.execute(
        'UPDATE incidencias SET estado = ? WHERE id_incidencia = ?',
        [datos.estado, idIncidencia]
      );
    }

    await conexion.execute(
      `INSERT INTO historial
         (id_incidencia, id_usuario, accion, estado_anterior, estado_nuevo, comentario)
       VALUES (?, ?, 'cambio_estado', ?, ?, ?)`,
      [idIncidencia, idOperador, estadoAnterior, datos.estado, datos.comentario]
    );

    await conexion.commit();
    return { resultado: 'ok' };
  } catch (error) {
    await conexion.rollback();
    throw error;
  } finally {
    conexion.release();
  }
};

module.exports = { crear, buscarPorId, listar, actualizar, cancelar, resumen, cambiarEstado };
