// Imagen asociada a una incidencia (docs/api.md -> Evidencias)
class Evidencia {
  const Evidencia({
    required this.id,
    required this.tipo,
    required this.url,
    required this.fechaSubida,
    this.nombreOriginal,
  });

  final int id;

  /// 'reporte' (la subió quien reportó) o 'atencion' (la subió el operador)
  final String tipo;

  /// URL completa, lista para Image.network
  final String url;
  final String? nombreOriginal;

  // En hora local (la API la manda en UTC)
  final DateTime fechaSubida;

  bool get esDeAtencion => tipo == 'atencion';

  String get etiquetaTipo => esDeAtencion ? 'Atención' : 'Reporte';

  /// La API manda `url` relativa al servidor (p. ej. /uploads/evidencias/x.jpg).
  /// [servidor] es el host sin /api, p. ej. 'http://localhost:3000'.
  factory Evidencia.fromJson(
    Map<String, dynamic> json, {
    required String servidor,
  }) {
    final url = json['url'] as String;
    return Evidencia(
      id: (json['id_evidencia'] as num).toInt(),
      tipo: (json['tipo'] ?? 'reporte') as String,
      url: url.startsWith('http') ? url : '$servidor$url',
      nombreOriginal: json['nombre_original'] as String?,
      fechaSubida: DateTime.parse(json['fecha_subida'] as String).toLocal(),
    );
  }
}
