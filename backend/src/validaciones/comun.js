// Estados posibles de una incidencia
const ESTADOS = ['pendiente', 'asignada', 'en_proceso', 'finalizada', 'cancelada'];

// Valida un texto obligatorio con longitud mínima y máxima.
// Agrega el error a la lista y devuelve el texto sin espacios sobrantes.
const validarTexto = (valor, campo, etiqueta, min, max, errores) => {
  const texto = typeof valor === 'string' ? valor.trim() : '';
  if (!texto) {
    errores.push({ campo, mensaje: `${etiqueta} es obligatorio` });
  } else if (texto.length < min || texto.length > max) {
    errores.push({ campo, mensaje: `${etiqueta} debe tener entre ${min} y ${max} caracteres` });
  }
  return texto;
};

// Convierte un id recibido en la URL a número entero positivo.
// Devuelve null si no es válido.
const parsearId = (valor) => {
  const id = Number(valor);
  return Number.isInteger(id) && id >= 1 ? id : null;
};

module.exports = { ESTADOS, validarTexto, parsearId };
