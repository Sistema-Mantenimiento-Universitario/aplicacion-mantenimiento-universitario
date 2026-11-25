const incidenciaModel = require('../models/incidencia.model');
const categoriaModel = require('../models/categoria.model');
const historialModel = require('../models/historial.model');
const { parsearId } = require('../validaciones/comun');
const {
  validarDatosIncidencia,
  validarFiltros,
  validarCambioEstado,
} = require('../validaciones/incidencia.validacion');

const respuestaInvalida = (res, errores) =>
  res.status(400).json({ ok: false, mensaje: 'Datos inválidos', errores });

const sinPermiso = (res) =>
  res.status(403).json({ ok: false, mensaje: 'No tienes permiso para realizar esta acción' });

const noEncontrada = (res) =>
  res.status(404).json({ ok: false, mensaje: 'Incidencia no encontrada' });

// Devuelve el id como número, o null si no es válido (ya responde el 400)
const obtenerIdValido = (req, res) => {
  const id = parsearId(req.params.id);
  if (id === null) {
    respuestaInvalida(res, [{ campo: 'id', mensaje: 'El id de la incidencia no es válido' }]);
  }
  return id;
};

const esCreador = (incidencia, req) =>
  incidencia.reportado_por.id_usuario === req.usuario.id_usuario;

// POST /api/incidencias
const crear = async (req, res) => {
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

  const idIncidencia = await incidenciaModel.crear({
    ...datos,
    id_usuario: req.usuario.id_usuario,
  });
  const incidencia = await incidenciaModel.buscarPorId(idIncidencia);

  return res.status(201).json(incidencia);
};

// GET /api/incidencias?estado=&categoria=&q=
const listar = async (req, res) => {
  const { errores, filtros } = validarFiltros(req.query);
  if (errores.length > 0) {
    return respuestaInvalida(res, errores);
  }

  const incidencias = await incidenciaModel.listar({
    // El usuario solo ve las suyas; el operador ve todas
    idUsuario: req.usuario.rol === 'usuario' ? req.usuario.id_usuario : null,
    ...filtros,
  });
  return res.json(incidencias);
};

// GET /api/incidencias/resumen
const resumen = async (req, res) => {
  const conteo = await incidenciaModel.resumen({
    idUsuario: req.usuario.rol === 'usuario' ? req.usuario.id_usuario : null,
  });
  return res.json(conteo);
};

// GET /api/incidencias/:id
const detalle = async (req, res) => {
  const id = obtenerIdValido(req, res);
  if (id === null) return;

  const incidencia = await incidenciaModel.buscarPorId(id);
  if (!incidencia) return noEncontrada(res);

  // El usuario solo puede ver las suyas; el operador ve todas
  if (req.usuario.rol === 'usuario' && !esCreador(incidencia, req)) {
    return sinPermiso(res);
  }
  return res.json(incidencia);
};

// PUT /api/incidencias/:id (solo el creador y solo si está pendiente)
const editar = async (req, res) => {
  const id = obtenerIdValido(req, res);
  if (id === null) return;

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
};

// DELETE /api/incidencias/:id (cancela una incidencia pendiente)
const cancelar = async (req, res) => {
  const id = obtenerIdValido(req, res);
  if (id === null) return;

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
};

// PATCH /api/incidencias/:id/estado (solo operador)
const cambiarEstado = async (req, res) => {
  const id = obtenerIdValido(req, res);
  if (id === null) return;

  const { errores, datos } = validarCambioEstado(req.body);
  if (errores.length > 0) {
    return respuestaInvalida(res, errores);
  }

  const cambio = await incidenciaModel.cambiarEstado(id, req.usuario.id_usuario, datos);

  if (cambio.resultado === 'no_encontrada') {
    return noEncontrada(res);
  }
  if (cambio.resultado === 'no_permitida') {
    return res.status(400).json({
      ok: false,
      mensaje: `Transición no permitida: de '${cambio.estadoAnterior}' a '${datos.estado}'`,
    });
  }

  const incidencia = await incidenciaModel.buscarPorId(id);
  return res.json(incidencia);
};

// GET /api/incidencias/:id/historial
const historial = async (req, res) => {
  const id = obtenerIdValido(req, res);
  if (id === null) return;

  const incidencia = await incidenciaModel.buscarPorId(id);
  if (!incidencia) return noEncontrada(res);

  // El usuario solo ve el historial de sus propias incidencias
  if (req.usuario.rol === 'usuario' && !esCreador(incidencia, req)) {
    return sinPermiso(res);
  }

  const cambios = await historialModel.listarPorIncidencia(id);
  return res.json(cambios);
};

module.exports = {
  crear,
  listar,
  resumen,
  detalle,
  editar,
  cancelar,
  cambiarEstado,
  historial,
};