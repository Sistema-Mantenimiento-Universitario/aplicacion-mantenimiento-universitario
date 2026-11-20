// Pruebas de la F9 · Detalle de incidencia.
// Usan el repositorio simulado.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mantenimiento_universitario/data/incidencias_fake_repository.dart';
import 'package:mantenimiento_universitario/models/usuario.dart';
import 'package:mantenimiento_universitario/pages/detalle_incidencia_page.dart';
import 'package:mantenimiento_universitario/pages/rutas.dart';
import 'package:mantenimiento_universitario/theme/app_theme.dart';

const _ana = Usuario(
  id: 1,
  nombre: 'Ana López',
  correo: 'ana@correo.com',
  rol: Rol.usuario,
);

const _luis = Usuario(
  id: 2,
  nombre: 'Luis Pérez',
  correo: 'luis@correo.com',
  rol: Rol.operador,
);

// Incidencias del repositorio simulado
const _pendienteDeAna = 1; // con coordenadas, sin evidencias
const _asignadaConFotos = 2; // 2 evidencias
const _paraCancelar = 5; // pendiente de Ana
const _canceladaDeBeatriz = 7;

Future<void> _abrirDetalle(
  WidgetTester tester,
  Usuario usuario,
  int id, {
  bool esperar = true,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.claro,
      home: DetalleIncidenciaPage(
        usuario: usuario,
        repositorio: FakeIncidenciasRepository(
          idUsuario: usuario.id,
          esOperador: usuario.esOperador,
          demora: Duration.zero,
        ),
        idIncidencia: id,
      ),
      routes: {
        Rutas.editarIncidencia: (_) =>
            const Scaffold(body: Text('Formulario de edición')),
      },
    ),
  );
  // Con imágenes de red no se usa pumpAndSettle: el indicador de
  // carga de cada imagen podría no terminar en las pruebas
  if (esperar) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('Muestra los datos, el estado actual y la ubicación', (
    tester,
  ) async {
    await _abrirDetalle(tester, _ana, _pendienteDeAna);

    expect(find.text('Lámpara fundida en el pasillo'), findsOneWidget);
    expect(find.text('Estado actual'), findsOneWidget);
    expect(
      find.text('En espera de que un operador la atienda'),
      findsOneWidget,
    );
    expect(find.text('Edificio 3, planta baja'), findsOneWidget);
    expect(find.text('21.913600, -102.315800'), findsOneWidget);
    expect(find.text('Abrir en el mapa'), findsOneWidget);
    expect(find.text('Sin evidencias'), findsOneWidget);
    expect(find.text('Incidencia creada'), findsOneWidget);
  });

  testWidgets('El historial va en orden cronológico', (tester) async {
    await _abrirDetalle(tester, _luis, _canceladaDeBeatriz);

    final creada = tester.getTopLeft(find.text('Incidencia creada')).dy;
    final cambio = tester.getTopLeft(find.text('Cambio de estado')).dy;
    expect(creada, lessThan(cambio));
    expect(find.text('“Reporte duplicado”'), findsOneWidget);
  });

  group('Botones según permisos', () {
    testWidgets('Creador y pendiente: puede editar y cancelar', (tester) async {
      await _abrirDetalle(tester, _ana, _pendienteDeAna);

      expect(find.text('Editar'), findsOneWidget);
      expect(find.byTooltip('Editar'), findsOneWidget);
      expect(find.text('Cancelar incidencia'), findsOneWidget);
    });

    testWidgets('Operador: puede cancelar pero no editar', (tester) async {
      await _abrirDetalle(tester, _luis, _pendienteDeAna);

      expect(find.text('Editar'), findsNothing);
      expect(find.byTooltip('Editar'), findsNothing);
      expect(find.text('Cancelar incidencia'), findsOneWidget);
    });

    testWidgets('No pendiente: no hay botones', (tester) async {
      await _abrirDetalle(tester, _luis, _canceladaDeBeatriz);

      expect(find.text('Editar'), findsNothing);
      expect(find.text('Cancelar incidencia'), findsNothing);
    });
  });

  testWidgets('Editar abre el formulario', (tester) async {
    await _abrirDetalle(tester, _ana, _pendienteDeAna);

    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();

    expect(find.text('Formulario de edición'), findsOneWidget);
  });

  testWidgets('Cancelar pide confirmación y cambia el estado', (tester) async {
    await _abrirDetalle(tester, _ana, _paraCancelar);

    await tester.tap(find.text('Cancelar incidencia'));
    await tester.pumpAndSettle();
    expect(find.text('¿Cancelar la incidencia?'), findsOneWidget);

    await tester.tap(find.text('Sí, cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('La incidencia se canceló'), findsOneWidget);
    expect(find.text('Cancelar incidencia'), findsNothing);
    expect(find.text('Incidencia cancelada'), findsOneWidget); // SnackBar
  });

  testWidgets('Galería: al tocar una imagen se abre la vista ampliada', (
    tester,
  ) async {
    await _abrirDetalle(tester, _ana, _asignadaConFotos, esperar: false);

    expect(find.byKey(const ValueKey('evidencia-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('evidencia-2')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('evidencia-2')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('2 de 2 · Reporte'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsWidgets);

    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('2 de 2 · Reporte'), findsNothing);
  });

  testWidgets('Si la incidencia no existe muestra el error', (tester) async {
    await _abrirDetalle(tester, _ana, 999);

    expect(find.text('Incidencia no encontrada'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('El usuario no puede ver incidencias de otros (403)', (
    tester,
  ) async {
    await _abrirDetalle(tester, _ana, _canceladaDeBeatriz);

    expect(
      find.text('No tienes permiso para realizar esta acción'),
      findsOneWidget,
    );
  });
}
