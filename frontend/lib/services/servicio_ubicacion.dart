import 'dart:async';

import 'package:geolocator/geolocator.dart';

// Latitud y longitud con hasta 6 decimales
typedef Coordenadas = ({double latitud, double longitud});

// Error de ubicación con el mensaje listo para mostrarse al usuario
class UbicacionException implements Exception {
  UbicacionException(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

// Envuelve geolocator. Las pantallas usan esta clase y no el paquete
// directamente, así en las pruebas se puede reemplazar por una simulada
class ServicioUbicacion {
  const ServicioUbicacion();

  Future<Coordenadas> obtenerUbicacion() async {
    // El GPS del dispositivo debe estar encendido
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw UbicacionException(
        'Activa la ubicación del dispositivo o escribe la ubicación a mano',
      );
    }

    // Permiso
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied) {
      throw UbicacionException(
        'No se dio permiso de ubicación. Puedes escribir la ubicación a mano',
      );
    }
    if (permiso == LocationPermission.deniedForever) {
      throw UbicacionException(
        'El permiso de ubicación está bloqueado. Actívalo en la '
        'configuración del dispositivo o escribe la ubicación a mano',
      );
    }

    // Posición actual, con un límite de tiempo
    try {
      final posicion = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return (
        latitud: redondear(posicion.latitude),
        longitud: redondear(posicion.longitude),
      );
    } on TimeoutException {
      throw UbicacionException(
        'No se pudo obtener la ubicación a tiempo. Intenta de nuevo',
      );
    } catch (_) {
      throw UbicacionException('No se pudo obtener la ubicación');
    }
  }

  static double redondear(double valor) =>
      double.parse(valor.toStringAsFixed(6));
}