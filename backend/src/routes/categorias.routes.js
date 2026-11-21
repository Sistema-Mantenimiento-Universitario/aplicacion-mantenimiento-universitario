const { Router } = require('express');
const { listar, crear, editar } = require('../controllers/categorias.controller');
const { verificarToken, verificarRol } = require('../middlewares/auth.middleware');

const router = Router();

router.use(verificarToken);

router.get('/', listar);
router.post('/', verificarRol('operador'), crear);
router.put('/:id', verificarRol('operador'), editar);

module.exports = router;
