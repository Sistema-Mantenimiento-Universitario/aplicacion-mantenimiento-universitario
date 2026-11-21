const categoriaModel = require('../models/categoria.model');

const respuestaInvalida = (res, errores) =>
  res.status(400).json({ ok: false, mensaje: 'Datos inválidos', errores });

const errorInterno = (res, error) => {
  console.error(error);
  return res.status(500).json({ ok: false, mensaje: 'Error interno del servidor' });
};

const nombreDuplicado = (res) =>
  respuestaInvalida(res, [{ campo: 'nombre', mensaje: 'Ya existe una categoría con ese nombre' }]);

const validarDatosCategoria = (body) => {
  const errores = [];
  const { nombre, descripcion, activa } = body ?? {};

  const nombreLimpio = typeof nombre === 'string' ? nombre.trim() : '';
  if (!nombreLimpio) {
    errores.push({ campo: 'nombre', mensaje: 'El nombre es obligatorio' });
  } else if (nombreLimpio.length < 3 || nombreLimpio.length > 80) {
    errores.push({ campo: 'nombre', mensaje: 'El nombre debe tener entre 3 y 80 caracteres' });
  }

  let descripcionLimpia = null;
  if (descripcion !== undefined && descripcion !== null) {
    if (typeof descripcion !== 'string') {
      errores.push({ campo: 'descripcion', mensaje: 'La descripción debe ser texto' });
    } else {
      descripcionLimpia = descripcion.trim() || null;
      if (descripcionLimpia && descripcionLimpia.length > 255) {
        errores.push({
          campo: 'descripcion',
          mensaje: 'La descripción puede tener hasta 255 caracteres',
        });
      }
    }
  }

  if (activa !== undefined && typeof activa !== 'boolean') {
    errores.push({ campo: 'activa', mensaje: 'El campo activa debe ser verdadero o falso' });
  }

  return {
    errores,
    datos: { nombre: nombreLimpio, descripcion: descripcionLimpia, activa },
  };
};

const listar = async (req, res) => {
  try {
    const categorias = await categoriaModel.listar({
      soloActivas: req.usuario.rol === 'usuario',
    });
    return res.json(categorias);
  } catch (error) {
    return errorInterno(res, error);
  }
};

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
    return errorInterno(res, error);
  }
};

const editar = async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id) || id < 1) {
    return respuestaInvalida(res, [{ campo: 'id', mensaje: 'El id de la categoría no es válido' }]);
  }

  try {
    const actual = await categoriaModel.buscarPorId(id);
    if (!actual) {
      return res.status(404).json({ ok: false, mensaje: 'Categoría no encontrada' });
    }

    const { errores, datos } = validarDatosCategoria(req.body);
    if (errores.length > 0) {
      return respuestaInvalida(res, errores);
    }

    await categoriaModel.actualizar(id, {
      nombre: datos.nombre,
      descripcion: datos.descripcion,
      activa: datos.activa === undefined ? actual.activa : datos.activa,
    });

    const categoria = await categoriaModel.buscarPorId(id);
    return res.json(categoria);
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') {
      return nombreDuplicado(res);
    }
    return errorInterno(res, error);
  }
};

module.exports = { listar, crear, editar };
