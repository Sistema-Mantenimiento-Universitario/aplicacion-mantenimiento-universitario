const { ESTADOS, validarTexto, parsearId } = require('./comun');

// Estados a los que el operador puede mover una incidencia con PATCH
const ESTADOS_NUEVOS = ['asignada', 'en_proceso', 'finalizada', 'cancelada'];

// Valida y limpia los datos de una incidencia (crear y editar) según docs/api.md
const validarDatosIncidencia = (body) => {
  const errores = [];
  const { titulo, descripcion, id_categoria, ubicacion_texto, latitud, longitud } = body ?? {};

  const tituloLimpio = validarTexto(titulo, 'titulo', 'El título', 5, 150, errores);
  const descripcionLimpia = validarTexto(descripcion, 'descripcion', 'La descripción', 10, 2000, errores);

  if (!Number.isInteger(id_categoria) || id_categoria < 1) {
    errores.push({ campo: 'id_categoria', mensaje: 'Selecciona una categoría válida' });
  }

  // Ubicación en texto (opcional, pero se exige alguna forma de ubicación)
  let textoUbicacion = '';
  if (ubicacion_texto !== undefined && ubicacion_texto !== null) {
    if (typeof ubicacion_texto !== 'string') {
      errores.push({ campo: 'ubicacion_texto', mensaje: 'La ubicación debe ser texto' });
    } else {
      textoUbicacion = ubicacion_texto.trim();
      if (textoUbicacion && (textoUbicacion.length < 3 || textoUbicacion.length > 200)) {
        errores.push({
          campo: 'ubicacion_texto',
          mensaje: 'La ubicación debe tener entre 3 y 200 caracteres',
        });
      }
    }
  }

  // Coordenadas: siempre juntas
  const hayLatitud = latitud !== undefined && latitud !== null;
  const hayLongitud = longitud !== undefined && longitud !== null;
  let hayCoordenadas = false;

  if (hayLatitud !== hayLongitud) {
    errores.push({
      campo: hayLatitud ? 'longitud' : 'latitud',
      mensaje: 'La latitud y la longitud se envían juntas',
    });
  } else if (hayLatitud && hayLongitud) {
    const coordenadaValida = (valor, min, max) =>
      typeof valor === 'number' &&
      Number.isFinite(valor) &&
      valor >= min &&
      valor <= max &&
      Number(valor.toFixed(6)) === valor;

    if (!coordenadaValida(latitud, -90, 90)) {
      errores.push({
        campo: 'latitud',
        mensaje: 'La latitud debe ser un número entre -90 y 90, con hasta 6 decimales',
      });
    }
    if (!coordenadaValida(longitud, -180, 180)) {
      errores.push({
        campo: 'longitud',
        mensaje: 'La longitud debe ser un número entre -180 y 180, con hasta 6 decimales',
      });
    }
    hayCoordenadas = true;
  }

  if (!textoUbicacion && !hayCoordenadas) {
    errores.push({
      campo: 'ubicacion_texto',
      mensaje: 'Indica la ubicación: texto, o latitud y longitud',
    });
  }

  return {
    errores,
    datos: {
      titulo: tituloLimpio,
      descripcion: descripcionLimpia,
      id_categoria,
      ubicacion_texto: textoUbicacion || null,
      latitud: hayCoordenadas ? latitud : null,
      longitud: hayCoordenadas ? longitud : null,
    },
  };
};

// Valida los parámetros del listado: ?estado=&categoria=&q=
const validarFiltros = (query) => {
  const errores = [];
  const { estado, categoria, q } = query ?? {};

  if (estado !== undefined && !ESTADOS.includes(estado)) {
    errores.push({
      campo: 'estado',
      mensaje: `Estado no válido. Valores permitidos: ${ESTADOS.join(', ')}`,
    });
  }

  let idCategoria;
  if (categoria !== undefined) {
    idCategoria = parsearId(categoria);
    if (idCategoria === null) {
      errores.push({ campo: 'categoria', mensaje: 'La categoría debe ser un id válido' });
    }
  }

  let texto;
  if (q !== undefined) {
    if (typeof q !== 'string' || q.trim().length > 100) {
      errores.push({ campo: 'q', mensaje: 'La búsqueda debe ser texto de hasta 100 caracteres' });
    } else {
      texto = q.trim();
    }
  }

  return { errores, filtros: { estado, idCategoria: idCategoria ?? undefined, q: texto } };
};

// Valida el cambio de estado (PATCH /:id/estado)
const validarCambioEstado = (body) => {
  const errores = [];
  const { estado, solucion_descripcion, comentario } = body ?? {};

  if (!ESTADOS_NUEVOS.includes(estado)) {
    errores.push({
      campo: 'estado',
      mensaje: `Estado no válido. Valores permitidos: ${ESTADOS_NUEVOS.join(', ')}`,
    });
  }

  // Regla del sistema: para finalizar es obligatoria la solución aplicada
  let solucion = null;
  if (estado === 'finalizada') {
    if (typeof solucion_descripcion === 'string') {
      solucion = solucion_descripcion.trim();
    }
    if (!solucion) {
      errores.push({
        campo: 'solucion_descripcion',
        mensaje: 'La solución aplicada es obligatoria para finalizar',
      });
    } else if (solucion.length < 10 || solucion.length > 2000) {
      errores.push({
        campo: 'solucion_descripcion',
        mensaje: 'La solución debe tener entre 10 y 2000 caracteres',
      });
    }
  }

  // Comentario opcional para el historial
  let textoComentario = null;
  if (comentario !== undefined && comentario !== null) {
    if (typeof comentario !== 'string') {
      errores.push({ campo: 'comentario', mensaje: 'El comentario debe ser texto' });
    } else if (comentario.trim().length > 500) {
      errores.push({ campo: 'comentario', mensaje: 'El comentario debe tener máximo 500 caracteres' });
    } else if (comentario.trim()) {
      textoComentario = comentario.trim();
    }
  }

  return {
    errores,
    datos: { estado, solucion_descripcion: solucion, comentario: textoComentario },
  };
};

module.exports = { validarDatosIncidencia, validarFiltros, validarCambioEstado };
