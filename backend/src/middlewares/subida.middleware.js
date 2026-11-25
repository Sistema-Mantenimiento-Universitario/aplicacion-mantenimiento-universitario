const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const multer = require('multer');

// backend/uploads/evidencias (la carpeta que server.js sirve en /uploads)
const CARPETA = path.join(__dirname, '..', '..', 'uploads', 'evidencias');
fs.mkdirSync(CARPETA, { recursive: true });

// Tipos permitidos y la extensión con la que se guardan
const EXTENSIONES = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
};

const MAX_ARCHIVOS = 5;

const upload = multer({
  storage: multer.diskStorage({
    destination: CARPETA,
    // Nombre aleatorio para que la URL pública no se pueda adivinar
    filename: (req, file, cb) => cb(null, crypto.randomUUID() + EXTENSIONES[file.mimetype]),
  }),
  limits: { fileSize: 5 * 1024 * 1024, files: MAX_ARCHIVOS },
  fileFilter: (req, file, cb) => {
    if (EXTENSIONES[file.mimetype]) return cb(null, true);
    const error = new Error('Tipo no permitido');
    error.code = 'TIPO_NO_PERMITIDO';
    return cb(error);
  },
}).array('imagenes', MAX_ARCHIVOS);

const MENSAJES = {
  LIMIT_FILE_SIZE: 'Cada imagen debe pesar máximo 5 MB',
  LIMIT_FILE_COUNT: `Se permiten máximo ${MAX_ARCHIVOS} imágenes`,
  LIMIT_UNEXPECTED_FILE: `Se permiten máximo ${MAX_ARCHIVOS} imágenes, en el campo imagenes`,
  TIPO_NO_PERMITIDO: 'Solo se permiten imágenes JPG, PNG o WEBP',
};

// Envuelve a multer para responder sus errores con el formato del contrato.
// Si falla, multer ya borra los archivos que alcanzó a guardar.
const subirImagenes = (req, res, next) => {
  upload(req, res, (error) => {
    if (!error) return next();

    const mensaje = MENSAJES[error.code];
    if (mensaje) {
      return res.status(400).json({
        ok: false,
        mensaje: 'Datos inválidos',
        errores: [{ campo: 'imagenes', mensaje }],
      });
    }

    console.error(error);
    return res.status(500).json({ ok: false, mensaje: 'Error interno del servidor' });
  });
};

// Para cuando algo falla después de multer (validación o BD)
const borrarArchivos = async (archivos = []) => {
  await Promise.all(archivos.map((archivo) => fs.promises.rm(archivo.path, { force: true })));
};

module.exports = { subirImagenes, borrarArchivos, CARPETA };
