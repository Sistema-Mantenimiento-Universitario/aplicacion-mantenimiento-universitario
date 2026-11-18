const { Router } = require('express');
const { obtenerPrueba, probarBD } = require('../controllers/prueba.controller');

const router = Router();

router.get('/', obtenerPrueba);
router.get('/db', probarBD);

module.exports = router;