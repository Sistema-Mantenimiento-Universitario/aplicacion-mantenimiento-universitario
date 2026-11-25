// Estados a los que se puede pasar desde cada estado
const TRANSICIONES = {
  pendiente: ["asignada", "cancelada"],
  asignada: ["en_proceso"],
  en_proceso: ["finalizada"],
  finalizada: [],
  cancelada: [],
};

// Devuelve true si se puede pasar de estadoActual a estadoNuevo
const transicionPermitida = (estadoActual, estadoNuevo) => {
  const permitidos = TRANSICIONES[estadoActual];
  if (!permitidos) {
    return false;
  }
  return permitidos.includes(estadoNuevo);
};

module.exports = { TRANSICIONES, transicionPermitida };
