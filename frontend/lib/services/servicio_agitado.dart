import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

// Detecta cuando el usuario agita el celular, a partir del acelerómetro.
class ServicioAgitado {
  ServicioAgitado({
    this.eventos,
    this.umbral = 25,
    this.espera = const Duration(seconds: 2),
  });

  // El acelerómetro solo existe en celulares (y en el navegador del
  // celular). En Windows no hay sensor (ahí se usa el botón de recargar)
  static bool get disponible =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  // Lecturas del acelerómetro, null: se usa el sensor real
  final Stream<AccelerometerEvent>? eventos;

  // Fuerza mínima para contar como agitado. En reposo la fuerza
  // es de unos 9.8 por la gravedad; al agitar pasa de 25 (unas 2.5 veces)
  final double umbral;

  // Tiempo mínimo entre dos agitados, para que un solo movimiento
  // no dispare la acción varias veces seguidas
  final Duration espera;

  // Avisa una vez por cada agitado detectado
  Stream<void> get agitados {
    final lecturas =
        eventos ??
        accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval);
    DateTime? ultimo;

    return lecturas
        .where((evento) {
          if (fuerza(evento) < umbral) return false;
          final antes = ultimo;
          if (antes != null && evento.timestamp.difference(antes) < espera) {
            return false;
          }
          ultimo = evento.timestamp;
          return true;
        })
        .map((_) {})
        // En web o escritorio puede no haber acelerómetro: Se ignora el error
        // y la pantalla sigue funcionando con su botón de recargar
        .handleError((Object _) {});
  }

  // Fuerza total del movimiento en los tres ejes
  static double fuerza(AccelerometerEvent evento) =>
      sqrt(evento.x * evento.x + evento.y * evento.y + evento.z * evento.z);
}
