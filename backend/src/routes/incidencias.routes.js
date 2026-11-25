const { Router } = require('express');
const {
  crear,
  listar,
  resumen,
  detalle,
  editar,
  cancelar,
  cambiarEstado,
  historial,
} = require('../controllers/incidencias.controller');
const { verificarToken, verificarRol } = require('../middlewares/auth.middleware');

const router = Router();

router.use(verificarToken);

router.post('/', verificarRol('usuario', 'operador'), crear);
router.get('/', listar);

router.get('/resumen', resumen);

router.get('/:id', detalle);
router.get('/:id/historial', historial);
router.put('/:id', verificarRol('usuario'), editar);
router.delete('/:id', verificarRol('usuario', 'operador'), cancelar);
router.patch('/:id/estado', verificarRol('operador'), cambiarEstado);

module.exports = router;
