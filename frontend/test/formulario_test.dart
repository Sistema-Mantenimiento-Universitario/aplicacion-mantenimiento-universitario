// Pruebas del formulario para crear y editar incidencias.
// Usan el repositorio simulado
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mantenimiento_universitario/data/incidencias_fake_repository.dart';
import 'package:mantenimiento_universitario/data/incidencias_repository.dart';
import 'package:mantenimiento_universitario/models/categoria.dart';
import 'package:mantenimiento_universitario/models/datos_incidencia.dart';
import 'package:mantenimiento_universitario/models/incidencia.dart';
import 'package:mantenimiento_universitario/models/usuario.dart';
import 'package:mantenimiento_universitario/pages/formulario_incidencia_page.dart';
import 'package:mantenimiento_universitario/theme/app_theme.dart';

const _ana = Usuario(
  id: 1,
  nombre: 'Ana López',
  correo: 'ana@correo.com',
  rol: Rol.usuario,
);

// Repositorio simulado que cuenta los envíos y puede fallar a propósito
class _RepositorioPrueba extends FakeIncidenciasRepository {
  _RepositorioPrueba({this.errorAlGuardar, this.errorCategorias})
    : super(idUsuario: 1, esOperador: false, demora: Duration.zero);

  final ApiException? errorAlGuardar;
  final ApiException? errorCategorias;
  int envios = 0;

  @override
  Future<List<Categoria>> obtenerCategorias() async {
    if (errorCategorias != null) throw errorCategorias!;
    return super.obtenerCategorias();
  }

  @override
  Future<Incidencia> crearIncidencia(DatosIncidencia datos) async {
    envios++;
    if (errorAlGuardar != null) throw errorAlGuardar!;
    return super.crearIncidencia(datos);
  }

  @override
  Future<Incidencia> editarIncidencia(int id, DatosIncidencia datos) async {
    envios++;
    if (errorAlGuardar != null) throw errorAlGuardar!;
    return super.editarIncidencia(id, datos);
  }
}

// Abre una pantalla con un botón que lleva al formulario
Future<void> _abrirFormulario(
  WidgetTester tester,
  IncidenciasRepository repositorio, {
  Incidencia? incidencia,
  ValueChanged<Incidencia?>? alRegresar,
  VoidCallback? onSesionExpirada,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.claro,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async {
                final guardada = await Navigator.push<Incidencia>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FormularioIncidenciaPage(
                      usuario: _ana,
                      repositorio: repositorio,
                      incidencia: incidencia,
                      onSesionExpirada: onSesionExpirada,
                    ),
                  ),
                );
                alRegresar?.call(guardada);
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

Finder _campo(String etiqueta) => find.widgetWithText(TextFormField, etiqueta);

Future<void> _elegirCategoria(WidgetTester tester, String nombre) async {
  await tester.tap(find.byType(DropdownButtonFormField<int>));
  await tester.pumpAndSettle();
  // .last: el texto también aparece en el campo si ya estaba elegido
  await tester.tap(find.text(nombre).last);
  await tester.pumpAndSettle();
}

Future<void> _llenarFormulario(WidgetTester tester) async {
  await tester.enterText(_campo('Título'), 'Ventana rota en el aula 305');
  await _elegirCategoria(tester, 'Mobiliario');
  await tester.enterText(
    _campo('Descripción'),
    'El vidrio de la ventana del fondo está estrellado.',
  );
  await tester.enterText(_campo('Ubicación'), 'Edificio 2, aula 305');
}

void main() {
  testWidgets('No se envía si faltan datos', (tester) async {
    final repositorio = _RepositorioPrueba();
    await _abrirFormulario(tester, repositorio);

    expect(find.text('Nueva incidencia'), findsOneWidget);

    await tester.tap(find.text('Crear incidencia'));
    await tester.pumpAndSettle();

    expect(find.text('Escribe el título'), findsOneWidget);
    expect(find.text('Elige una categoría'), findsOneWidget);
    expect(find.text('Escribe la descripción'), findsOneWidget);
    expect(find.text('Escribe la ubicación'), findsOneWidget);
    expect(repositorio.envios, 0);
  });

  testWidgets('Avisa que es obligatorio al salir de un campo vacío', (
    tester,
  ) async {
    await _abrirFormulario(tester, _RepositorioPrueba());

    // Entra al título y se pasa a la descripción sin escribir
    await tester.tap(_campo('Título'));
    await tester.pump();
    await tester.tap(_campo('Descripción'));
    await tester.pump();

    expect(find.text('Escribe el título'), findsOneWidget);
    expect(find.text('Escribe la descripción'), findsNothing);
  });

  testWidgets('Avisa el mínimo de caracteres antes de guardar', (tester) async {
    await _abrirFormulario(tester, _RepositorioPrueba());

    await tester.enterText(_campo('Título'), 'Foco');
    await tester.tap(_campo('Descripción'));
    await tester.pump();

    expect(find.text('Debe tener al menos 5 caracteres'), findsOneWidget);

    // Al corregirlo, el error se quita mientras escribe
    await tester.enterText(_campo('Título'), 'Foco fundido');
    await tester.pump();

    expect(find.text('Debe tener al menos 5 caracteres'), findsNothing);
  });

  testWidgets('Valida el mínimo de caracteres', (tester) async {
    final repositorio = _RepositorioPrueba();
    await _abrirFormulario(tester, repositorio);

    await _llenarFormulario(tester);
    await tester.enterText(_campo('Título'), 'Foco');
    await tester.enterText(_campo('Descripción'), 'Se fundió');
    await tester.tap(find.text('Crear incidencia'));
    await tester.pumpAndSettle();

    expect(find.text('Debe tener al menos 5 caracteres'), findsOneWidget);
    expect(find.text('Debe tener al menos 10 caracteres'), findsOneWidget);
    expect(repositorio.envios, 0);
  });

  testWidgets('Crea la incidencia y regresa a la pantalla anterior', (
    tester,
  ) async {
    final repositorio = _RepositorioPrueba();
    Incidencia? guardada;
    await _abrirFormulario(
      tester,
      repositorio,
      alRegresar: (incidencia) => guardada = incidencia,
    );

    await _llenarFormulario(tester);
    await tester.tap(find.text('Crear incidencia'));
    await tester.pumpAndSettle();

    expect(repositorio.envios, 1);
    expect(find.text('Incidencia creada'), findsOneWidget);
    // Regresó a la pantalla anterior con la incidencia nueva
    expect(find.text('Abrir'), findsOneWidget);
    expect(guardada?.titulo, 'Ventana rota en el aula 305');
    expect(guardada?.categoria.nombre, 'Mobiliario');
  });

  testWidgets('Editar: carga los datos y guarda los cambios', (tester) async {
    final repositorio = _RepositorioPrueba();
    final lampara = (await repositorio.obtenerIncidencias()).firstWhere(
      (i) => i.titulo == 'Lámpara fundida en el pasillo',
    );
    Incidencia? guardada;
    await _abrirFormulario(
      tester,
      repositorio,
      incidencia: lampara,
      alRegresar: (incidencia) => guardada = incidencia,
    );

    expect(find.text('Editar incidencia'), findsOneWidget);
    expect(find.text('Lámpara fundida en el pasillo'), findsOneWidget);
    expect(find.text('Electricidad'), findsOneWidget);

    await tester.enterText(
      _campo('Título'),
      'Lámpara fundida en el edificio 3',
    );
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    expect(find.text('Cambios guardados'), findsOneWidget);
    expect(guardada?.id, lampara.id);
    expect(guardada?.titulo, 'Lámpara fundida en el edificio 3');
  });

  testWidgets('Editar: no se permite si la incidencia no está pendiente', (
    tester,
  ) async {
    final repositorio = _RepositorioPrueba();
    final silla = (await repositorio.obtenerIncidencias()).firstWhere(
      (i) => i.titulo == 'Silla rota en el aula 204',
    );
    await _abrirFormulario(tester, repositorio, incidencia: silla);

    expect(
      find.text('Solo puedes editar incidencias pendientes que tú reportaste'),
      findsOneWidget,
    );
    expect(find.text('Guardar cambios'), findsNothing);
  });

  testWidgets('Muestra los errores del backend debajo del campo', (
    tester,
  ) async {
    final repositorio = _RepositorioPrueba(
      errorAlGuardar: ApiException(
        'Datos inválidos',
        statusCode: 400,
        errores: {'titulo': 'Ya reportaste una incidencia con ese título'},
      ),
    );
    await _abrirFormulario(tester, repositorio);

    await _llenarFormulario(tester);
    await tester.tap(find.text('Crear incidencia'));
    await tester.pumpAndSettle();

    expect(
      find.text('Ya reportaste una incidencia con ese título'),
      findsOneWidget,
    );
    expect(find.text('Datos inválidos'), findsOneWidget);
    // Sigue en el formulario
    expect(find.text('Crear incidencia'), findsOneWidget);

    // Al corregir el campo, el error del backend desaparece
    await tester.enterText(_campo('Título'), 'Ventana rota en el aula 306');
    await tester.pumpAndSettle();
    expect(
      find.text('Ya reportaste una incidencia con ese título'),
      findsNothing,
    );
  });

  testWidgets('Si la sesión expiró (401) avisa para cerrar la sesión', (
    tester,
  ) async {
    var cerrada = false;
    final repositorio = _RepositorioPrueba(
      errorAlGuardar: ApiException('Sesión expirada', statusCode: 401),
    );
    await _abrirFormulario(
      tester,
      repositorio,
      onSesionExpirada: () => cerrada = true,
    );

    await _llenarFormulario(tester);
    await tester.tap(find.text('Crear incidencia'));
    await tester.pumpAndSettle();

    expect(cerrada, isTrue);
  });

  testWidgets('Si no cargan las categorías muestra Reintentar', (tester) async {
    final repositorio = _RepositorioPrueba(
      errorCategorias: ApiException('No se pudo conectar con el servidor'),
    );
    await _abrirFormulario(tester, repositorio);

    expect(find.text('No se pudo conectar con el servidor'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
