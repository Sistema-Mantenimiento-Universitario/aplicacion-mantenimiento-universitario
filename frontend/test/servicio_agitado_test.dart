// Pruebas del detector de agitado, con movimientos simulados
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'package:mantenimiento_universitario/services/servicio_agitado.dart';

final _inicio = DateTime(2026, 11, 25, 10);

// Lectura del acelerómetro a los milisegundos del inicio
AccelerometerEvent _lectura(double x, double y, double z, int ms) =>
    AccelerometerEvent(x, y, z, _inicio.add(Duration(milliseconds: ms)));

// Cuenta cuántos agitados detecta el servicio con esas lecturas
Future<int> _contarAgitados(List<AccelerometerEvent> lecturas) async {
  final servicio = ServicioAgitado(eventos: Stream.fromIterable(lecturas));
  return servicio.agitados.length;
}

void main() {
  test('En reposo no detecta agitado', () async {
    // Solo la gravedad: unos 9.8 m/s² en el eje z
    final cuantos = await _contarAgitados([
      _lectura(0, 0, 9.8, 0),
      _lectura(0.2, 0.1, 9.7, 100),
      _lectura(0.1, 0.3, 9.9, 200),
    ]);

    expect(cuantos, 0);
  });

  test('Un movimiento fuerte cuenta como agitado', () async {
    final cuantos = await _contarAgitados([
      _lectura(0, 0, 9.8, 0),
      _lectura(22, 15, 9.8, 100),
    ]);

    expect(cuantos, 1);
  });

  test('Un solo agitado no se cuenta varias veces', () async {
    // Varias lecturas fuertes en menos de 2 segundos = un agitado
    final cuantos = await _contarAgitados([
      _lectura(22, 15, 9.8, 0),
      _lectura(-25, 10, 9.8, 100),
      _lectura(24, -12, 9.8, 300),
      // Pasados los 2 segundos sí cuenta otro
      _lectura(23, 14, 9.8, 2500),
    ]);

    expect(cuantos, 2);
  });

  test('Si no hay acelerómetro no truena', () async {
    final servicio = ServicioAgitado(
      eventos: Stream.error(UnsupportedError('Sin acelerómetro')),
    );

    expect(await servicio.agitados.length, 0);
  });
}
