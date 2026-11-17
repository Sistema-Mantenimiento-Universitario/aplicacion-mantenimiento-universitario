// Pruebas del Listado de incidencias.
// Usan el repositorio simulado
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mantenimiento_universitario/data/incidencias_fake_repository.dart';
import 'package:mantenimiento_universitario/data/incidencias_repository.dart';
import 'package:mantenimiento_universitario/models/categoria.dart';
import 'package:mantenimiento_universitario/models/estado_incidencia.dart';
import 'package:mantenimiento_universitario/models/incidencia.dart';
import 'package:mantenimiento_universitario/models/usuario.dart';
import 'package:mantenimiento_universitario/pages/listado_incidencias_page.dart';
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

// Tamaños de pantalla (altos para que toda la lista quede visible).
const _computadora = Size(1080, 2400);
const _celular = Size(400, 1600);

/// Repositorio que responde con el error indicado.
class _RepositorioConError implements IncidenciasRepository {
  _RepositorioConError(this.error);
  final ApiException error;

  @override
  Future<Map<String, int>> obtenerResumenPorEstado() async => throw error;

  @override
  Future<List<Incidencia>> obtenerIncidencias({
    String? texto,
    EstadoIncidencia? estado,
    int? idCategoria,
  }) async => throw error;

  @override
  Future<List<Categoria>> obtenerCategorias() async => throw error;
}

Future<void> _abrirListado(
  WidgetTester tester,
  Usuario usuario, {
  IncidenciasRepository? repositorio,
  VoidCallback? onSesionExpirada,
  Size tamano = _computadora,
}) async {
  // Pantalla alta para que toda la lista quede visible.
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.claro,
      home: ListadoIncidenciasPage(
        usuario: usuario,
        repositorio:
            repositorio ??
            FakeIncidenciasRepository(
              idUsuario: usuario.id,
              esOperador: usuario.esOperador,
              demora: Duration.zero,
            ),
        onSesionExpirada: onSesionExpirada,
      ),
      routes: {
        Rutas.detalleIncidencia: (context) => Scaffold(
          body: Text('Detalle ${ModalRoute.of(context)!.settings.arguments}'),
        ),
      },
    ),
  );
  await tester.pumpAndSettle();
}

/// Cuántas incidencias hay en la lista
int _cantidad(WidgetTester tester) =>
    tester.widgetList(find.byType(Card)).length;

/// Una opción del panel de filtros de la vista web
Finder _enPanel(String texto) => find.descendant(
  of: find.byKey(const ValueKey('panel-filtros')),
  matching: find.text(texto),
);

void main() {
  testWidgets('El usuario ve solo sus incidencias', (tester) async {
    await _abrirListado(tester, _ana);

    expect(find.text('Mis incidencias'), findsOneWidget);
    expect(_cantidad(tester), 5);
    expect(find.text('Lámpara fundida en el pasillo'), findsOneWidget);
    // Es de Beatriz, así que Ana no la ve.
    expect(find.text('Proyector sin imagen'), findsNothing);
    // Categoría y fecha en cada elemento.
        expect(find.text('Electricidad   12/11/2026 09:15'), findsOneWidget);
  });

  testWidgets('El operador ve todas y quién las reportó', (tester) async {
    await _abrirListado(tester, _luis);

    expect(find.text('Incidencias'), findsOneWidget);
    expect(_cantidad(tester), 7);
    expect(find.text('Reportó: Beatriz Gómez'), findsNWidgets(2));
  });

  testWidgets('Web: filtra por estado desde el panel lateral', (tester) async {
    await _abrirListado(tester, _ana);

    await tester.tap(_enPanel('Pendiente'));
    await tester.pumpAndSettle();

    expect(_cantidad(tester), 2);
    expect(find.text('Silla rota en el aula 204'), findsNothing);
  });

  testWidgets('Web: filtra por categoría desde el panel lateral', (
    tester,
  ) async {
    await _abrirListado(tester, _ana);

    await tester.tap(_enPanel('Plomería'));
    await tester.pumpAndSettle();

    expect(_cantidad(tester), 1);
    expect(find.text('Fuga de agua en el baño'), findsOneWidget);
  });

  testWidgets('Web: el filtro aplicado se quita con su X', (tester) async {
    await _abrirListado(tester, _ana);

    await tester.tap(_enPanel('Pendiente'));
    await tester.pumpAndSettle();
    expect(_cantidad(tester), 2);

    // X del chip del filtro aplicado, arriba de los resultados.
    await tester.tap(find.byTooltip('Quitar filtro'));
    await tester.pumpAndSettle();

    expect(_cantidad(tester), 5);
  });

  testWidgets('Celular: los filtros se abren con el botón Filtros', (
    tester,
  ) async {
    await _abrirListado(tester, _ana, tamano: _celular);

    // En celular no se ve el panel lateral.
    expect(find.byKey(const ValueKey('panel-filtros')), findsNothing);

    await tester.tap(find.text('Filtros'));
    await tester.pumpAndSettle();

    // Se pueden elegir un estado y una categoría a la vez.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Pendiente'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Electricidad'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver resultados'));
    await tester.pumpAndSettle();

    expect(_cantidad(tester), 1);
    expect(find.text('Lámpara fundida en el pasillo'), findsOneWidget);
    // El botón muestra cuántos filtros hay activos.
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.text('Limpiar filtros'));
    await tester.pumpAndSettle();

    expect(_cantidad(tester), 5);
  });

  testWidgets('Celular: cerrar la hoja sin aplicar no cambia nada', (
    tester,
  ) async {
    await _abrirListado(tester, _ana, tamano: _celular);

    await tester.tap(find.text('Filtros'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Pendiente'));
    await tester.pumpAndSettle();
    // Toca fuera de la hoja para cerrarla.
    await tester.tapAt(const Offset(200, 20));
    await tester.pumpAndSettle();

    expect(_cantidad(tester), 5);
  });
  testWidgets('Busca por texto en título y descripción', (tester) async {
    await _abrirListado(tester, _ana);

    await tester.enterText(find.byType(TextField), 'lavabo');
    // Espera a que termine el tiempo de espera del buscador.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(_cantidad(tester), 1);
    expect(find.text('Fuga de agua en el baño'), findsOneWidget);
  });

  testWidgets('Sin resultados muestra un mensaje y permite quitar filtros', (
    tester,
  ) async {
    await _abrirListado(tester, _ana);

    await tester.enterText(find.byType(TextField), 'no existe');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('No hay incidencias con esos filtros'), findsOneWidget);

    await tester.tap(find.text('Limpiar filtros').first);
    await tester.pumpAndSettle();

    expect(_cantidad(tester), 5);
  });

  testWidgets('Con error muestra el mensaje y Reintentar', (tester) async {
    await _abrirListado(
      tester,
      _ana,
      repositorio: _RepositorioConError(
        ApiException('No se pudo conectar con el servidor'),
      ),
    );

    expect(find.text('No se pudo conectar con el servidor'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('Si la sesión expiró (401) avisa para cerrar la sesión', (
    tester,
  ) async {
    var cerrada = false;
    await _abrirListado(
      tester,
      _ana,
      repositorio: _RepositorioConError(
        ApiException('Sesión expirada', statusCode: 401),
      ),
      onSesionExpirada: () => cerrada = true,
    );

    expect(cerrada, isTrue);
  });

  testWidgets('Al tocar una incidencia abre su detalle', (tester) async {
    await _abrirListado(tester, _ana);

    await tester.tap(find.text('Lámpara fundida en el pasillo'));
    await tester.pumpAndSettle();

    expect(find.text('Detalle 1'), findsOneWidget);
  });
}
