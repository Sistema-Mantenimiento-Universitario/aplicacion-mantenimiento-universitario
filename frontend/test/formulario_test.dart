// Pruebas del formulario para crear y editar incidencias.
// Usan el repositorio simulado
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mantenimiento_universitario/data/incidencias_fake_repository.dart';
import 'package:mantenimiento_universitario/data/incidencias_repository.dart';
import 'package:mantenimiento_universitario/models/categoria.dart';
import 'package:mantenimiento_universitario/models/evidencia.dart';
import 'package:mantenimiento_universitario/models/datos_incidencia.dart';
import 'package:mantenimiento_universitario/models/incidencia.dart';
import 'package:mantenimiento_universitario/models/usuario.dart';
import 'package:mantenimiento_universitario/pages/formulario_incidencia_page.dart';
import 'package:mantenimiento_universitario/services/servicio_imagenes.dart';
import 'package:mantenimiento_universitario/services/servicio_ubicacion.dart';
import 'package:mantenimiento_universitario/theme/app_theme.dart';

const _ana = Usuario(
  id: 1,
  nombre: 'Ana López',
  correo: 'ana@correo.com',
  rol: Rol.usuario,
);

// Repositorio simulado que cuenta los envíos y puede fallar a propósito
class _RepositorioPrueba extends FakeIncidenciasRepository {
  _RepositorioPrueba({
    this.errorAlGuardar,
    this.errorCategorias,
    this.errorAlSubir,
  }) : super(idUsuario: 1, esOperador: false, demora: Duration.zero);

  final ApiException? errorAlGuardar;
  final ApiException? errorCategorias;
  final ApiException? errorAlSubir;
  int envios = 0;
  int fotosSubidas = 0;

  @override
  Future<List<Evidencia>> subirEvidencias(
    int id,
    List<FotoSeleccionada> fotos,
  ) async {
    if (errorAlSubir != null) throw errorAlSubir!;
    fotosSubidas += fotos.length;
    return super.subirEvidencias(id, fotos);
  }

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

// GPS simulado que devuelve unas coordenadas fijas o el error indicado
class _UbicacionPrueba extends ServicioUbicacion {
  const _UbicacionPrueba({this.error});
  final String? error;

  @override
  Future<Coordenadas> obtenerUbicacion() async {
    if (error != null) throw UbicacionException(error!);
    return (latitud: 21.9136, longitud: -102.3158);
  }
}

// Imagen PNG de 1x1 pixel
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

// Cámara y galería simuladas
class _ImagenesPrueba extends ServicioImagenes {
  _ImagenesPrueba({this.error});
  final String? error;

  @override
  bool get hayCamara => true;

  @override
  Future<FotoSeleccionada?> tomarFoto() async {
    if (error != null) throw ImagenException(error!);
    return FotoSeleccionada(
      nombre: 'foto.png',
      bytes: _png,
      tipoMime: 'image/png',
    );
  }

  @override
  Future<FotoSeleccionada?> elegirDeGaleria() => tomarFoto();
}

// Abre una pantalla con un botón que lleva al formulario
Future<void> _abrirFormulario(
  WidgetTester tester,
  IncidenciasRepository repositorio, {
  Incidencia? incidencia,
  ValueChanged<Incidencia?>? alRegresar,
  VoidCallback? onSesionExpirada,
  ServicioUbicacion ubicacion = const _UbicacionPrueba(),
  ServicioImagenes? imagenes,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
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
                      servicioUbicacion: ubicacion,
                      servicioImagenes: imagenes ?? _ImagenesPrueba(),
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
    expect(
      find.text('Escribe la ubicación o usa tu ubicación actual'),
      findsOneWidget,
    );
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

  testWidgets('Usar mi ubicación llena las coordenadas', (tester) async {
    Incidencia? guardada;
    await _abrirFormulario(
      tester,
      _RepositorioPrueba(),
      alRegresar: (incidencia) => guardada = incidencia,
    );

    await tester.enterText(_campo('Título'), 'Ventana rota en el aula 305');
    await _elegirCategoria(tester, 'Mobiliario');
    await tester.enterText(
      _campo('Descripción'),
      'El vidrio de la ventana del fondo está estrellado.',
    );
    await tester.tap(find.text('Usar mi ubicación'));
    await tester.pumpAndSettle();

    expect(find.text('21.913600'), findsOneWidget);
    expect(find.text('-102.315800'), findsOneWidget);

    // Con coordenadas, la ubicación en texto ya no es obligatoria
    await tester.tap(find.text('Crear incidencia'));
    await tester.pumpAndSettle();

    expect(guardada?.latitud, 21.9136);
    expect(guardada?.longitud, -102.3158);
    expect(guardada?.ubicacionTexto, isNull);
  });

  testWidgets('Si no hay permiso de ubicación muestra el mensaje', (
    tester,
  ) async {
    await _abrirFormulario(
      tester,
      _RepositorioPrueba(),
      ubicacion: const _UbicacionPrueba(
        error: 'No se dio permiso de ubicación',
      ),
    );

    await tester.tap(find.text('Usar mi ubicación'));
    await tester.pumpAndSettle();

    expect(find.text('No se dio permiso de ubicación'), findsOneWidget);
    // El formulario sigue disponible
    expect(find.text('Crear incidencia'), findsOneWidget);
  });

  testWidgets('Coordenadas a mano: pide las dos y revisa el rango', (
    tester,
  ) async {
    final repositorio = _RepositorioPrueba();
    await _abrirFormulario(tester, repositorio);

    await _llenarFormulario(tester);
    await tester.enterText(_campo('Latitud'), '95');
    await tester.tap(find.text('Crear incidencia'));
    await tester.pumpAndSettle();

    expect(find.text('Debe estar entre -90 y 90'), findsOneWidget);
    expect(find.text('Escribe también la longitud'), findsOneWidget);
    expect(repositorio.envios, 0);
  });

  testWidgets('Fotos: se agregan, se quitan y se suben al guardar', (
    tester,
  ) async {
    final repositorio = _RepositorioPrueba();
    await _abrirFormulario(tester, repositorio);

    await tester.tap(find.text('Tomar foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Galería'));
    await tester.pumpAndSettle();
    expect(find.text('Fotos (opcional) · 2 de 5'), findsOneWidget);

    await tester.tap(find.byTooltip('Quitar foto').first);
    await tester.pumpAndSettle();
    expect(find.text('Fotos (opcional) · 1 de 5'), findsOneWidget);

    await _llenarFormulario(tester);
    await tester.tap(find.text('Crear incidencia'));
    await tester.pumpAndSettle();

    expect(repositorio.fotosSubidas, 1);
    expect(find.text('Incidencia creada'), findsOneWidget);
  });

  testWidgets('Al tocar una foto se abre en grande con animación', (
    tester,
  ) async {
    await _abrirFormulario(tester, _RepositorioPrueba());

    await tester.tap(find.text('Tomar foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ver foto'));
    // A media animación la foto va "volando" (Hero)
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(Hero), findsWidgets);
    await tester.pumpAndSettle();

    expect(find.text('Vista previa'), findsOneWidget);

    // Al cerrar regresa al formulario con la foto
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.text('Fotos (opcional) · 1 de 5'), findsOneWidget);
  });

  testWidgets('Si la foto no es válida muestra el motivo', (tester) async {
    await _abrirFormulario(
      tester,
      _RepositorioPrueba(),
      imagenes: _ImagenesPrueba(
        error: 'Solo se permiten imágenes JPG, PNG o WEBP',
      ),
    );

    await tester.tap(find.text('Tomar foto'));
    await tester.pumpAndSettle();

    expect(
      find.text('Solo se permiten imágenes JPG, PNG o WEBP'),
      findsOneWidget,
    );
    expect(find.text('Fotos (opcional) · 0 de 5'), findsOneWidget);
  });

  testWidgets('Si fallan las fotos, la incidencia se guarda y avisa', (
    tester,
  ) async {
    Incidencia? guardada;
    final repositorio = _RepositorioPrueba(
      errorAlSubir: ApiException('El servidor no encontró las evidencias'),
    );
    await _abrirFormulario(
      tester,
      repositorio,
      alRegresar: (incidencia) => guardada = incidencia,
    );

    await tester.tap(find.text('Tomar foto'));
    await tester.pumpAndSettle();
    await _llenarFormulario(tester);
    await tester.tap(find.text('Crear incidencia'));
    await tester.pumpAndSettle();

    expect(guardada, isNotNull);
    expect(
      find.textContaining('pero no se pudieron subir las fotos'),
      findsOneWidget,
    );
  });

  testWidgets('Editar conserva las coordenadas de la incidencia', (
    tester,
  ) async {
    final repositorio = _RepositorioPrueba();
    final lampara = (await repositorio.obtenerIncidencias()).firstWhere(
      (i) => i.titulo.startsWith('Lámpara fundida'),
    );
    final completa = await repositorio.obtenerIncidencia(lampara.id);
    Incidencia? guardada;
    await _abrirFormulario(
      tester,
      repositorio,
      incidencia: completa,
      alRegresar: (incidencia) => guardada = incidencia,
    );

    expect(find.text('21.913600'), findsOneWidget);

    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    expect(guardada?.latitud, 21.9136);
    expect(guardada?.longitud, -102.3158);
  });
}
