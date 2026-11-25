const incidenciaModel = require('../models/incidencia.model');
const evidenciaModel = require('../models/evidencia.model');
const { borrarArchivos } = require('../middlewares/subida.middleware');

const TIPOS = ['reporte', 'atencion'];

const respuestaInvalida = (res, errores) =>
  res.status(400).json({ ok: false, mensaje: 'Datos inválidos', errores });

const errorInterno = (res, error) => {
  console.error(error);
  return res.status(500).json({ ok: false, mensaje: 'Error interno del servidor' });
};

const sinPermiso = (res) =>
  res.status(403).json({ ok: false, mensaje: 'No tienes permiso para realizar esta acción' });

const noEncontrada = (res) =>
  res.status(404).json({ ok: false, mensaje: 'Incidencia no encontrada' });

// Middleware: valida el id, que la incidencia exista y que el usuario pueda verla.
// El usuario solo accede a sus propias incidencias; el operador a todas.
// Deja la incidencia en req.incidencia para lo que sigue.
const cargarIncidencia = async (req, res, next) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id) || id < 1) {
    return respuestaInvalida(res, [{ campo: 'id', mensaje: 'El id de la incidencia no es válido' }]);
  }

  try {
    const incidencia = await incidenciaModel.buscarPorId(id);
    if (!incidencia) return noEncontrada(res);

    if (
      req.usuario.rol === 'usuario' &&
      incidencia.reportado_por.id_usuario !== req.usuario.id_usuario
    ) {
      return sinPermiso(res);
    }

    req.incidencia = incidencia;
    return next();
  } catch (error) {
    return errorInterno(res, error);
  }
};

// GET /api/incidencias/:id/evidencias
const listar = async (req, res) => {
  try {
    const evidencias = await evidenciaModel.listarPorIncidencia(req.incidencia.id_incidencia);
    return res.json(evidencias);
  } catch (error) {
    return errorInterno(res, error);
  }
};

// POST /api/incidencias/:id/evidencias (multipart, campo imagenes)
// Llega después de multer: si algo falla aquí, se borran los archivos ya guardados
const subir = async (req, res) => {
  const archivos = req.files ?? [];
  const tipo = req.body?.tipo || 'reporte';

  const errores = [];
  if (archivos.length === 0) {
    errores.push({ campo: 'imagenes', mensaje: 'Selecciona al menos una imagen' });
  }
  if (!TIPOS.includes(tipo)) {
    errores.push({ campo: 'tipo', mensaje: 'El tipo debe ser reporte o atencion' });
  }
  if (errores.length > 0) {
    await borrarArchivos(archivos);
    return respuestaInvalida(res, errores);
  }

  // Solo el operador sube evidencias de la atención
  if (tipo === 'atencion' && req.usuario.rol !== 'operador') {
    await borrarArchivos(archivos);
    return sinPermiso(res);
  }

  try {
    const evidencias = await evidenciaModel.crear(
      req.incidencia.id_incidencia,
      req.usuario.id_usuario,
      tipo,
      archivos.map((archivo) => ({
        ruta_archivo: `evidencias/${archivo.filename}`,
        nombre_original: archivo.originalname,
        mime_type: archivo.mimetype,
      }))
    );
    return res.status(201).json(evidencias);
  } catch (error) {
    await borrarArchivos(archivos);
    return errorInterno(res, error);
  }
};

module.exports = { cargarIncidencia, listar, subir };
