const incidenciaModel = require('../models/incidencia.model');
const categoriaModel = require('../models/categoria.model');

const ESTADOS = ['pendiente', 'asignada', 'en_proceso', 'finalizada', 'cancelada'];

const respuestaInvalida = (res, errores) =>
  res.status(400).json({ ok: false, mensaje: 'Datos inválidos', errores });

const errorInterno = (res, error) => {
  console.error(error);
  return res.status(500).json({ ok: false, mensaje: 'Error interno del servidor' });
};

// Valida un texto obligatorio con longitud mínima y máxima
const validarTexto = (valor, campo, etiqueta, min, max, errores) => {
  const texto = typeof valor === 'string' ? valor.trim() : '';
  if (!texto) {
    errores.push({ campo, mensaje: `${etiqueta} es obligatorio` });
  } else if (texto.length < min || texto.length > max) {
    errores.push({ campo, mensaje: `${etiqueta} debe tener entre ${min} y ${max} caracteres` });
  }
  return texto;
};

// Valida y limpia los datos de una incidencia según docs/api.md
const validarDatosIncidencia = (body) => {
  const errores = [];
  const { titulo, descripcion, id_categoria, ubicacion_texto, latitud, longitud } = body ?? {};

  const tituloLimpio = validarTexto(titulo, 'titulo', 'El título', 5, 150, errores);
  const descripcionLimpia = validarTexto(descripcion, 'descripcion', 'La descripción', 10, 2000, errores);

  if (!Number.isInteger(id_categoria) || id_categoria < 1) {
    errores.push({ campo: 'id_categoria', mensaje: 'Selecciona una categoría válida' });
  }

  // Ubicación en texto (opcional, pero se exige alguna forma de ubicación)
  let textoUbicacion = '';
  if (ubicacion_texto !== undefined && ubicacion_texto !== null) {
    if (typeof ubicacion_texto !== 'string') {
      errores.push({ campo: 'ubicacion_texto', mensaje: 'La ubicación debe ser texto' });
    } else {
      textoUbicacion = ubicacion_texto.trim();
      if (textoUbicacion && (textoUbicacion.length < 3 || textoUbicacion.length > 200)) {
        errores.push({
          campo: 'ubicacion_texto',
          mensaje: 'La ubicación debe tener entre 3 y 200 caracteres',
        });
      }
    }
  }

  // Coordenadas: siempre juntas
  const hayLatitud = latitud !== undefined && latitud !== null;
  const hayLongitud = longitud !== undefined && longitud !== null;
  let hayCoordenadas = false;

  if (hayLatitud !== hayLongitud) {
    errores.push({
      campo: hayLatitud ? 'longitud' : 'latitud',
      mensaje: 'La latitud y la longitud se envían juntas',
    });
  } else if (hayLatitud && hayLongitud) {
    const coordenadaValida = (valor, min, max) =>
      typeof valor === 'number' &&
      Number.isFinite(valor) &&
      valor >= min &&
      valor <= max &&
      Number(valor.toFixed(6)) === valor;

    if (!coordenadaValida(latitud, -90, 90)) {
      errores.push({
        campo: 'latitud',
        mensaje: 'La latitud debe ser un número entre -90 y 90, con hasta 6 decimales',
      });
    }
    if (!coordenadaValida(longitud, -180, 180)) {
      errores.push({
        campo: 'longitud',
        mensaje: 'La longitud debe ser un número entre -180 y 180, con hasta 6 decimales',
      });
    }
    hayCoordenadas = true;
  }

  if (!textoUbicacion && !hayCoordenadas) {
    errores.push({
      campo: 'ubicacion_texto',
      mensaje: 'Indica la ubicación: texto, o latitud y longitud',
    });
  }

  return {
    errores,
    datos: {
      titulo: tituloLimpio,
      descripcion: descripcionLimpia,
      id_categoria,
      ubicacion_texto: textoUbicacion || null,
      latitud: hayCoordenadas ? latitud : null,
      longitud: hayCoordenadas ? longitud : null,
    },
  };
};

// POST /api/incidencias
const crear = async (req, res) => {
  const { errores, datos } = validarDatosIncidencia(req.body);
  if (errores.length > 0) {
    return respuestaInvalida(res, errores);
  }

  try {
    const categoria = await categoriaModel.buscarActivaPorId(datos.id_categoria);
    if (!categoria) {
      return respuestaInvalida(res, [
        { campo: 'id_categoria', mensaje: 'La categoría no existe o está inactiva' },
      ]);
    }

    const idIncidencia = await incidenciaModel.crear({
      ...datos,
      id_usuario: req.usuario.id_usuario,
    });
    const incidencia = await incidenciaModel.buscarPorId(idIncidencia);

    return res.status(201).json(incidencia);
  } catch (error) {
    return errorInterno(res, error);
  }
};

// GET /api/incidencias?estado=&categoria=&q=
const listar = async (req, res) => {
  const { estado, categoria, q } = req.query;
  const errores = [];

  if (estado !== undefined && !ESTADOS.includes(estado)) {
    errores.push({
      campo: 'estado',
      mensaje: `Estado no válido. Valores permitidos: ${ESTADOS.join(', ')}`,
    });
  }

  let idCategoria;
  if (categoria !== undefined) {
    idCategoria = Number(categoria);
    if (!Number.isInteger(idCategoria) || idCategoria < 1) {
      errores.push({ campo: 'categoria', mensaje: 'La categoría debe ser un id válido' });
    }
  }

  let texto;
  if (q !== undefined) {
    if (typeof q !== 'string' || q.trim().length > 100) {
      errores.push({ campo: 'q', mensaje: 'La búsqueda debe ser texto de hasta 100 caracteres' });
    } else {
      texto = q.trim();
    }
  }

  if (errores.length > 0) {
    return respuestaInvalida(res, errores);
  }

  try {
    const incidencias = await incidenciaModel.listar({
      // El usuario solo ve las suyas; el operador ve todas
      idUsuario: req.usuario.rol === 'usuario' ? req.usuario.id_usuario : null,
      estado,
      idCategoria,
      q: texto,
    });
    return res.json(incidencias);
  } catch (error) {
    return errorInterno(res, error);
  }
};

// ---------- Ayudas para las rutas con :id ----------

const sinPermiso = (res) =>
  res.status(403).json({ ok: false, mensaje: 'No tienes permiso para realizar esta acción' });

const noEncontrada = (res) =>
  res.status(404).json({ ok: false, mensaje: 'Incidencia no encontrada' });

// Devuelve el id como número, o null si no es válido (ya responde el 400)
const obtenerIdValido = (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id) || id < 1) {
    respuestaInvalida(res, [{ campo: 'id', mensaje: 'El id de la incidencia no es válido' }]);
    return null;
  }
  return id;
};

const esCreador = (incidencia, req) =>
  incidencia.reportado_por.id_usuario === req.usuario.id_usuario;

// GET /api/incidencias/resumen
const resumen = async (req, res) => {
  try {
    const conteo = await incidenciaModel.resumen({
      idUsuario: req.usuario.rol === 'usuario' ? req.usuario.id_usuario : null,
    });
    return res.json(conteo);
  } catch (error) {
    return errorInterno(res, error);
  }
};

// GET /api/incidencias/:id
const detalle = async (req, res) => {
  const id = obtenerIdValido(req, res);
  if (id === null) return;

  try {
    const incidencia = await incidenciaModel.buscarPorId(id);
    if (!incidencia) return noEncontrada(res);

    // El usuario solo puede ver las suyas; el operador ve todas
    if (req.usuario.rol === 'usuario' && !esCreador(incidencia, req)) {
      return sinPermiso(res);
    }
    return res.json(incidencia);
  } catch (error) {
    return errorInterno(res, error);
  }
};

// PUT /api/incidencias/:id (solo el creador y solo si está pendiente)
const editar = async (req, res) => {
  const id = obtenerIdValido(req, res);
  if (id === null) return;

  try {
    const incidencia = await incidenciaModel.buscarPorId(id);
    if (!incidencia) return noEncontrada(res);
    if (!esCreador(incidencia, req)) return sinPermiso(res);

    if (incidencia.estado !== 'pendiente') {
      return res
        .status(400)
        .json({ ok: false, mensaje: 'Solo se puede editar una incidencia pendiente' });
    }

    const { errores, datos } = validarDatosIncidencia(req.body);
    if (errores.length > 0) {
      return respuestaInvalida(res, errores);
    }

    const categoria = await categoriaModel.buscarActivaPorId(datos.id_categoria);
    if (!categoria) {
      return respuestaInvalida(res, [
        { campo: 'id_categoria', mensaje: 'La categoría no existe o está inactiva' },
      ]);
    }

    const resultado = await incidenciaModel.actualizar(id, req.usuario.id_usuario, datos);
    if (!resultado.ok) {
      return res
        .status(400)
        .json({ ok: false, mensaje: 'Solo se puede editar una incidencia pendiente' });
    }

    const actualizada = await incidenciaModel.buscarPorId(id);
    return res.json(actualizada);
  } catch (error) {
    return errorInterno(res, error);
  }
};

// DELETE /api/incidencias/:id (cancela una incidencia pendiente)
const cancelar = async (req, res) => {
  const id = obtenerIdValido(req, res);
  if (id === null) return;

  try {
    const incidencia = await incidenciaModel.buscarPorId(id);
    if (!incidencia) return noEncontrada(res);

    // El usuario solo cancela las suyas; el operador puede cancelar cualquiera
    if (req.usuario.rol === 'usuario' && !esCreador(incidencia, req)) {
      return sinPermiso(res);
    }

    const resultado =
      incidencia.estado === 'pendiente'
        ? await incidenciaModel.cancelar(id, req.usuario.id_usuario)
        : { ok: false };

    if (!resultado.ok) {
      return res
        .status(400)
        .json({ ok: false, mensaje: 'Solo se puede cancelar una incidencia pendiente' });
    }

    return res.json({ ok: true, mensaje: 'Incidencia cancelada', estado: 'cancelada' });
  } catch (error) {
    return errorInterno(res, error);
  }
};

// Estados a los que el operador puede mover una incidencia con PATCH
const ESTADOS_NUEVOS = ['asignada', 'en_proceso', 'finalizada', 'cancelada'];

// PATCH /api/incidencias/:id/estado (solo operador)
const cambiarEstado = async (req, res) => {
  const id = obtenerIdValido(req, res);
  if (id === null) return;

  const { estado, solucion_descripcion, comentario } = req.body ?? {};
  const errores = [];

  if (!ESTADOS_NUEVOS.includes(estado)) {
    errores.push({
      campo: 'estado',
      mensaje: `Estado no válido. Valores permitidos: ${ESTADOS_NUEVOS.join(', ')}`,
    });
  }

  // Regla del sistema: para finalizar es obligatoria la solución aplicada
  let solucion = null;
  if (estado === 'finalizada') {
    if (typeof solucion_descripcion === 'string') {
      solucion = solucion_descripcion.trim();
    }
    if (!solucion) {
      errores.push({
        campo: 'solucion_descripcion',
        mensaje: 'La solución aplicada es obligatoria para finalizar',
      });
    } else if (solucion.length < 10 || solucion.length > 2000) {
      errores.push({
        campo: 'solucion_descripcion',
        mensaje: 'La solución debe tener entre 10 y 2000 caracteres',
      });
    }
  }

  // Comentario opcional para el historial
  let textoComentario = null;
  if (comentario !== undefined && comentario !== null) {
    if (typeof comentario !== 'string') {
      errores.push({ campo: 'comentario', mensaje: 'El comentario debe ser texto' });
    } else if (comentario.trim().length > 500) {
      errores.push({ campo: 'comentario', mensaje: 'El comentario debe tener máximo 500 caracteres' });
    } else if (comentario.trim()) {
      textoComentario = comentario.trim();
    }
  }

  if (errores.length > 0) {
    return respuestaInvalida(res, errores);
  }

  try {
    const cambio = await incidenciaModel.cambiarEstado(id, req.usuario.id_usuario, {
      estado,
      solucion_descripcion: solucion,
      comentario: textoComentario,
    });

    if (cambio.resultado === 'no_encontrada') {
      return noEncontrada(res);
    }
    if (cambio.resultado === 'no_permitida') {
      return res.status(400).json({
        ok: false,
        mensaje: `Transición no permitida: de '${cambio.estadoAnterior}' a '${estado}'`,
      });
    }

    const incidencia = await incidenciaModel.buscarPorId(id);
    return res.json(incidencia);
  } catch (error) {
    return errorInterno(res, error);
  }
};

module.exports = { crear, listar, resumen, detalle, editar, cancelar, cambiarEstado };
