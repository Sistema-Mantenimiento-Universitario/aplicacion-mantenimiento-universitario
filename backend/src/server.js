require('dotenv').config({ quiet: true });

const express = require('express');
const cors = require('cors');
const pruebaRoutes = require('./routes/prueba.routes');
const authRoutes = require('./routes/auth.routes');
const { probarConexion } = require('./config/db');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

app.use('/api/prueba', pruebaRoutes);
app.use('/api/auth', authRoutes);

app.listen(PORT, async () => {
  console.log(`Servidor corriendo en http://localhost:${PORT}`);
  await probarConexion();
});