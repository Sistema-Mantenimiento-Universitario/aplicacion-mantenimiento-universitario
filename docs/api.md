# Contrato de la API REST: Sistema de mantenimiento universitario

Este documento define los endpoints de la API para que frontend y backend trabajen con el mismo acuerdo. Los nombres de campos coinciden con `docs/modelo-datos.md`.

## Convenciones generales

| Concepto | Valor |
|---|---|
| URL base (desarrollo) | `http://localhost:3000/api` |
| Formato | JSON (`Content-Type: application/json`), salvo la subida de evidencias (`multipart/form-data`) |
| Autenticación | JWT en el encabezado `Authorization: Bearer <token>` |
| Fechas | ISO 8601 en UTC, por ejemplo `2026-11-11T15:30:00.000Z` |
| Nombres de campos | `snake_case`, igual que la base de datos |
| Roles | `usuario` y `operador` |
| Estados | `pendiente`, `asignada`, `en_proceso`, `finalizada`, `cancelada` |
| CORS | El backend habilita CORS (paquete `cors`) en las rutas `/api` y en `/uploads`, para que Flutter web pueda consumir la API y mostrar las imágenes |

Los permisos se comprueban siempre en el backend. Ocultar botones en Flutter no es suficiente.

Las rutas de este documento incluyen el prefijo `/api`. En los Issues del proyecto aparecen sin él (por ejemplo `POST /auth/login`), pero en el servidor todas cuelgan de `/api`.

## Resumen de endpoints

| Método | Ruta | Rol requerido | Descripción |
|---|---|---|---|
| GET | `/api/prueba` | Público | Prueba de que el servidor funciona (ya implementado) |
| POST | `/api/auth/registro` | Público | Registra un usuario nuevo (opcional) |
| POST | `/api/auth/login` | Público | Inicia sesión y devuelve el token |
| GET | `/api/auth/perfil` | `usuario`, `operador` | Devuelve los datos del usuario del token |
| POST | `/api/incidencias` | `usuario`, `operador` | Crea una incidencia |
| GET | `/api/incidencias` | `usuario`, `operador` | Lista incidencias con búsqueda y filtros |
| GET | `/api/incidencias/resumen` | `usuario`, `operador` | Conteo de incidencias por estado |
| GET | `/api/incidencias/:id` | `usuario`, `operador` | Detalle de una incidencia |
| PUT | `/api/incidencias/:id` | `usuario` (creador) | Edita una incidencia pendiente |
| DELETE | `/api/incidencias/:id` | `usuario` (creador), `operador` | Cancela una incidencia pendiente |
| PATCH | `/api/incidencias/:id/estado` | `operador` | Avanza o cancela una incidencia |
| GET | `/api/incidencias/:id/historial` | `usuario` (creador), `operador` | Historial de cambios |
| POST | `/api/incidencias/:id/evidencias` | `usuario` (creador), `operador` | Sube imágenes |
| GET | `/api/incidencias/:id/evidencias` | `usuario` (creador), `operador` | Lista las evidencias |
| GET | `/api/categorias` | `usuario`, `operador` | Lista las categorías |
| POST | `/api/categorias` | `operador` | Crea una categoría |
| PUT | `/api/categorias/:id` | `operador` | Edita una categoría |

Salvo los marcados como públicos, todos los endpoints requieren el token.

## Límites y validaciones de campos

Los máximos coinciden con `database/schema.sql`. Los mínimos los define el equipo para que el backend y Flutter validen igual. Un campo que no cumple devuelve 400 con el detalle en `errores`.

| Campo | Mínimo | Máximo | Reglas |
|---|---|---|---|
| `nombre` (usuario) | 2 | 100 | Obligatorio |
| `correo` | 5 | 150 | Obligatorio, formato de correo válido |
| `password` | 8 | 72 | Obligatorio al registrar (72 es el límite de bcrypt). En el login solo se exige que no esté vacío |
| `titulo` | 5 | 150 | Obligatorio |
| `descripcion` | 10 | 2000 | Obligatorio |
| `id_categoria` | | | Obligatorio, entero positivo de una categoría existente y activa |
| `ubicacion_texto` | 3 | 200 | Opcional si se envían `latitud` y `longitud` |
| `latitud` | -90 | 90 | Número con hasta 6 decimales; se envía junto con `longitud` |
| `longitud` | -180 | 180 | Número con hasta 6 decimales; se envía junto con `latitud` |
| `solucion_descripcion` | 10 | 2000 | Obligatoria al pasar a `finalizada` |
| `comentario` (historial) | | 500 | Opcional |
| `nombre` (categoría) | 3 | 80 | Obligatorio, único |
| `descripcion` (categoría) | | 255 | Opcional |
| `q` (búsqueda) | | 100 | Opcional |
| `imagenes` | | 5 archivos, 5 MB cada uno | Solo `image/jpeg`, `image/png` y `image/webp` |

Los campos `ruta_archivo` (255), `nombre_original` (255) y `mime_type` (100) los genera el servidor al guardar cada imagen.

---

## Formato de errores

Todos los errores responden con el mismo formato JSON:

```json
{
  "ok": false,
  "mensaje": "Descripción del error para mostrar al usuario",
  "errores": [
    { "campo": "titulo", "mensaje": "El título es obligatorio" }
  ]
}
```

`errores` solo aparece en los errores de validación (400).

| Código | Cuándo ocurre |
|---|---|
| 400 | Datos inválidos, campos faltantes o transición de estado no permitida |
| 401 | Falta el token, es inválido o expiró; o las credenciales del login son incorrectas |
| 403 | El usuario no tiene permiso para esa operación |
| 404 | El recurso no existe |
| 500 | Error interno del servidor (sin detalles sensibles en el mensaje) |

---

## Autenticación

### POST `/api/auth/registro`

- **Rol:** público.
- **Descripción:** crea un usuario con rol `usuario`. Los operadores se crean directamente en la base de datos.
- **Opcional:** la app no tiene pantalla de registro por ahora; los usuarios de prueba (uno por rol) se cargan en el script de datos de prueba (B4).

**Cuerpo:**
```json
{
  "nombre": "Ana López",
  "correo": "ana@correo.com",
  "password": "MiClave123"
}
```

**Respuesta 201:**
```json
{
  "id_usuario": 5,
  "nombre": "Ana López",
  "correo": "ana@correo.com",
  "rol": "usuario"
}
```

**Errores:** 400 (campos inválidos o correo ya registrado), 500.

### POST `/api/auth/login`

- **Rol:** público.

**Cuerpo:**
```json
{
  "correo": "ana@correo.com",
  "password": "MiClave123"
}
```

**Respuesta 200:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "usuario": {
    "id_usuario": 5,
    "nombre": "Ana López",
    "correo": "ana@correo.com",
    "rol": "usuario"
  }
}
```

**Errores:** 400 (faltan campos), 401 (credenciales incorrectas o usuario inactivo), 500.

### GET `/api/auth/perfil`

- **Rol:** `usuario` u `operador`.
- **Descripción:** devuelve los datos del usuario a partir del token. La app lo usa al abrirse con una sesión guardada, para recuperar nombre, correo y rol, y para comprobar que el token sigue siendo válido.

**Respuesta 200:**
```json
{
  "id_usuario": 5,
  "nombre": "Ana López",
  "correo": "ana@correo.com",
  "rol": "usuario"
}
```

**Errores:** 401 (token inválido, expirado, o el usuario ya no existe o está inactivo), 500.

---

## Incidencias

Objeto incidencia (se usa en varias respuestas):

```json
{
  "id_incidencia": 12,
  "titulo": "Lámpara fundida en el pasillo",
  "descripcion": "La lámpara del pasillo del edificio 3 no enciende desde el lunes.",
  "estado": "pendiente",
  "categoria": { "id_categoria": 2, "nombre": "Electricidad" },
  "reportado_por": { "id_usuario": 5, "nombre": "Ana López" },
  "operador": null,
  "ubicacion_texto": "Edificio 3, planta baja",
  "latitud": 21.912345,
  "longitud": -102.296789,
  "solucion_descripcion": null,
  "fecha_creacion": "2026-11-11T15:30:00.000Z",
  "fecha_actualizacion": "2026-11-11T15:30:00.000Z",
  "fecha_finalizacion": null
}
```

Cuando una incidencia ya tiene operador, `operador` es `{ "id_usuario": 2, "nombre": "Luis Pérez" }`.

### POST `/api/incidencias`

- **Rol:** `usuario` u `operador`.
- **Descripción:** crea una incidencia en estado `pendiente` y registra la creación en el historial.

**Cuerpo:**
```json
{
  "titulo": "Lámpara fundida en el pasillo",
  "descripcion": "La lámpara del pasillo del edificio 3 no enciende desde el lunes.",
  "id_categoria": 2,
  "ubicacion_texto": "Edificio 3, planta baja",
  "latitud": 21.912345,
  "longitud": -102.296789
}
```

`titulo`, `descripcion` e `id_categoria` son obligatorios.

**Ubicación:** se debe enviar al menos una forma de ubicación: `ubicacion_texto`, o el par `latitud` y `longitud` (siempre las dos juntas). Se pueden enviar ambas. Esta regla se valida en el backend; en la base de datos esos campos admiten `NULL`.

**Respuesta 201:** el objeto incidencia.

**Errores:** 400 (datos inválidos, falta la ubicación, o categoría inexistente o inactiva), 401, 500.

### GET `/api/incidencias`

- **Rol:** `usuario` u `operador`.
- **Descripción:** el `usuario` ve solo sus incidencias; el `operador` ve todas. Ordenadas de la más reciente a la más antigua.

**Parámetros opcionales (query):**

| Parámetro | Ejemplo | Descripción |
|---|---|---|
| `estado` | `?estado=pendiente` | Filtra por estado |
| `categoria` | `?categoria=2` | Filtra por `id_categoria` |
| `q` | `?q=lámpara` | Busca el texto en título y descripción |

Los parámetros se pueden combinar: `/api/incidencias?estado=pendiente&categoria=2&q=lámpara`.

**Respuesta 200:**
```json
[
  {
    "id_incidencia": 12,
    "titulo": "Lámpara fundida en el pasillo",
    "estado": "pendiente",
    "categoria": { "id_categoria": 2, "nombre": "Electricidad" },
    "reportado_por": { "id_usuario": 5, "nombre": "Ana López" },
    "operador": null,
    "ubicacion_texto": "Edificio 3, planta baja",
    "fecha_creacion": "2026-11-11T15:30:00.000Z"
  }
]
```

`operador` es `null` mientras la incidencia no se asigna; después es `{ "id_usuario": 2, "nombre": "Luis Pérez" }`. El panel del operador lo usa para mostrar quién atiende cada incidencia.

Si no hay resultados, responde `200` con una lista vacía `[]`.

**Errores:** 400 (por ejemplo, `estado` con un valor no válido), 401, 500.

### GET `/api/incidencias/resumen`

- **Rol:** `usuario` u `operador` (el usuario cuenta solo las suyas).
- **Descripción:** conteo de incidencias por estado, para la pantalla principal.

**Respuesta 200:**
```json
{
  "pendiente": 3,
  "asignada": 1,
  "en_proceso": 2,
  "finalizada": 8,
  "cancelada": 0,
  "total": 14
}
```

**Errores:** 401, 500.

### GET `/api/incidencias/:id`

- **Rol:** `usuario` (solo si es el creador) u `operador`.

**Respuesta 200:** el objeto incidencia completo.

**Errores:** 401, 403 (la incidencia es de otro usuario), 404, 500.

### PUT `/api/incidencias/:id`

- **Rol:** `usuario`, solo el creador y solo mientras la incidencia está `pendiente`.
- **Descripción:** edita los datos. Registra el cambio en el historial.

**Cuerpo (mismos campos y reglas que al crear, incluida la ubicación):**
```json
{
  "titulo": "Lámpara fundida en el pasillo del edificio 3",
  "descripcion": "No enciende desde el lunes. Ya se revisó el apagador.",
  "id_categoria": 2,
  "ubicacion_texto": "Edificio 3, planta baja"
}
```

**Respuesta 200:** el objeto incidencia actualizado.

**Errores:** 400 (datos inválidos, la incidencia se quedaría sin ubicación, o ya no está pendiente), 401, 403 (no es el creador), 404, 500.

### DELETE `/api/incidencias/:id`

- **Rol:** `usuario` (solo el creador) u `operador`.
- **Descripción:** cancela la incidencia. No la borra: cambia su estado a `cancelada` y lo registra en el historial. Solo se puede cancelar una incidencia `pendiente`. Equivale a `PATCH /api/incidencias/:id/estado` con `cancelada`, pero lo puede usar también el creador.

**Respuesta 200:**
```json
{
  "ok": true,
  "mensaje": "Incidencia cancelada",
  "estado": "cancelada"
}
```

**Errores:** 400 (la incidencia ya no está pendiente), 401, 403, 404, 500.

---

## Cambio de estado

Flujo permitido:

```
pendiente → asignada → en_proceso → finalizada
pendiente → cancelada
```

La cancelación solo es posible desde `pendiente`. El operador puede hacerla con este endpoint (`estado: "cancelada"`) y el creador con `DELETE /api/incidencias/:id`. Ambos aplican la misma validación y dejan registro en el historial.

### PATCH `/api/incidencias/:id/estado`

- **Rol:** `operador`.
- **Descripción:** avanza la incidencia al siguiente estado o la cancela. Al pasar a `asignada`, el operador que hace la petición queda registrado como responsable. Cada cambio se guarda en el historial.

**Cuerpo:**
```json
{
  "estado": "finalizada",
  "solucion_descripcion": "Se cambió la lámpara y se revisó el balastro.",
  "comentario": "Trabajo concluido"
}
```

| Campo | Obligatorio | Descripción |
|---|---|---|
| `estado` | Sí | Nuevo estado: `asignada`, `en_proceso`, `finalizada` o `cancelada` |
| `solucion_descripcion` | Solo si `estado` es `finalizada` | Descripción de la solución aplicada |
| `comentario` | No | Nota que se guarda en el historial |

**Regla del sistema:** no se puede pasar a `finalizada` sin `solucion_descripcion` (no vacía).

**Respuesta 200:** el objeto incidencia actualizado.

**Errores:**
- 400: transición no permitida (por ejemplo, de `pendiente` a `finalizada`), estado inválido, o falta `solucion_descripcion` al finalizar.
- 401, 403 (el rol no es `operador`), 404, 500.

Ejemplo de error por transición inválida:
```json
{
  "ok": false,
  "mensaje": "Transición no permitida: de 'pendiente' a 'finalizada'"
}
```

---

## Historial

### GET `/api/incidencias/:id/historial`

- **Rol:** `usuario` (solo si es el creador) u `operador`.
- **Descripción:** cambios de la incidencia ordenados del más antiguo al más reciente.

**Respuesta 200:**
```json
[
  {
    "id_historial": 30,
    "accion": "creacion",
    "estado_anterior": null,
    "estado_nuevo": "pendiente",
    "comentario": null,
    "fecha": "2026-11-11T15:30:00.000Z",
    "responsable": { "id_usuario": 5, "nombre": "Ana López" }
  },
  {
    "id_historial": 31,
    "accion": "cambio_estado",
    "estado_anterior": "pendiente",
    "estado_nuevo": "asignada",
    "comentario": null,
    "fecha": "2026-11-12T09:10:00.000Z",
    "responsable": { "id_usuario": 2, "nombre": "Luis Pérez" }
  }
]
```

`accion` puede ser `creacion`, `edicion` o `cambio_estado`.

**Errores:** 401, 403 (la incidencia es de otro usuario), 404, 500.

---

## Evidencias

### POST `/api/incidencias/:id/evidencias`

- **Rol:** `usuario` (solo si es el creador) u `operador`.
- **Tipo de contenido:** `multipart/form-data`.
- **Descripción:** sube una o varias imágenes asociadas a la incidencia. Para crear una incidencia con fotos, primero se crea con `POST /api/incidencias` y después se suben las imágenes con el `id_incidencia` que devuelve.

**Campos del formulario:**

| Campo | Obligatorio | Descripción |
|---|---|---|
| `imagenes` | Sí | Archivos de imagen (máximo 5 por petición) |
| `tipo` | No | `reporte` (por defecto) o `atencion`. `atencion` solo la puede usar el `operador` |

**Restricciones:** solo `image/jpeg`, `image/png` y `image/webp`, con un máximo de 5 MB por archivo.

**Respuesta 201:**
```json
[
  {
    "id_evidencia": 7,
    "tipo": "reporte",
    "url": "/uploads/evidencias/1762875000-lampara.jpg",
    "nombre_original": "lampara.jpg",
    "mime_type": "image/jpeg",
    "fecha_subida": "2026-11-11T15:31:00.000Z"
  }
]
```

**Errores:** 400 (sin archivos, formato no permitido o archivo demasiado grande), 401, 403, 404, 500.

### GET `/api/incidencias/:id/evidencias`

- **Rol:** `usuario` (solo si es el creador) u `operador`.

**Respuesta 200:** lista de evidencias con el mismo formato de arriba (`[]` si no hay).

`url` es relativa al servidor, sin el prefijo `/api`. Para mostrar la imagen, la app usa `<host del servidor><url>`, por ejemplo `http://localhost:3000/uploads/evidencias/1762875000-lampara.jpg`.

**Errores:** 401, 403, 404, 500.

---

## Categorías

Objeto categoría:
```json
{
  "id_categoria": 2,
  "nombre": "Electricidad",
  "descripcion": "Fallas eléctricas, iluminación y contactos",
  "activa": true
}
```

### GET `/api/categorias`

- **Rol:** `usuario` u `operador`.
- **Descripción:** el `usuario` ve solo las categorías activas; el `operador` ve todas.

**Respuesta 200:** lista de objetos categoría.

**Errores:** 401, 500.

### POST `/api/categorias`

- **Rol:** `operador`.

**Cuerpo:**
```json
{
  "nombre": "Plomería",
  "descripcion": "Fugas, drenajes y sanitarios"
}
```

**Respuesta 201:** el objeto categoría creado.

**Errores:** 400 (nombre vacío o ya existente), 401, 403, 500.

### PUT `/api/categorias/:id`

- **Rol:** `operador`.

**Cuerpo:**
```json
{
  "nombre": "Plomería",
  "descripcion": "Fugas, drenajes, sanitarios y tinacos",
  "activa": true
}
```

**Respuesta 200:** el objeto categoría actualizado.

**Errores:** 400, 401, 403, 404, 500.