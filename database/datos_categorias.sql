-- Categorías de ejemplo. Ejecutar después de schema.sql.

USE mantenimiento_universitario;

INSERT INTO categorias (nombre, descripcion) VALUES
    ('Electricidad',   'Fallas eléctricas, iluminación y contactos'),
    ('Plomería',       'Fugas, drenajes y sanitarios'),
    ('Mobiliario',     'Sillas, mesas, pizarrones y puertas'),
    ('Climatización',  'Aire acondicionado y ventilación'),
    ('Limpieza',       'Aseo de aulas, baños y áreas comunes'),
    ('Otros',          'Cualquier otra falla de las instalaciones');
