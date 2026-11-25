const FORMATO_CORREO = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// Valida los datos del login según docs/api.md
const validarLogin = (body) => {
  const errores = [];
  const { correo, password } = body ?? {};

  const correoLimpio = typeof correo === 'string' ? correo.trim() : '';
  if (!correoLimpio) {
    errores.push({ campo: 'correo', mensaje: 'El correo es obligatorio' });
  } else if (correoLimpio.length > 150 || !FORMATO_CORREO.test(correoLimpio)) {
    errores.push({ campo: 'correo', mensaje: 'El correo no tiene un formato válido' });
  }

  if (typeof password !== 'string' || !password) {
    errores.push({ campo: 'password', mensaje: 'La contraseña es obligatoria' });
  }

  return { errores, datos: { correo: correoLimpio, password } };
};

module.exports = { validarLogin };
