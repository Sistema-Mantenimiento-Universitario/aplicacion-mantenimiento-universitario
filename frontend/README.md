# Mantenimiento universitario

Aplicación para reportar y dar seguimiento a fallas en las instalaciones de la universidad. Funciona en Android, web y Windows.

**Versión web:** https://mantenimiento-universitario.vercel.app

> Por ahora la versión publicada usa datos simulados: Las incidencias que se crean se guardan solo en el navegador de ese dispositivo y se pierden al recargar. Cuando el backend esté desplegado, se publicará la versión conectada a él.

## Usuarios de prueba (datos simulados)

| Rol | Correo | Contraseña |
|---|---|---|
| Usuario | `ana@correo.com` | `Ana12345` |
| Operador | `luis@correo.com` | `Luis12345` |

## Requisitos

- Flutter 3.47 o superior (`flutter doctor` sin problemas)
- Android: Android SDK y un celular con depuración USB o un emulador
- Windows: Visual Studio 2022 con "Desarrollo para el escritorio con C++"

## Ejecutar en desarrollo

```bash
cd frontend
flutter pub get
flutter run              # Elegir el dispositivo
flutter test             
```

Por defecto la app usa datos simulados. Para usar el backend real:

```bash
flutter run --dart-define=API_REAL=true --dart-define=API_URL=http://localhost:3000/api
```

En el emulador de Android, `localhost` es `http://10.0.2.2:3000/api`.

## Generar las versiones

Todos los comandos se ejecutan desde `frontend`. Para apuntar al backend desplegado, agregar a cada uno `--dart-define=API_REAL=true --dart-define=API_URL=https://<backend>/api`.

### Android (APK)

```bash
flutter build apk --release
```

Resultado: `build/app/outputs/flutter-apk/app-release.apk`. Se instala con `flutter install` (celular conectado) o copiando el archivo al celular y abriéndolo (hay que permitir instalar apps de origen desconocido).

### Web

```bash
flutter build web
```

Resultado: la carpeta `build/web`. Se publica en Vercel como sitio estático:

```bash
cd build/web
vercel --prod
```

La primera vez se crea el proyecto (sin conectar el repositorio de Git y sin modificar la configuración). Las siguientes veces se elige el proyecto existente `mantenimiento-universitario`.

### Windows

```bash
flutter build windows --release
```

Resultado: la carpeta `build/windows/x64/runner/Release`. Para compartirla se comprime **toda la carpeta**: el `.exe` necesita las `.dll` y la carpeta `data` que están junto a él.

## Alternativas según la plataforma

| Función | Android | Web | Windows |
|---|---|---|---|
| Fotos | Cámara y galería | Elegir imagen | Elegir imagen |
| Ubicación | GPS (pide permiso) | Ubicación del navegador (pide permiso) o a mano | Ubicación de Windows o a mano |
| Recargar | Agitar el celular o botón de actualizar | Botón de actualizar | Botón de actualizar |
