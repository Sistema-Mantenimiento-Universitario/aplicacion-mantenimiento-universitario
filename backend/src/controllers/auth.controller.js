const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const { buscarPorCorreo, buscarPorId } = require("../models/usuario.model");
const { validarLogin } = require("../validaciones/auth.validacion");

const login = async (req, res) => {
  const { errores, datos } = validarLogin(req.body);
  if (errores.length > 0) {
    return res.status(400).json({ ok: false, mensaje: "Datos inválidos", errores });
  }
  const { correo, password } = datos;

  // buscamos al usuario y comparamos la contraseña
  const usuario = await buscarPorCorreo(correo);
  const contrasenaCorrecta =
    usuario && (await bcrypt.compare(password, usuario.password_hash));

  if (!contrasenaCorrecta) {
    return res.status(401).json({ ok: false, mensaje: "Correo o contraseña incorrectos" });
  }

  if (!usuario.activo) {
    return res.status(401).json({ ok: false, mensaje: "Tu cuenta está desactivada" });
  }

  const token = jwt.sign(
    { id_usuario: usuario.id_usuario, rol: usuario.rol },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || "24h" },
  );

  return res.json({
    token,
    usuario: {
      id_usuario: usuario.id_usuario,
      nombre: usuario.nombre,
      correo: usuario.correo,
      rol: usuario.rol,
    },
  });
};

const perfil = async (req, res) => {
  // el token puede seguir vigente aunque el usuario ya no exista o lo hayan desactivado
  const usuario = await buscarPorId(req.usuario.id_usuario);

  if (!usuario || !usuario.activo) {
    return res.status(401).json({ ok: false, mensaje: "Usuario no válido. Inicia sesión de nuevo" });
  }

  return res.json({
    id_usuario: usuario.id_usuario,
    nombre: usuario.nombre,
    correo: usuario.correo,
    rol: usuario.rol,
  });
};

module.exports = { login, perfil };