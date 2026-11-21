// Nombres de rutas centralizados para la navegación.
class Rutas {
  static const inicio = '/';
  static const nuevaIncidencia = '/incidencias/nueva';
  static const misIncidencias = '/incidencias/mias';
  static const adminIncidencias = '/incidencias/admin';
  static const detalleIncidencia = '/incidencias/detalle';
  static const editarIncidencia = '/incidencias/editar';

  // El id va en la URL (p. ej. /incidencias/detalle?id=5) para que la
  // pantalla se pueda volver a abrir al recargar la página en web
  static String detalle(int id) => '$detalleIncidencia?id=$id';
  static String editar(int id) => '$editarIncidencia?id=$id';

  // Ruta sin parámetros: '/incidencias/detalle?id=5' -> '/incidencias/detalle'
  static String base(String ruta) => Uri.parse(ruta).path;

  // Id de la URL: '/incidencias/detalle?id=5' -> 5 (null si no viene)
  static int? idDe(String ruta) =>
      int.tryParse(Uri.parse(ruta).queryParameters['id'] ?? '');
}
