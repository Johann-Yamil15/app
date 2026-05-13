-- QUERY TRUNCATED
-- =====================================================
-- SCRIPT COMPLETO: SISTEMA SAI - POSTGRESQL 17
-- Migración completa desde SQL Server -> PostgreSQL
-- Compatible PostgreSQL 17+
-- =====================================================

-- =====================================================
-- FASE 0: CREACIÓN DB (ejecutar separado si estás en psql)
-- =====================================================
-- CREATE DATABASE sai;
-- \c sai;

-- =====================================================
-- FASE 1: LIMPIEZA
-- =====================================================

DROP VIEW IF EXISTS vw_proveedores_tendencia_negativa CASCADE;
DROP VIEW IF EXISTS vw_proveedores_riesgo_critico CASCADE;
DROP VIEW IF EXISTS vw_consolidado_cxp CASCADE;

DROP FUNCTION IF EXISTS sp_actualizarhistorialdesempeno();
DROP FUNCTION IF EXISTS sp_registrarincidencia(
    INT,
    VARCHAR,
    VARCHAR,
    VARCHAR,
    NUMERIC
);

DROP TABLE IF EXISTS incidencias_proveedor CASCADE;
DROP TABLE IF EXISTS historico_desempeno CASCADE;
DROP TABLE IF EXISTS config_scoring CASCADE;
DROP TABLE IF EXISTS historico_pagos CASCADE;
DROP TABLE IF EXISTS movimientos_cxp CASCADE;
DROP TABLE IF EXISTS cat_proveedores CASCADE;

-- =====================================================
-- FASE 2: TABLAS BASE
-- =====================================================

CREATE TABLE cat_proveedores (
    id_proveedor              SERIAL PRIMARY KEY,
    nombre_comercial          VARCHAR(100) NOT NULL,
    categoria                 VARCHAR(50),

    criticidad_operativa      VARCHAR(20) DEFAULT 'Media',
    riesgo_operativo          VARCHAR(20) DEFAULT 'Medio',

    condicion_pago            VARCHAR(20) DEFAULT 'Crédito',
    dias_credito_autorizado   INT DEFAULT 30,

    sustituibilidad           VARCHAR(20) DEFAULT 'Media',

    origen_seleccion          VARCHAR(50) DEFAULT 'Comparativa',

    acepta_pago_parcial       BOOLEAN DEFAULT FALSE,
    es_proveedor_estrategico  BOOLEAN DEFAULT FALSE,

    fecha_alta_proveedor      DATE DEFAULT CURRENT_DATE,

    categoria_compra          VARCHAR(50) DEFAULT 'General',

    nombre_contacto           VARCHAR(100) DEFAULT '',
    telefono_contacto         VARCHAR(20) DEFAULT ''
);

-- =====================================================

CREATE TABLE movimientos_cxp (
    id_movimiento                   SERIAL PRIMARY KEY,

    id_proveedor                    INT NOT NULL,

    descripcion_servicio            VARCHAR(100),

    monto_pendiente                 NUMERIC(18,2) NOT NULL,

    moneda                          CHAR(3) DEFAULT 'MXN',

    fecha_factura                   DATE,
    fecha_vencimiento               DATE,

    dias_vencidos_manual            INT DEFAULT 0,

    expediente_completo             BOOLEAN DEFAULT TRUE,

    documentos_faltantes            VARCHAR(200) DEFAULT '',

    orden_compra_valida             BOOLEAN DEFAULT TRUE,

    riesgo_legal_presion            BOOLEAN DEFAULT FALSE,

    criticidad_ref                  VARCHAR(20),

    es_proveedor_estrategico_ref    BOOLEAN DEFAULT FALSE,

    riesgo_operativo_ref            VARCHAR(20),

    riesgo_paro_operativo           BOOLEAN DEFAULT FALSE,

    retrabajos                      INT DEFAULT 0,

    notas_operacion                 VARCHAR(500) DEFAULT '',

    presupuesto_referencia          NUMERIC(18,2) DEFAULT 500000,

    prioridad_sugerida              VARCHAR(20) DEFAULT 'Media',

    accion_recomendada              VARCHAR(20) DEFAULT 'Programar',

    fecha_recepcion_real            DATE,

    fecha_expediente_completo       DATE,

    fecha_primer_contacto_proveedor DATE,

    canal_presion                   VARCHAR(50),

    nivel_escalamiento              VARCHAR(20),

    fecha_pago_realizado            DATE,

    CONSTRAINT fk_mov_proveedor
        FOREIGN KEY (id_proveedor)
        REFERENCES cat_proveedores(id_proveedor)
);

-- =====================================================

CREATE TABLE historico_desempeno (
    id_historico                    SERIAL PRIMARY KEY,

    id_proveedor                    INT NOT NULL,

    fecha_corte                     DATE DEFAULT CURRENT_DATE,

    promedio_dias_vencidos          NUMERIC(10,2) DEFAULT 0.00,

    total_documentos_procesados     INT DEFAULT 0,

    documentos_rechazados           INT DEFAULT 0,

    historial_rechazos              INT DEFAULT 0,

    tasa_expediente_completo        NUMERIC(5,2) DEFAULT 100.00,

    promedio_dias_retrabajo         NUMERIC(10,2) DEFAULT 0.00,

    monto_promedio_mensual          NUMERIC(18,2) DEFAULT 0.00,

    frecuencia_pagos_mes            INT DEFAULT 0,

    puntualidad_score               NUMERIC(5,2) DEFAULT 100.00,

    CONSTRAINT fk_hist_proveedor
        FOREIGN KEY (id_proveedor)
        REFERENCES cat_proveedores(id_proveedor)
);

-- =====================================================

CREATE TABLE incidencias_proveedor (
    id_incidencia       SERIAL PRIMARY KEY,

    id_proveedor        INT NOT NULL,

    fecha_incidencia    DATE DEFAULT CURRENT_DATE,

    tipo_incidencia     VARCHAR(50) NOT NULL,

    gravedad            VARCHAR(20) NOT NULL,

    descripcion         VARCHAR(500),

    costo_incidencia    NUMERIC(18,2) DEFAULT 0.00,

    resuelta            BOOLEAN DEFAULT FALSE,

    fecha_resolucion    DATE,

    CONSTRAINT fk_incidencia_proveedor
        FOREIGN KEY (id_proveedor)
        REFERENCES cat_proveedores(id_proveedor)
);

-- =====================================================

CREATE TABLE config_scoring (
    id_config             SERIAL PRIMARY KEY,

    parametro             VARCHAR(100) UNIQUE NOT NULL,

    valor_peso            NUMERIC(10,2) NOT NULL,

    descripcion           VARCHAR(500),

    activo                BOOLEAN DEFAULT TRUE,

    fecha_actualizacion   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================

CREATE TABLE historico_pagos (
    id                    SERIAL PRIMARY KEY,

    id_proveedor          INT,

    fecha_pago            DATE,

    dias_vencidos         INT,

    monto_pagado          NUMERIC(12,2),

    expediente_completo   BOOLEAN,

    CONSTRAINT fk_pago_proveedor
        FOREIGN KEY (id_proveedor)
        REFERENCES cat_proveedores(id_proveedor)
);

-- =====================================================
-- FASE 3: CONFIGURACIÓN SCORING
-- =====================================================

INSERT INTO config_scoring
(parametro, valor_peso, descripcion)
VALUES

('peso_criticidad_operativa',    40.00, 'Impacto en producción'),
('peso_riesgo_legal',            50.00, 'Riesgo legal'),
('peso_dias_vencidos',           20.00, 'Peso días vencidos'),
('peso_riesgo_operativo',        10.00, 'Riesgo operativo'),
('peso_proveedor_unico',         30.00, 'Proveedor único'),
('peso_riesgo_paro',             50.00, 'Riesgo paro'),

('malus_retrabajo',             -15.00, 'Penalización retrabajo'),

('bono_contado',                 20.00, 'Pago contado'),

('malus_tendencia_empeorando',   15.00, 'Tendencia empeorando'),

('peso_historial_rechazos',      -5.00, 'Rechazos'),

('peso_puntualidad',             10.00, 'Puntualidad'),

('umbral_proveedor_estrategico', 25.00, 'Proveedor estratégico');

-- =====================================================
-- FASE 4: ÍNDICES RECOMENDADOS
-- =====================================================

CREATE INDEX idx_movimientos_proveedor
ON movimientos_cxp(id_proveedor);

CREATE INDEX idx_movimientos_vencimiento
ON movimientos_cxp(fecha_vencimiento);

CREATE INDEX idx_historico_proveedor
ON historico_desempeno(id_proveedor);

CREATE INDEX idx_historico_pagos_proveedor
ON historico_pagos(id_proveedor);

CREATE INDEX idx_incidencias_proveedor
ON incidencias_proveedor(id_proveedor);

-- =====================================================
-- FASE 5: VISTA CONSOLIDADA PRINCIPAL
-- =====================================================

CREATE OR REPLACE VIEW vw_consolidado_cxp AS

WITH historico AS (

    SELECT
        id_proveedor,
        promedio_dias_vencidos,
        historial_rechazos,
        tasa_expediente_completo,
        puntualidad_score,
        monto_promedio_mensual,

        ROW_NUMBER() OVER (
            PARTITION BY id_proveedor
            ORDER BY fecha_corte DESC
        ) AS rn

    FROM historico_desempeno
),

historicogauss AS (

    SELECT
        id_proveedor,

        COUNT(*)             AS total_operaciones,

        AVG(dias_vencidos)::NUMERIC(10,2) AS media_dias,

        STDDEV(dias_vencidos)::NUMERIC(10,2) AS std_dias

    FROM historico_pagos

    GROUP BY id_proveedor
),

maxdias AS (

    SELECT
        COALESCE(
            MAX(CURRENT_DATE - fecha_vencimiento),
            1
        ) AS max_dias_vencidos

    FROM movimientos_cxp

    WHERE monto_pendiente > 0
),

configparams AS (

    SELECT
        parametro,
        valor_peso

    FROM config_scoring

    WHERE activo = TRUE
)

SELECT

    -- IDENTIFICACIÓN
    cp.id_proveedor,
      cp.nombre_comercial AS proveedor_nombre,

    cp.nombre_contacto AS contacto,
    cp.telefono_contacto AS telefono,

    -- CATÁLOGO
    cp.categoria,
    cp.criticidad_operativa,
    cp.riesgo_operativo,
    cp.condicion_pago,
    cp.sustituibilidad,
    cp.acepta_pago_parcial,
    cp.es_proveedor_estrategico,

    -- MOVIMIENTO
    m.monto_pendiente,
    m.fecha_factura,
    m.fecha_vencimiento,
    m.expediente_completo,
    m.orden_compra_valida,
    m.documentos_faltantes,
    m.riesgo_legal_presion,
    m.riesgo_paro_operativo,
    m.retrabajos,
    m.notas_operacion,
    m.canal_presion,
    m.nivel_escalamiento,
    m.fecha_recepcion_real,
    m.fecha_expediente_completo,

    -- DÍAS
    (CURRENT_DATE - m.fecha_vencimiento) AS dias_vencidos,

    CASE
        WHEN m.fecha_expediente_completo IS NOT NULL
        THEN CURRENT_DATE - m.fecha_expediente_completo
        ELSE CURRENT_DATE - m.fecha_vencimiento
    END AS dias_vencidos_reales,

    -- HISTÓRICO
    COALESCE(h.promedio_dias_vencidos, 0)
        AS promedio_dias_anterior,

    COALESCE(h.historial_rechazos, 0)
        AS historial_rechazos,

    COALESCE(h.tasa_expediente_completo, 100.0)
        AS tasa_expediente_completo,

    COALESCE(h.puntualidad_score, 100.0)
        AS puntualidad_score,

    COALESCE(h.monto_promedio_mensual, 0.0)
        AS monto_promedio_mensual,

    -- TENDENCIA
    CASE
        WHEN (CURRENT_DATE - m.fecha_vencimiento)
            > (COALESCE(h.promedio_dias_vencidos,0) + 5)
        THEN 1
        ELSE 0
    END AS tendencia_empeorando,

    -- NORMALIZACIÓN
    CASE
        WHEN md.max_dias_vencidos > 0
        THEN (
            ((CURRENT_DATE - m.fecha_vencimiento)::NUMERIC)
            / md.max_dias_vencidos
        ) * 100
        ELSE 0
    END AS dias_vencidos_normalizado,

    -- SCORE PRINCIPAL
    (

        (
            CASE cp.criticidad_operativa
                WHEN 'Crítica' THEN 100
                WHEN 'Alta' THEN 70
                WHEN 'Media' THEN 40
                WHEN 'Baja' THEN 10
                ELSE 40
            END
        )

        * (
            SELECT valor_peso
            FROM configparams
            WHERE parametro = 'peso_criticidad_operativa'
        ) / 100.0

        +

        CASE
            WHEN m.riesgo_legal_presion = TRUE
            THEN (
                SELECT valor_peso
                FROM configparams
                WHERE parametro = 'peso_riesgo_legal'
            )
            ELSE 0
        END

        +

        (
            CASE
                WHEN md.max_dias_vencidos > 0
                THEN (
                    ((CURRENT_DATE - m.fecha_vencimiento)::NUMERIC)
                    / md.max_dias_vencidos
                )
                ELSE 0
            END
        )

        * (
            SELECT valor_peso
            FROM configparams
            WHERE parametro = 'peso_dias_vencidos'
        )

        +

        (
            CASE cp.riesgo_operativo
                WHEN 'Alto' THEN 100
                WHEN 'Medio' THEN 50
                WHEN 'Bajo' THEN 10
                ELSE 50
            END
        )

        * (
            SELECT valor_peso
            FROM configparams
            WHERE parametro = 'peso_riesgo_operativo'
        ) / 100.0

        +

        CASE
            WHEN cp.sustituibilidad = 'Único'
            THEN (
                SELECT valor_peso
                FROM configparams
                WHERE parametro = 'peso_proveedor_unico'
            )
            ELSE 0
        END

        +

        CASE
            WHEN m.riesgo_paro_operativo = TRUE
            THEN (
                SELECT valor_peso
                FROM configparams
                WHERE parametro = 'peso_riesgo_paro'
            )
            ELSE 0
        END

        +

        (
            m.retrabajos
            *
            (
                SELECT valor_peso
                FROM configparams
                WHERE parametro = 'malus_retrabajo'
            )
        )

        +

        CASE
            WHEN cp.condicion_pago = 'Contado'
            THEN (
                SELECT valor_peso
                FROM configparams
                WHERE parametro = 'bono_contado'
            )
            ELSE 0
        END

        +

        CASE
            WHEN (CURRENT_DATE - m.fecha_vencimiento)
                 > (COALESCE(h.promedio_dias_vencidos,0) + 5)

            THEN (
                SELECT valor_peso
                FROM configparams
                WHERE parametro = 'malus_tendencia_empeorando'
            )

            ELSE 0
        END

        +

        (
            COALESCE(h.historial_rechazos,0)
            *
            (
                SELECT valor_peso
                FROM configparams
                WHERE parametro = 'peso_historial_rechazos'
            )
        )

        +

        (
            COALESCE(h.puntualidad_score,100.0) / 100.0
        )

        * (
            SELECT valor_peso
            FROM configparams
            WHERE parametro = 'peso_puntualidad'
        )

        +

        CASE
            WHEN cp.es_proveedor_estrategico = TRUE
            THEN (
                SELECT valor_peso
                FROM configparams
                WHERE parametro = 'umbral_proveedor_estrategico'
            )
            ELSE 0
        END

    ) AS score_prioridad_v2,

    -- APTO PAGO
    CASE
        WHEN m.expediente_completo = TRUE
         AND m.orden_compra_valida = TRUE
        THEN 1
        ELSE 0
    END AS apto_para_pago,

    -- GAUSSIANO
    COALESCE(hg.total_operaciones,0)
        AS total_operaciones,

    hg.media_dias,
    hg.std_dias,

    CASE
        WHEN COALESCE(hg.total_operaciones,0) >= 100
        THEN 1
        ELSE 0
    END AS data_confiable,

    CASE
        WHEN COALESCE(hg.total_operaciones,0) < 30
            THEN 'Muy poca data'

        WHEN COALESCE(hg.total_operaciones,0) < 60
            THEN 'Limitada'

        WHEN COALESCE(hg.total_operaciones,0) < 100
            THEN 'Moderada'

        WHEN COALESCE(hg.total_operaciones,0) < 200
            THEN 'Confiable'

        ELSE 'Alta confiabilidad'
    END AS nivel_confianza_datos,

    -- Z SCORE
    z_calc.z AS z_score_dias,

    ng.nivel_gauss,
    ng.impacto_gauss

FROM movimientos_cxp m

JOIN cat_proveedores cp
    ON cp.id_proveedor = m.id_proveedor

LEFT JOIN historico h
    ON h.id_proveedor = cp.id_proveedor
    AND h.rn = 1

LEFT JOIN historicogauss hg
    ON hg.id_proveedor = cp.id_proveedor

CROSS JOIN maxdias md

CROSS JOIN LATERAL (

    SELECT
        CASE
            WHEN hg.std_dias IS NULL
              OR hg.std_dias = 0

            THEN 0

            ELSE (
                ((CURRENT_DATE - m.fecha_vencimiento)::NUMERIC)
                - hg.media_dias
            )
            / NULLIF(hg.std_dias,0)
        END AS z

) z_calc

CROSS JOIN LATERAL (

    SELECT

        CASE
            WHEN hg.std_dias IS NULL
              OR hg.std_dias = 0
                THEN 'NORMAL'

            WHEN ABS(z_calc.z) > 3
                THEN 'CRÍTICO (99.7%)'

            WHEN ABS(z_calc.z) > 2
                THEN 'ATÍPICO (95%)'

            WHEN ABS(z_calc.z) > 1
                THEN 'ALERTA (68%)'

            ELSE 'NORMAL'
        END AS nivel_gauss,

        CASE
            WHEN hg.std_dias IS NULL
              OR hg.std_dias = 0
                THEN 0

            WHEN ABS(z_calc.z) > 3
                THEN 30

            WHEN ABS(z_calc.z) > 2
                THEN 20

            WHEN ABS(z_calc.z) > 1
                THEN 10

            ELSE 0
        END AS impacto_gauss

) ng

WHERE m.monto_pendiente > 0;