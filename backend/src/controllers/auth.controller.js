const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const { buscarPorCorreo, buscarPorId } = require("../models/usuario.model");

const login = async (req, res) => {
  const { correo, password } = req.body ?? {};

  // validamos
  const errores = [];
  if (typeof correo !== "string" || !correo.trim()) {
    errores.push({ campo: "correo", mensaje: "El correo es obligatorio" });
  }
  if (typeof password !== "string" || !password) {
    errores.push({ campo: "password", mensaje: "La contraseña es obligatoria" });
  }
  if (errores.length > 0) {
    return res.status(400).json({ ok: false, mensaje: "Datos inválidos", errores });
  }

  try {
    // buscamos al usuario y comparamos la contraseña
    const usuario = await buscarPorCorreo(correo.trim());
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
  } catch (error) {
    console.error(error);
    return res.status(500).json({ ok: false, mensaje: "Error interno del servidor" });
  }
};

const perfil = async (req, res) => {
  try {
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
  } catch (error) {
    console.error(error);
    return res.status(500).json({ ok: false, mensaje: "Error interno del servidor" });
  }
};

module.exports = { login, perfil };
