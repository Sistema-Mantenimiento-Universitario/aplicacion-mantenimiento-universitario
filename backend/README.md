# Backend — Despliegue

El backend y la base de datos están desplegados en [Railway](https://railway.com), en un mismo proyecto.

**URL de la API:** https://aplicacion-mantenimiento-universitario-production.up.railway.app/api

Para comprobar que funciona: `GET /api/prueba/db` responde `"ok": true` con el nombre de la base.

## Servicios del proyecto

| Servicio | Configuración |
|---|---|
| Backend | Desde este repositorio, con Root Directory `/backend`. Railway ejecuta `npm install` y `npm start`. Dominio público generado en el puerto 8080 (HTTPS automático) |
| MySQL | Base de datos de Railway (MySQL 8.4). El backend se conecta por la red privada del proyecto |
| Volumen | Montado en el backend en `/app/uploads`, para que las imágenes de evidencias no se pierdan al reiniciar o volver a desplegar |

## Variables de entorno del backend

Se configuran en la pestaña Variables del servicio del backend (nunca en el repositorio):

```
DB_HOST=${{MySQL.MYSQLHOST}}
DB_PORT=${{MySQL.MYSQLPORT}}
DB_USER=${{MySQL.MYSQLUSER}}
DB_PASSWORD=${{MySQL.MYSQLPASSWORD}}
DB_NAME=mantenimiento_universitario
JWT_SECRET=<cadena larga y aleatoria>
JWT_EXPIRES_IN=24h
```

Las `DB_*` son referencias a las variables del servicio de MySQL. `PORT` la define Railway.

## Cargar la base de datos

Desde la pestaña Console del servicio de MySQL:

```bash
mysql -u root -p"$MYSQL_ROOT_PASSWORD"
```

Y pegar, en este orden, el contenido de `database/schema.sql`, `database/datos_prueba.sql` y `database/datos_categorias.sql`. Las tablas quedan en la base `mantenimiento_universitario`; el visor Data de Railway solo muestra la base `railway`, así que las consultas se hacen desde la consola.

## Fechas

La API maneja todas las fechas en UTC (`db.js` fija la zona horaria de la conexión) y la app las convierte a la hora local del dispositivo.

## Conectar la app

```bash
flutter build web --dart-define=API_REAL=true --dart-define=API_URL=https://aplicacion-mantenimiento-universitario-production.up.railway.app/api
```

Lo mismo para `flutter build apk` y `flutter build windows` (ver `frontend/README.md`).
