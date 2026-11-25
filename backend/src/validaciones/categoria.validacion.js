const { validarTexto } = require('./comun');

// Valida y limpia los datos de una categoría según docs/api.md
const validarDatosCategoria = (body) => {
  const errores = [];
  const { nombre, descripcion, activa } = body ?? {};

  const nombreLimpio = validarTexto(nombre, 'nombre', 'El nombre', 3, 80, errores);

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

module.exports = { validarDatosCategoria };
