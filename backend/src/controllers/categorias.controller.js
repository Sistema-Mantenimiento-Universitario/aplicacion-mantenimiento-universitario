const categoriaModel = require('../models/categoria.model');
const { parsearId } = require('../validaciones/comun');
const { validarDatosCategoria } = require('../validaciones/categoria.validacion');

const respuestaInvalida = (res, errores) =>
  res.status(400).json({ ok: false, mensaje: 'Datos inválidos', errores });

const nombreDuplicado = (res) =>
  respuestaInvalida(res, [{ campo: 'nombre', mensaje: 'Ya existe una categoría con ese nombre' }]);

// GET /api/categorias
const listar = async (req, res) => {
  const categorias = await categoriaModel.listar({
    // El usuario solo ve las activas; el operador ve todas
    soloActivas: req.usuario.rol === 'usuario',
  });
  return res.json(categorias);
};

// POST /api/categorias (operador)
const crear = async (req, res) => {
  const { errores, datos } = validarDatosCategoria(req.body);
  if (errores.length > 0) {
    return respuestaInvalida(res, errores);
  }

  try {
    const idCategoria = await categoriaModel.crear(datos);
    const categoria = await categoriaModel.buscarPorId(idCategoria);
    return res.status(201).json(categoria);
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') {
      return nombreDuplicado(res);
    }
    throw error; // lo atiende el manejador global
  }
};

// PUT /api/categorias/:id (operador)
const editar = async (req, res) => {
  const id = parsearId(req.params.id);
  if (id === null) {
    return respuestaInvalida(res, [{ campo: 'id', mensaje: 'El id de la categoría no es válido' }]);
  }

  const actual = await categoriaModel.buscarPorId(id);
  if (!actual) {
    return res.status(404).json({ ok: false, mensaje: 'Categoría no encontrada' });
  }

  const { errores, datos } = validarDatosCategoria(req.body);
  if (errores.length > 0) {
    return respuestaInvalida(res, errores);
  }

  try {
    await categoriaModel.actualizar(id, {
      nombre: datos.nombre,
      descripcion: datos.descripcion,
      // Si no se envía "activa", se conserva el valor actual
      activa: datos.activa === undefined ? actual.activa : datos.activa,
    });
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') {
      return nombreDuplicado(res);
    }
    throw error; // lo atiende el manejador global
  }

  const categoria = await categoriaModel.buscarPorId(id);
  return res.json(categoria);
};

module.exports = { listar, crear, editar };