-- Datos de prueba. Ejecutar después de schema.sql.
-- Las contraseñas se guardan como hash bcrypt (10 rondas), nunca en texto plano:
--   usuario@uaa.mx  -> Usuario123
--   operador@uaa.mx -> Operador123

USE mantenimiento_universitario;

INSERT INTO usuarios (nombre, correo, password_hash, rol, activo) VALUES
    ('Usuario Prueba',  'usuario@uaa.mx',  '$2b$10$stGmL2RuNgwv.XCuwwC.K.8asq34FwTyHnQoifdBwxWhohw3WsGK6', 'usuario',  1),
    ('Operador Prueba', 'operador@uaa.mx', '$2b$10$6UBbpkFWkMF/3XjBXCZ99OgIZgqqkjHg3eXBGS.G/6Re2o1LiHDxm', 'operador', 1);
