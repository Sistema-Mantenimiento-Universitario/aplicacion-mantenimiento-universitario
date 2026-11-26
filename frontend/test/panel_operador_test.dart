// Panel de administración del operador.
// Usan el repositorio simulado (sus datos cambian dentro de este archivo,
// por eso cada prueba usa incidencias distintas).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mantenimiento_universitario/data/incidencias_fake_repository.dart';
import 'package:mantenimiento_universitario/data/incidencias_repository.dart';
import 'package:mantenimiento_universitario/models/estado_incidencia.dart';
import 'package:mantenimiento_universitario/models/incidencia.dart';
import 'package:mantenimiento_universitario/models/transiciones_estado.dart';
import 'package:mantenimiento_universitario/models/usuario.dart';
import 'package:mantenimiento_universitario/pages/panel_operador_page.dart';
import 'package:mantenimiento_universitario/services/servicio_agitado.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:mantenimiento_universitario/theme/app_theme.dart';
import 'package:mantenimiento_universitario/widgets/estado_chip.dart';

const _luis = Usuario(
  id: 2,
  nombre: 'Luis Pérez',
  correo: 'luis@correo.com',
  rol: Rol.operador,
);

const _ana = Usuario(
  id: 1,
  nombre: 'Ana López',
  correo: 'ana@correo.com',
  rol: Rol.usuario,
);

FakeIncidenciasRepository _fake(Usuario u) => FakeIncidenciasRepository(
  idUsuario: u.id,
  esOperador: u.esOperador,
  demora: Duration.zero,
);

// Simula que el backend rechaza el cambio
class _RepositorioQueRechaza extends FakeIncidenciasRepository {
  _RepositorioQueRechaza()
    : super(idUsuario: 2, esOperador: true, demora: Duration.zero);

  @override
  Future<Incidencia> cambiarEstado(
    int id,
    EstadoIncidencia nuevoEstado, {
    String? solucion,
    String? comentario,
  }) async => throw ApiException(
    "Transición no permitida: de 'asignada' a 'en_proceso'",
    statusCode: 400,
  );
}

// Repositorio simulado que cuenta cuántas veces se pidió la lista
class _RepositorioContador extends FakeIncidenciasRepository {
  _RepositorioContador()
    : super(idUsuario: 2, esOperador: true, demora: Duration.zero);

  int cargas = 0;

  @override
  Future<List<Incidencia>> obtenerIncidencias({
    String? texto,
    EstadoIncidencia? estado,
    int? idCategoria,
  }) {
    cargas++;
    return super.obtenerIncidencias(
      texto: texto,
      estado: estado,
      idCategoria: idCategoria,
    );
  }
}

Future<void> _abrirPanel(
  WidgetTester tester, {
  Usuario usuario = _luis,
  IncidenciasRepository? repositorio,
  ServicioAgitado? agitado,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.claro,
      home: PanelOperadorPage(
        usuario: usuario,
        repositorio: repositorio ?? _fake(usuario),
        servicioAgitado: agitado,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _tarjeta(int id) => find.byKey(ValueKey('incidencia-$id'));

// Estado que muestra la tarjeta de una incidencia
EstadoIncidencia _estadoDe(WidgetTester tester, int id) => tester
    .widget<EstadoChip>(
      find.descendant(of: _tarjeta(id), matching: find.byType(EstadoChip)),
    )
    .estado;

void main() {
  group('Transiciones permitidas', () {
    test('Flujo normal y cancelación solo desde pendiente', () {
      expect(EstadoIncidencia.pendiente.permitidos, [
        EstadoIncidencia.asignada,
        EstadoIncidencia.cancelada,
      ]);
      expect(EstadoIncidencia.asignada.permitidos, [
        EstadoIncidencia.enProceso,
      ]);
      expect(EstadoIncidencia.enProceso.permitidos, [
        EstadoIncidencia.finalizada,
      ]);
      expect(EstadoIncidencia.finalizada.permitidos, isEmpty);
      expect(EstadoIncidencia.cancelada.permitidos, isEmpty);
    });

    test('Solución obligatoria de 10 a 2000 caracteres', () {
      expect(
        PanelOperadorPage.validarSolucion(''),
        'Escribe la solución aplicada',
      );
      expect(
        PanelOperadorPage.validarSolucion('corta'),
        'La solución debe tener entre 10 y 2000 caracteres',
      );
      expect(
        PanelOperadorPage.validarSolucion('a' * 2001),
        'La solución debe tener entre 10 y 2000 caracteres',
      );
      expect(PanelOperadorPage.validarSolucion('Se cambió el foco'), isNull);
    });
  });

  testWidgets('Muestra todas agrupadas y filtra por estado', (tester) async {
    await _abrirPanel(tester);

    expect(find.text('Todas  7'), findsOneWidget);
    expect(find.text('Pendiente  3'), findsOneWidget);
    expect(find.text('3 incidencias'), findsOneWidget); // grupo pendientes

    await tester.tap(find.text('Pendiente  3'));
    await tester.pumpAndSettle();

    expect(find.byType(Dismissible), findsNWidgets(3));
    expect(find.text('Silla rota en el aula 204'), findsNothing); // en proceso
  });

  testWidgets('Deslizar a la derecha avanza al siguiente estado', (
    tester,
  ) async {
    await _abrirPanel(tester);
    expect(_estadoDe(tester, 1), EstadoIncidencia.pendiente);

    await tester.drag(_tarjeta(1), const Offset(600, 0));
    await tester.pumpAndSettle();

    expect(_estadoDe(tester, 1), EstadoIncidencia.asignada);
    expect(find.text('#1 pasó a Asignada'), findsOneWidget);
  });

  testWidgets('Finalizar exige la solución aplicada', (tester) async {
    await _abrirPanel(tester);
    expect(_estadoDe(tester, 3), EstadoIncidencia.enProceso);

    // Mantener presionado → Finalizar
    await tester.longPress(_tarjeta(3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Finalizar la incidencia?'), findsOneWidget);

    // Sin solución
    await tester.tap(find.widgetWithText(FilledButton, 'Finalizar'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe la solución aplicada'), findsOneWidget);

    // Muy corta
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Solución aplicada'),
      'Listo',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Finalizar'));
    await tester.pumpAndSettle();
    expect(
      find.text('La solución debe tener entre 10 y 2000 caracteres'),
      findsOneWidget,
    );

    // Válida
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Solución aplicada'),
      'Se cambió la pata de la silla',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Finalizar'));
    await tester.pumpAndSettle();

    expect(find.text('¿Finalizar la incidencia?'), findsNothing);
    expect(_estadoDe(tester, 3), EstadoIncidencia.finalizada);
  });

  testWidgets('Las opciones solo muestran los estados permitidos', (
    tester,
  ) async {
    await _abrirPanel(tester);

    // Pendiente: asignar o cancelar, no finalizar
    await tester.longPress(_tarjeta(6));
    await tester.pumpAndSettle();
    expect(find.text('Ver detalle'), findsOneWidget);
    expect(find.text('Asignarme'), findsOneWidget);
    expect(find.text('Cancelar incidencia'), findsOneWidget);
    expect(find.text('Finalizar'), findsNothing);
    await tester.tapAt(const Offset(10, 10)); // cerrar la hoja
    await tester.pumpAndSettle();

    // Finalizada: ya no cambia
    await tester.longPress(_tarjeta(4));
    await tester.pumpAndSettle();
    expect(find.text('Asignarme'), findsNothing);
    expect(find.text('Esta incidencia ya no cambia de estado'), findsOneWidget);
  });

  testWidgets(
    'Deslizar a la izquierda cancela una pendiente con confirmación',
    (tester) async {
      await _abrirPanel(tester);
      expect(_estadoDe(tester, 5), EstadoIncidencia.pendiente);

      await tester.drag(_tarjeta(5), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.text('¿Cancelar la incidencia?'), findsOneWidget);

      await tester.tap(
        find.widgetWithText(FilledButton, 'Cancelar incidencia'),
      );
      await tester.pumpAndSettle();

      expect(_estadoDe(tester, 5), EstadoIncidencia.cancelada);
    },
  );

  testWidgets('Muestra el error que devuelve el backend', (tester) async {
    await _abrirPanel(tester, repositorio: _RepositorioQueRechaza());

    await tester.drag(_tarjeta(2), const Offset(600, 0));
    await tester.pumpAndSettle();

    expect(
      find.text("Transición no permitida: de 'asignada' a 'en_proceso'"),
      findsOneWidget,
    );
  });

  testWidgets('Un usuario normal no puede usar el panel', (tester) async {
    await _abrirPanel(tester, usuario: _ana);

    expect(find.text('Esta pantalla es solo para operadores.'), findsOneWidget);
    expect(find.byType(Dismissible), findsNothing);
  });

  testWidgets('Al agitar el celular se recarga el panel', (tester) async {
    final repositorio = _RepositorioContador();
    // Acelerómetro simulado: aquí se "agita" agregando lecturas
    final sensor = StreamController<AccelerometerEvent>();
    addTearDown(sensor.close);

    await _abrirPanel(
      tester,
      repositorio: repositorio,
      agitado: ServicioAgitado(eventos: sensor.stream),
    );
    expect(repositorio.cargas, 1);

    sensor.add(
      AccelerometerEvent(22, 15, 9.8, DateTime(2026, 11, 25, 10, 0, 1)),
    );
    // Un cuadro para recibir la lectura y otro para mostrar el aviso
    await tester.pump();
    await tester.pump();
    expect(find.text('Actualizando la lista…'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(repositorio.cargas, 2);
  });
}
