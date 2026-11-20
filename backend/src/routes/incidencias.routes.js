const { Router } = require('express');
const {
  crear,
  listar,
  resumen,
  detalle,
  editar,
  cancelar,
} = require('../controllers/incidencias.controller');
const { verificarToken, verificarRol } = require('../middlewares/auth.middleware');

const router = Router();

// Todas las rutas de incidencias exigen sesión iniciada
router.use(verificarToken);

router.post('/', verificarRol('usuario', 'operador'), crear);
router.get('/', listar);

// IMPORTANTE: /resumen va antes que /:id, o "resumen" se tomaría como un id
router.get('/resumen', resumen);

router.get('/:id', detalle);
router.put('/:id', verificarRol('usuario'), editar);
router.delete('/:id', verificarRol('usuario', 'operador'), cancelar);

module.exports = router;
