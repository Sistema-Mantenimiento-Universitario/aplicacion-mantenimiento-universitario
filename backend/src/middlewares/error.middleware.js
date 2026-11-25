const rutaNoEncontrada = (req, res) => {
  res.status(404).json({ ok: false, mensaje: 'Ruta no encontrada' });
};

const manejarErrores = (error, req, res, next) => {
  if (res.headersSent) {
    return next(error);
  }

  if (error.type === 'entity.parse.failed') {
    return res
      .status(400)
      .json({ ok: false, mensaje: 'El cuerpo de la petición no es un JSON válido' });
  }

  if (error.type === 'entity.too.large') {
    return res
      .status(400)
      .json({ ok: false, mensaje: 'El cuerpo de la petición es demasiado grande' });
  }

  if (Number.isInteger(error.status) && error.status >= 400 && error.status < 500) {
    return res.status(400).json({ ok: false, mensaje: 'Petición no válida' });
  }

  console.error(`Error en ${req.method} ${req.originalUrl}:`, error);
  return res.status(500).json({ ok: false, mensaje: 'Error interno del servidor' });
};

module.exports = { rutaNoEncontrada, manejarErrores };