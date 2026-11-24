import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/datos_incidencia.dart';

// Foto escogida por el usuario. Aquí se guardan los bytes y no la ruta del
// archivo, porque en web no hay rutas
class FotoSeleccionada {
  const FotoSeleccionada({
    required this.nombre,
    required this.bytes,
    required this.tipoMime,
  });

  final String nombre;
  final Uint8List bytes;
  final String tipoMime;
}

// Error al seleccionar una foto
class ImagenException implements Exception {
  ImagenException(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

// Envuelve image_picker para poder reemplazarlo en las pruebas
class ServicioImagenes {
  ServicioImagenes({ImagePicker? selector})
    : _selector = selector ?? ImagePicker();

  final ImagePicker _selector;

  // Solo Android e iOS tienen cámara integrada; en web y escritorio
  // se ofrece elegir un archivo
  bool get hayCamara =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  // null si el usuario cerró la cámara o la galería sin elegir nada
  Future<FotoSeleccionada?> tomarFoto() => _elegir(ImageSource.camera);

  Future<FotoSeleccionada?> elegirDeGaleria() => _elegir(ImageSource.gallery);

  Future<FotoSeleccionada?> _elegir(ImageSource origen) async {
    final XFile? archivo;
    try {
      // Se reduce la foto para que pese menos
      archivo = await _selector.pickImage(
        source: origen,
        imageQuality: 70,
        maxWidth: 1280,
      );
    } on PlatformException {
      throw ImagenException(
        origen == ImageSource.camera
            ? 'No se pudo abrir la cámara. Revisa el permiso de cámara'
            : 'No se pudo abrir la galería. Revisa el permiso de fotos',
      );
    }
    if (archivo == null) return null;

    return validar(archivo.name, await archivo.readAsBytes());
  }

  // Revisa el formato y el tamaño que acepta el backend
  static FotoSeleccionada validar(String nombre, Uint8List bytes) {
    final tipoMime = tipoMimeDe(nombre);
    if (tipoMime == null) {
      throw ImagenException('Solo se permiten imágenes JPG, PNG o WEBP');
    }
    if (bytes.length > LimitesIncidencia.fotoMaxBytes) {
      throw ImagenException('La imagen pesa más de 5 MB');
    }
    return FotoSeleccionada(nombre: nombre, bytes: bytes, tipoMime: tipoMime);
  }

  // Tipo de archivo según la extensión, null si no está permitido
  static String? tipoMimeDe(String nombre) {
    final extension = nombre.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => null,
    };
  }
}
