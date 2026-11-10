const obtenerPrueba = (req, res) => {
  res.json({
    mensaje: 'El backend está funcionando',
    fecha: new Date().toISOString(),
  });
};

module.exports = { obtenerPrueba };
