// TEMPORAL: lista en memoria mientras no exista la conexión a MySQL (B2).
// Contraseñas: usuario@uaa.mx -> Usuario123, operador@uaa.mx -> Operador123
const usuarios = [
  {
    id_usuario: 1,
    nombre: "Usuario Prueba",
    correo: "usuario@uaa.mx",
    password_hash: "$2b$10$stGmL2RuNgwv.XCuwwC.K.8asq34FwTyHnQoifdBwxWhohw3WsGK6",
    rol: "usuario",
    activo: 1,
  },
  {
    id_usuario: 2,
    nombre: "Operador Prueba",
    correo: "operador@uaa.mx",
    password_hash: "$2b$10$6UBbpkFWkMF/3XjBXCZ99OgIZgqqkjHg3eXBGS.G/6Re2o1LiHDxm",
    rol: "operador",
    activo: 1,
  },
];

const buscarPorCorreo = async (correo) => {
  return usuarios.find((u) => u.correo === correo) ?? null;
};

module.exports = { buscarPorCorreo };
