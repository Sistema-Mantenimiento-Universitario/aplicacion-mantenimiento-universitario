-- Sistema de mantenimiento universitario
-- Motor: MySQL 8.0.16 o superior (las restricciones CHECK se aplican desde esa versión)

CREATE DATABASE IF NOT EXISTS mantenimiento_universitario
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE mantenimiento_universitario;

CREATE TABLE usuarios (
    id_usuario      INT          NOT NULL AUTO_INCREMENT,
    nombre          VARCHAR(100) NOT NULL,
    correo          VARCHAR(150) NOT NULL,
    password_hash   VARCHAR(255) NOT NULL,
    rol             VARCHAR(20)  NOT NULL DEFAULT 'usuario',
    activo          TINYINT(1)   NOT NULL DEFAULT 1,
    fecha_creacion  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_usuarios PRIMARY KEY (id_usuario),
    CONSTRAINT uq_usuarios_correo UNIQUE (correo),
    CONSTRAINT ck_usuarios_rol CHECK (rol IN ('usuario', 'operador'))
) ENGINE=InnoDB;

CREATE TABLE categorias (
    id_categoria  INT          NOT NULL AUTO_INCREMENT,
    nombre        VARCHAR(80)  NOT NULL,
    descripcion   VARCHAR(255) NULL,
    activa        TINYINT(1)   NOT NULL DEFAULT 1,
    CONSTRAINT pk_categorias PRIMARY KEY (id_categoria),
    CONSTRAINT uq_categorias_nombre UNIQUE (nombre)
) ENGINE=InnoDB;

CREATE TABLE incidencias (
    id_incidencia         INT           NOT NULL AUTO_INCREMENT,
    titulo                VARCHAR(150)  NOT NULL,
    descripcion           TEXT          NOT NULL,
    id_usuario            INT           NOT NULL,
    id_categoria          INT           NOT NULL,
    id_operador           INT           NULL,
    estado                VARCHAR(20)   NOT NULL DEFAULT 'pendiente',
    ubicacion_texto       VARCHAR(200)  NULL,
    latitud               DECIMAL(9,6)  NULL,
    longitud              DECIMAL(9,6)  NULL,
    solucion_descripcion  TEXT          NULL,
    fecha_creacion        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                                        ON UPDATE CURRENT_TIMESTAMP,
    fecha_finalizacion    DATETIME      NULL,
    CONSTRAINT pk_incidencias PRIMARY KEY (id_incidencia),
    CONSTRAINT fk_incidencias_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuarios (id_usuario)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_incidencias_categoria
        FOREIGN KEY (id_categoria) REFERENCES categorias (id_categoria)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_incidencias_operador
        FOREIGN KEY (id_operador) REFERENCES usuarios (id_usuario)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_incidencias_estado
        CHECK (estado IN ('pendiente', 'asignada', 'en_proceso', 'finalizada', 'cancelada')),
    CONSTRAINT ck_incidencias_latitud
        CHECK (latitud IS NULL OR latitud BETWEEN -90 AND 90),
    CONSTRAINT ck_incidencias_longitud
        CHECK (longitud IS NULL OR longitud BETWEEN -180 AND 180),
    -- Asignada, en proceso o finalizada requieren operador responsable
    CONSTRAINT ck_incidencias_operador_asignado
        CHECK (estado IN ('pendiente', 'cancelada') OR id_operador IS NOT NULL),
    -- Regla del sistema: no finalizar sin descripción de la solución aplicada
    CONSTRAINT ck_incidencias_finalizada
        CHECK (
            estado <> 'finalizada'
            OR (
                solucion_descripcion IS NOT NULL
                AND CHAR_LENGTH(TRIM(solucion_descripcion)) > 0
                AND fecha_finalizacion IS NOT NULL
            )
        )
) ENGINE=InnoDB;

CREATE TABLE evidencias (
    id_evidencia     INT          NOT NULL AUTO_INCREMENT,
    id_incidencia    INT          NOT NULL,
    id_usuario       INT          NOT NULL,
    tipo             VARCHAR(20)  NOT NULL DEFAULT 'reporte',
    ruta_archivo     VARCHAR(255) NOT NULL,
    nombre_original  VARCHAR(255) NULL,
    mime_type        VARCHAR(100) NULL,
    fecha_subida     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_evidencias PRIMARY KEY (id_evidencia),
    CONSTRAINT fk_evidencias_incidencia
        FOREIGN KEY (id_incidencia) REFERENCES incidencias (id_incidencia)
        ON DELETE CASCADE ON UPDATE RESTRICT,
    CONSTRAINT fk_evidencias_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuarios (id_usuario)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_evidencias_tipo CHECK (tipo IN ('reporte', 'atencion'))
) ENGINE=InnoDB;

CREATE TABLE historial (
    id_historial     INT          NOT NULL AUTO_INCREMENT,
    id_incidencia    INT          NOT NULL,
    id_usuario       INT          NOT NULL,
    accion           VARCHAR(30)  NOT NULL,
    estado_anterior  VARCHAR(20)  NULL,
    estado_nuevo     VARCHAR(20)  NULL,
    comentario       TEXT         NULL,
    fecha            DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_historial PRIMARY KEY (id_historial),
    CONSTRAINT fk_historial_incidencia
        FOREIGN KEY (id_incidencia) REFERENCES incidencias (id_incidencia)
        ON DELETE CASCADE ON UPDATE RESTRICT,
    CONSTRAINT fk_historial_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuarios (id_usuario)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_historial_accion
        CHECK (accion IN ('creacion', 'edicion', 'cambio_estado')),
    CONSTRAINT ck_historial_estado_anterior
        CHECK (estado_anterior IS NULL
               OR estado_anterior IN ('pendiente', 'asignada', 'en_proceso', 'finalizada', 'cancelada')),
    CONSTRAINT ck_historial_estado_nuevo
        CHECK (estado_nuevo IS NULL
               OR estado_nuevo IN ('pendiente', 'asignada', 'en_proceso', 'finalizada', 'cancelada'))
) ENGINE=InnoDB;

-- Índices para búsquedas y filtros frecuentes
-- (MySQL ya crea índices automáticos sobre las llaves foráneas)
CREATE INDEX idx_incidencias_estado ON incidencias (estado);
CREATE INDEX idx_incidencias_fecha  ON incidencias (fecha_creacion);
