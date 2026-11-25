require('dotenv').config({ quiet: true });

const path = require('path');
const express = require('express');
const cors = require('cors');
const pruebaRoutes = require('./routes/prueba.routes');
const authRoutes = require('./routes/auth.routes');
const { probarConexion } = require('./config/db');
const incidenciasRoutes = require('./routes/incidencias.routes');
const categoriasRoutes = require('./routes/categorias.routes');
const evidenciasRoutes = require('./routes/evidencias.routes');
const { rutaNoEncontrada, manejarErrores } = require('./middlewares/error.middleware');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Imágenes de evidencias, públicas (sin token) para que la app las muestre con Image.network
app.use('/uploads', express.static(path.join(__dirname, '..', 'uploads')));

app.use('/api/prueba', pruebaRoutes);
app.use('/api/auth', authRoutes);
// Va antes que /api/incidencias para que esas rutas no la intercepten
app.use('/api/incidencias/:id/evidencias', evidenciasRoutes);
app.use('/api/incidencias', incidenciasRoutes);
app.use('/api/categorias', categoriasRoutes);

app.use(rutaNoEncontrada);
app.use(manejarErrores);

app.listen(PORT, async () => {
  console.log(`Servidor corriendo en http://localhost:${PORT}`);
  await probarConexion();
});