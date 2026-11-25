const { Router } = require('express');
const { cargarIncidencia, listar, subir } = require('../controllers/evidencias.controller');
const { verificarToken } = require('../middlewares/auth.middleware');
const { subirImagenes } = require('../middlewares/subida.middleware');

// mergeParams: para leer el :id de /api/incidencias/:id/evidencias
const router = Router({ mergeParams: true });

router.use(verificarToken, cargarIncidencia);

router.get('/', listar);
// cargarIncidencia valida permisos antes de que multer guarde archivos
router.post('/', subirImagenes, subir);

module.exports = router;
