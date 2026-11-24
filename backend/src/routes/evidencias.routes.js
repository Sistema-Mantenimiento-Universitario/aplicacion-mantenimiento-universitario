const { Router } = require('express');
const { cargarIncidencia, listar } = require('../controllers/evidencias.controller');
const { verificarToken } = require('../middlewares/auth.middleware');

// mergeParams: para leer el :id de /api/incidencias/:id/evidencias
const router = Router({ mergeParams: true });

router.use(verificarToken, cargarIncidencia);

router.get('/', listar);

module.exports = router;
