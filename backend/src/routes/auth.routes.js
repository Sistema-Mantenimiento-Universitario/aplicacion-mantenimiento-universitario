const { Router } = require("express");
const { login, perfil } = require("../controllers/auth.controller");
const { verificarToken } = require("../middlewares/auth.middleware");

const router = Router();

router.post("/login", login);
router.get("/perfil", verificarToken, perfil);

module.exports = router;
