const jwt = require("jsonwebtoken");

const verificarToken = (req, res, next) => {
  const encabezado = req.headers.authorization;

  if (!encabezado || !encabezado.startsWith("Bearer ")) {
    return res.status(401).json({
      ok: false,
      mensaje: "Falta el token de autenticación",
    });
  }

  const token = encabezado.split(" ")[1];

  let datos;
  try {
    datos = jwt.verify(token, process.env.JWT_SECRET);
  } catch (error) {
    const mensaje =
      error.name === "TokenExpiredError"
        ? "Sesión expirada. Inicia sesión de nuevo"
        : "Token inválido";

    return res.status(401).json({ ok: false, mensaje });
  }

  req.usuario = { id_usuario: datos.id_usuario, rol: datos.rol };
  next();
};

const verificarRol = (...rolesPermitidos) => {
    return (req, res, next) => {
        if (!req.usuario) {
            return res.status(401).json({
                ok: false,
                mensaje: "No autenticado",
            });
        }

        if (!rolesPermitidos.includes(req.usuario.rol)) {
            return res.status(403).json({
                ok: false,
                mensaje: "No tienes permiso para realizar esta acción",
            });
        }

        next();
    };
};

module.exports = { verificarToken, verificarRol };
