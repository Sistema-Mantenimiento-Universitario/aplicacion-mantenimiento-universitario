const { Router } = require('express');
const { obtenerPrueba } = require('../controllers/prueba.controller');

const router = Router();

router.get('/', obtenerPrueba);

module.exports = router;
