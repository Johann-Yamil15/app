-- =====================================================
-- SCRIPT COMPLETO: SISTEMA SAI - SETUP DESDE CERO
-- Ejecutar en orden. Compatible SQL Server 2016+
-- =====================================================
CREATE DATABASE SAI;
GO

USE SAI;
GO

-- =====================================================
-- FASE 0: LIMPIEZA (si ya existen objetos previos)
-- =====================================================
IF OBJECT_ID('vw_Proveedores_Tendencia_Negativa', 'V') IS NOT NULL DROP VIEW vw_Proveedores_Tendencia_Negativa;
IF OBJECT_ID('vw_Proveedores_Riesgo_Critico',     'V') IS NOT NULL DROP VIEW vw_Proveedores_Riesgo_Critico;
IF OBJECT_ID('vw_Consolidado_CxP',                'V') IS NOT NULL DROP VIEW vw_Consolidado_CxP;
IF OBJECT_ID('sp_ActualizarHistorialDesempeño',   'P') IS NOT NULL DROP PROCEDURE sp_ActualizarHistorialDesempeño;
IF OBJECT_ID('sp_RegistrarIncidencia',            'P') IS NOT NULL DROP PROCEDURE sp_RegistrarIncidencia;
IF OBJECT_ID('Incidencias_Proveedor',             'U') IS NOT NULL DROP TABLE Incidencias_Proveedor;
IF OBJECT_ID('Historico_Desempeño',               'U') IS NOT NULL DROP TABLE Historico_Desempeño;
IF OBJECT_ID('Config_Scoring',                    'U') IS NOT NULL DROP TABLE Config_Scoring;
IF OBJECT_ID('Movimientos_CxP',                   'U') IS NOT NULL DROP TABLE Movimientos_CxP;
IF OBJECT_ID('Cat_Proveedores',                   'U') IS NOT NULL DROP TABLE Cat_Proveedores;
GO

-- =====================================================
-- FASE 1: TABLAS BASE
-- =====================================================

-- 1.1 Catálogo de Proveedores
CREATE TABLE Cat_Proveedores (
    id_proveedor            INT IDENTITY(1,1) PRIMARY KEY,
    nombre_comercial        VARCHAR(100)   NOT NULL,
    categoria               VARCHAR(50),
    criticidad_operativa    VARCHAR(20)    DEFAULT 'Media',   -- Crítica|Alta|Media|Baja
    riesgo_operativo        VARCHAR(20)    DEFAULT 'Medio',   -- Alto|Medio|Bajo
    condicion_pago          VARCHAR(20)    DEFAULT 'Crédito', -- Crédito|Contado
    dias_credito_autorizado INT            DEFAULT 30,
    sustituibilidad         VARCHAR(20)    DEFAULT 'Media',   -- Único|Difícil|Media|Fácil
    origen_seleccion        VARCHAR(50)    DEFAULT 'Comparativa',
    acepta_pago_parcial     BIT            DEFAULT 0,
    es_proveedor_estrategico BIT           DEFAULT 0,
    fecha_alta_proveedor    DATE           DEFAULT GETDATE(),
    categoria_compra        VARCHAR(50)    DEFAULT 'General',
	nombre_contacto VARCHAR(100) DEFAULT '',
    telefono_contacto VARCHAR(20) DEFAULT ''
);
GO

-- 1.2 Movimientos de Cuentas por Pagar
CREATE TABLE Movimientos_CxP (
    id_movimiento               INT IDENTITY(1,1) PRIMARY KEY,
    id_proveedor                INT            NOT NULL,
    descripcion_servicio        VARCHAR(100),
    monto_pendiente             DECIMAL(18,2)  NOT NULL,
    moneda                      CHAR(3)        DEFAULT 'MXN',
    fecha_factura               DATE,
    fecha_vencimiento           DATE,
    dias_vencidos_manual        INT            DEFAULT 0,    -- referencia; se calcula en la vista
    expediente_completo         BIT            DEFAULT 1,
    documentos_faltantes        VARCHAR(200)   DEFAULT '',
    orden_compra_valida         BIT            DEFAULT 1,
    riesgo_legal_presion        BIT            DEFAULT 0,
    criticidad_ref              VARCHAR(20),                 -- copia desnormalizada para reportes rápidos
    es_proveedor_estrategico_ref BIT           DEFAULT 0,
    riesgo_operativo_ref        VARCHAR(20),
    riesgo_paro_operativo       BIT            DEFAULT 0,
    retrabajos                  INT            DEFAULT 0,
    notas_operacion             VARCHAR(500)   DEFAULT '',
    presupuesto_referencia      DECIMAL(18,2)  DEFAULT 500000,
    prioridad_sugerida          VARCHAR(20)    DEFAULT 'Media',
    accion_recomendada          VARCHAR(20)    DEFAULT 'Programar',
    -- Trazabilidad operativa
    fecha_recepcion_real        DATE,
    fecha_expediente_completo   DATE,
    fecha_primer_contacto_proveedor DATE,
    canal_presion               VARCHAR(50),   -- Email|WhatsApp|Llamada|Presencial
    nivel_escalamiento          VARCHAR(20),   -- Operativo|Gerencial|Directivo|Legal
    fecha_pago_realizado        DATE,
    FOREIGN KEY (id_proveedor) REFERENCES Cat_Proveedores(id_proveedor)
);
GO

-- 1.3 Histórico de Desempeño
CREATE TABLE Historico_Desempeño (
    id_historico                INT IDENTITY(1,1) PRIMARY KEY,
    id_proveedor                INT            NOT NULL,
    fecha_corte                 DATE           NOT NULL DEFAULT GETDATE(),
    promedio_dias_vencidos      DECIMAL(10,2)  DEFAULT 0.00,
    total_documentos_procesados INT            DEFAULT 0,
    documentos_rechazados       INT            DEFAULT 0,
    historial_rechazos          INT            DEFAULT 0,
    tasa_expediente_completo    DECIMAL(5,2)   DEFAULT 100.00,
    promedio_dias_retrabajo     DECIMAL(10,2)  DEFAULT 0.00,
    monto_promedio_mensual      DECIMAL(18,2)  DEFAULT 0.00,
    frecuencia_pagos_mes        INT            DEFAULT 0,
    puntualidad_score           DECIMAL(5,2)   DEFAULT 100.00,
    FOREIGN KEY (id_proveedor) REFERENCES Cat_Proveedores(id_proveedor)
);
GO

-- 1.4 Incidencias (Causalidad)
CREATE TABLE Incidencias_Proveedor (
    id_incidencia       INT IDENTITY(1,1) PRIMARY KEY,
    id_proveedor        INT            NOT NULL,
    fecha_incidencia    DATE           NOT NULL DEFAULT GETDATE(),
    tipo_incidencia     VARCHAR(50)    NOT NULL, -- Rechazo|Retrabajo|Presión Legal|Paro Operativo
    gravedad            VARCHAR(20)    NOT NULL, -- Baja|Media|Alta|Crítica
    descripcion         VARCHAR(500),
    costo_incidencia    DECIMAL(18,2)  DEFAULT 0.00,
    resuelta            BIT            DEFAULT 0,
    fecha_resolucion    DATE,
    FOREIGN KEY (id_proveedor) REFERENCES Cat_Proveedores(id_proveedor)
);
GO

-- 1.5 Configuración de Scoring
CREATE TABLE Config_Scoring (
    id_config           INT IDENTITY(1,1) PRIMARY KEY,
    parametro           VARCHAR(100)   NOT NULL UNIQUE,
    valor_peso          DECIMAL(10,2)  NOT NULL,
    descripcion         VARCHAR(500),
    activo              BIT            DEFAULT 1,
    fecha_actualizacion DATETIME       DEFAULT GETDATE()
);
GO

CREATE TABLE Historico_Pagos (
    id INT IDENTITY PRIMARY KEY,
    id_proveedor INT,
    fecha_pago DATE,
    dias_vencidos INT,
    monto_pagado DECIMAL(12,2),
    expediente_completo BIT,
    FOREIGN KEY (id_proveedor) REFERENCES Cat_Proveedores(id_proveedor)
);
GO

-- =====================================================
-- FASE 2: PARÁMETROS DE SCORING
-- =====================================================

INSERT INTO Config_Scoring (parametro, valor_peso, descripcion) VALUES
('peso_criticidad_operativa',    40.00, 'Impacto en producción si el proveedor falla'),
('peso_riesgo_legal',            50.00, 'Presión legal o amenaza de demanda'),
('peso_dias_vencidos',           20.00, 'Normalizado por máximo en el período'),
('peso_riesgo_operativo',        10.00, 'Fiabilidad histórica del proveedor'),
('peso_proveedor_unico',         30.00, 'Bono si no tiene sustituto'),
('peso_riesgo_paro',             50.00, 'Amenaza inminente de paro de producción'),
('malus_retrabajo',             -15.00, 'Penalización por documentos mal entregados'),
('bono_contado',                 20.00, 'Bono si el proveedor opera a contado'),
('malus_tendencia_empeorando',   15.00, 'Penalización si el proveedor ahora debe más de lo usual'),
('peso_historial_rechazos',      -5.00, 'Penalización por cada rechazo histórico'),
('peso_puntualidad',             10.00, 'Bono por historial limpio de pagos'),
('umbral_proveedor_estrategico', 25.00, 'Bono si es proveedor estratégico');
GO

-- =====================================================
-- FASE 3: DATOS DE PRUEBA — CATÁLOGO DE PROVEEDORES
-- =====================================================

-- Los 40 proveedores del INSERT original.
-- Se cargan primero los catálogos, luego los movimientos.

INSERT INTO Cat_Proveedores
    (nombre_comercial, categoria, criticidad_operativa, riesgo_operativo,
     condicion_pago, sustituibilidad, acepta_pago_parcial, es_proveedor_estrategico,
     categoria_compra)
VALUES
-- 🔴 CRÍTICOS Y URGENTES
('Proveedor A',  'Material crítico',    'Crítica', 'Alto',  'Crédito', 'Único',  1, 1, 'Acero estructural'),
('Proveedor B',  'Material crítico',    'Crítica', 'Medio', 'Crédito', 'Media',  0, 0, 'Concreto'),
('Proveedor C',  'Operativo crítico',   'Alta',    'Alto',  'Crédito', 'Media',  0, 0, 'Refacciones maquinaria'),
-- 🟡 SERVICIOS RECURRENTES
('Proveedor D',  'Servicio recurrente', 'Alta',    'Bajo',  'Crédito', 'Media',  0, 0, 'Renta maquinaria'),
('Proveedor E',  'Servicio recurrente', 'Media',   'Bajo',  'Crédito', 'Media',  0, 0, 'Luz'),
-- ⚪ ADMINISTRATIVOS
('Proveedor F',  'Administrativo',      'Baja',    'Bajo',  'Crédito', 'Media',  0, 0, 'Papelería'),
('Proveedor G',  'Administrativo',      'Media',   'Medio', 'Crédito', 'Media',  0, 0, 'Consultoría'),
-- 🔴 ALTA ANTIGÜEDAD
('Proveedor H',  'Antigüedad alta',     'Media',   'Alto',  'Crédito', 'Media',  0, 0, 'Servicios varios'),
('Proveedor I',  'Antigüedad alta',     'Alta',    'Medio', 'Crédito', 'Media',  0, 0, 'Material eléctrico'),
-- ⚠️ EXPEDIENTE INCOMPLETO
('Proveedor J',  'Revisión',            'Alta',    'Medio', 'Crédito', 'Media',  0, 0, 'Material químico'),
('Proveedor K',  'Revisión',            'Media',   'Bajo',  'Crédito', 'Media',  0, 0, 'Servicios limpieza'),
-- ⚖️ CASOS MIXTOS
('Proveedor L',  'Operativo crítico',   'Alta',    'Alto',  'Crédito', 'Media',  0, 0, 'Refacciones'),
('Proveedor M',  'Material crítico',    'Crítica', 'Medio', 'Contado', 'Media',  0, 1, 'Cemento'),
-- 🟢 BUEN COMPORTAMIENTO
('Proveedor N',  'Servicio recurrente', 'Media',   'Bajo',  'Crédito', 'Media',  0, 0, 'Internet'),
('Proveedor O',  'Operativo crítico',   'Alta',    'Bajo',  'Crédito', 'Media',  0, 0, 'Mantenimiento'),
-- 🔴 RIESGO LEGAL
('Proveedor P',  'Antigüedad alta',     'Media',   'Alto',  'Crédito', 'Media',  0, 0, 'Servicios legales'),
-- 🟡 VARIADOS
('Proveedor Q',  'Administrativo',      'Baja',    'Bajo',  'Crédito', 'Fácil',  0, 0, 'Publicidad'),
('Proveedor R',  'Material crítico',    'Alta',    'Medio', 'Crédito', 'Media',  0, 0, 'Arena'),
('Proveedor S',  'Operativo crítico',   'Alta',    'Bajo',  'Crédito', 'Media',  0, 0, 'Herramientas'),
('Proveedor T',  'Servicio recurrente', 'Alta',    'Medio', 'Crédito', 'Media',  0, 0, 'Seguridad'),
-- 🧩 MÁS CASOS
('Proveedor U',  'Administrativo',      'Baja',    'Bajo',  'Crédito', 'Media',  0, 0, 'Capacitación'),
('Proveedor V',  'Material crítico',    'Alta',    'Medio', 'Crédito', 'Media',  0, 0, 'Vidrio'),
('Proveedor W',  'Revisión',            'Alta',    'Medio', 'Crédito', 'Media',  0, 0, 'Equipo'),
('Proveedor X',  'Antigüedad alta',     'Media',   'Medio', 'Crédito', 'Media',  0, 0, 'Cableado'),
('Proveedor Y',  'Servicio recurrente', 'Media',   'Bajo',  'Crédito', 'Media',  0, 0, 'Agua'),
('Proveedor Z',  'Operativo crítico',   'Alta',    'Alto',  'Crédito', 'Media',  0, 0, 'Refacciones'),
('Proveedor AA', 'Administrativo',      'Media',   'Bajo',  'Crédito', 'Media',  0, 0, 'Software'),
('Proveedor AB', 'Material crítico',    'Crítica', 'Alto',  'Crédito', 'Media',  0, 0, 'Acero'),
('Proveedor AC', 'Revisión',            'Media',   'Bajo',  'Crédito', 'Media',  0, 0, 'Servicios'),
('Proveedor AD', 'Antigüedad alta',     'Media',   'Medio', 'Crédito', 'Media',  0, 0, 'Transporte'),
('Proveedor AE', 'Servicio recurrente', 'Media',   'Bajo',  'Crédito', 'Media',  0, 0, 'Gas'),
('Proveedor AF', 'Operativo crítico',   'Alta',    'Alto',  'Crédito', 'Media',  0, 0, 'Equipo'),
('Proveedor AG', 'Administrativo',      'Baja',    'Bajo',  'Crédito', 'Media',  0, 0, 'RH'),
('Proveedor AH', 'Material crítico',    'Crítica', 'Medio', 'Crédito', 'Media',  0, 0, 'Cemento'),
('Proveedor AI', 'Revisión',            'Media',   'Bajo',  'Crédito', 'Media',  0, 0, 'Servicios'),
('Proveedor AJ', 'Antigüedad alta',     'Media',   'Alto',  'Crédito', 'Media',  0, 0, 'Material'),
('Proveedor AK', 'Servicio recurrente', 'Media',   'Bajo',  'Crédito', 'Media',  0, 0, 'Internet'),
('Proveedor AL', 'Operativo crítico',   'Alta',    'Medio', 'Crédito', 'Media',  0, 0, 'Refacciones'),
('Proveedor AM', 'Administrativo',      'Media',   'Medio', 'Crédito', 'Media',  0, 0, 'Consultoría'),
('Proveedor AN', 'Material crítico',    'Crítica', 'Alto',  'Crédito', 'Media',  0, 0, 'Acero');
GO

-- =====================================================
-- FASE 4: DATOS DE PRUEBA — MOVIMIENTOS CxP
-- =====================================================
-- Nota: los dias_vencidos se calculan dinámicamente en
-- la vista con DATEDIFF. Las fechas aquí son las originales
-- del INSERT de prueba; los días quedarán ~60-90 días más
-- vencidos al ejecutarse hoy (2026-05-01). Eso es correcto
-- para demostrar el sistema con datos realistas.

INSERT INTO Movimientos_CxP
    (id_proveedor, descripcion_servicio, monto_pendiente, moneda,
     fecha_factura, fecha_vencimiento,
     expediente_completo, documentos_faltantes, orden_compra_valida,
     riesgo_legal_presion, riesgo_paro_operativo, retrabajos,
     notas_operacion, presupuesto_referencia, prioridad_sugerida, accion_recomendada,
     criticidad_ref, es_proveedor_estrategico_ref, riesgo_operativo_ref)
VALUES
-- 🔴 CRÍTICOS Y URGENTES
(1,  'Acero estructural',    120000, 'MXN', '2026-02-01', '2026-03-01', 1, '',               1, 1, 1, 0, 'Material clave para producción. Si no se paga hoy, detienen la línea 3.',500000,'Alta','Pagar',    'Crítica',1,'Alto'),
(2,  'Concreto',              95000, 'MXN', '2026-02-10', '2026-03-10', 1, '',               1, 1, 0, 0, 'Alta dependencia operativa.',                                            500000,'Alta','Pagar',    'Crítica',0,'Medio'),
(3,  'Refacciones maquinaria',80000, 'MXN', '2026-02-15', '2026-03-15', 1, '',               1, 1, 0, 2, 'Impacta línea de producción.',                                           500000,'Alta','Pagar',    'Alta',  0,'Alto'),
-- 🟡 SERVICIOS RECURRENTES
(4,  'Renta maquinaria',      60000, 'MXN', '2026-03-01', '2026-04-01', 1, '',               1, 1, 0, 0, 'Servicio mensual indispensable.',                                        500000,'Media','Programar','Alta',  0,'Bajo'),
(5,  'Luz',                   30000, 'MXN', '2026-03-05', '2026-04-05', 1, '',               1, 1, 0, 0, 'Servicio básico.',                                                       500000,'Media','Programar','Media', 0,'Bajo'),
-- ⚪ ADMINISTRATIVOS
(6,  'Papelería',             10000, 'MXN', '2026-03-10', '2026-04-10', 1, '',               1, 0, 0, 0, 'No crítico.',                                                            500000,'Baja','Esperar',  'Baja',  0,'Bajo'),
(7,  'Consultoría',           40000, 'MXN', '2026-03-12', '2026-04-12', 1, '',               1, 0, 0, 1, 'Apoyo administrativo.',                                                  500000,'Baja','Esperar',  'Media', 0,'Medio'),
-- 🔴 ALTA ANTIGÜEDAD
(8,  'Servicios varios',      70000, 'MXN', '2025-12-01', '2026-01-01', 1, '',               1, 0, 1, 3, 'Presión por pago.',                                                      500000,'Alta','Revisar',  'Media', 0,'Alto'),
(9,  'Material eléctrico',    65000, 'MXN', '2025-12-15', '2026-01-15', 1, '',               1, 0, 0, 2, 'Atraso considerable.',                                                   500000,'Alta','Pagar',    'Alta',  0,'Medio'),
-- ⚠️ EXPEDIENTE INCOMPLETO
(10, 'Material químico',      50000, 'MXN', '2026-03-01', '2026-04-01', 0, 'Falta XML',      1, 1, 0, 2, 'Documentación incompleta.',                                              500000,'Revisión','Pendiente','Alta',1,'Medio'),
(11, 'Servicios limpieza',    20000, 'MXN', '2026-03-05', '2026-04-05', 0, 'Falta OC',       0, 1, 0, 1, 'Error administrativo.',                                                  500000,'Revisión','Pendiente','Media',0,'Bajo'),
-- ⚖️ CASOS MIXTOS
(12, 'Refacciones',           55000, 'MXN', '2026-02-20', '2026-03-20', 1, '',               1, 1, 0, 1, 'Importante pero costoso.',                                               500000,'Media','Revisar',  'Alta',  0,'Alto'),
(13, 'Cemento',              110000, 'MXN', '2026-02-18', '2026-03-18', 1, '',               1, 1, 0, 0, 'Alta prioridad.',                                                        500000,'Alta','Pagar',    'Crítica',1,'Medio'),
-- 🟢 BUEN COMPORTAMIENTO
(14, 'Internet',              15000, 'MXN', '2026-03-20', '2026-04-20', 1, '',               1, 1, 0, 0, 'Siempre cumple.',                                                        500000,'Media','Programar','Media', 0,'Bajo'),
(15, 'Mantenimiento',         45000, 'MXN', '2026-03-15', '2026-04-15', 1, '',               1, 1, 0, 0, 'Proveedor confiable.',                                                   500000,'Media','Programar','Alta',  0,'Bajo'),
-- 🔴 RIESGO LEGAL
(16, 'Servicios legales',     90000, 'MXN', '2025-11-01', '2025-12-01', 1, '',               1, 0, 1, 4, 'Amenaza legal activa. Presionando a compras por WhatsApp.',              500000,'Alta','Revisar',  'Media', 0,'Alto'),
-- 🟡 VARIADOS
(17, 'Publicidad',            25000, 'MXN', '2026-03-10', '2026-04-10', 1, '',               1, 0, 0, 0, 'No urgente.',                                                            500000,'Baja','Esperar',  'Baja',  0,'Bajo'),
(18, 'Arena',                 50000, 'MXN', '2026-02-25', '2026-03-25', 1, '',               1, 1, 0, 1, 'Uso constante.',                                                         500000,'Alta','Pagar',    'Alta',  0,'Medio'),
(19, 'Herramientas',          30000, 'MXN', '2026-03-01', '2026-04-01', 1, '',               1, 1, 0, 0, 'Soporte operación.',                                                     500000,'Media','Programar','Alta',  0,'Bajo'),
(20, 'Seguridad',             35000, 'MXN', '2026-03-05', '2026-04-05', 1, '',               1, 1, 0, 1, 'Servicio esencial.',                                                     500000,'Media','Programar','Alta',  0,'Medio'),
-- 🧩 MÁS CASOS
(21, 'Capacitación',          18000, 'MXN', '2026-03-12', '2026-04-12', 1, '',               1, 0, 0, 0, 'No urgente.',                                                            500000,'Baja','Esperar',  'Baja',  0,'Bajo'),
(22, 'Vidrio',                72000, 'MXN', '2026-02-20', '2026-03-20', 1, '',               1, 1, 0, 1, 'Importante.',                                                            500000,'Alta','Pagar',    'Alta',  0,'Medio'),
(23, 'Equipo',                65000, 'MXN', '2026-03-01', '2026-04-01', 0, 'Falta evidencia',1, 1, 0, 2, 'Pendiente validación.',                                                  500000,'Revisión','Pendiente','Alta',0,'Medio'),
(24, 'Cableado',              58000, 'MXN', '2025-12-10', '2026-01-10', 1, '',               1, 0, 0, 1, 'Atraso.',                                                                500000,'Alta','Revisar',  'Media', 0,'Medio'),
(25, 'Agua',                  12000, 'MXN', '2026-03-15', '2026-04-15', 1, '',               1, 1, 0, 0, 'Servicio básico.',                                                       500000,'Media','Programar','Media', 0,'Bajo'),
(26, 'Refacciones',           90000, 'MXN', '2026-02-15', '2026-03-15', 1, '',               1, 1, 0, 2, 'Clave.',                                                                 500000,'Alta','Pagar',    'Alta',  0,'Alto'),
(27, 'Software',              40000, 'MXN', '2026-03-01', '2026-04-01', 1, '',               1, 1, 0, 0, 'Licencias.',                                                             500000,'Media','Programar','Media', 0,'Bajo'),
(28, 'Acero',                105000, 'MXN', '2026-02-10', '2026-03-10', 1, '',               1, 1, 0, 1, 'Fundamental.',                                                           500000,'Alta','Pagar',    'Crítica',0,'Alto'),
(29, 'Servicios',             30000, 'MXN', '2026-03-05', '2026-04-05', 0, 'Falta OC',       0, 0, 0, 1, 'Revisión.',                                                              500000,'Revisión','Pendiente','Media',0,'Bajo'),
(30, 'Transporte',            50000, 'MXN', '2025-12-01', '2026-01-01', 1, '',               1, 1, 1, 3, 'Presión.',                                                               500000,'Alta','Revisar',  'Media', 0,'Medio'),
(31, 'Gas',                   22000, 'MXN', '2026-03-10', '2026-04-10', 1, '',               1, 1, 0, 0, 'Operación.',                                                             500000,'Media','Programar','Media', 0,'Bajo'),
(32, 'Equipo',                88000, 'MXN', '2026-02-20', '2026-03-20', 1, '',               1, 1, 0, 1, 'Importante.',                                                            500000,'Alta','Pagar',    'Alta',  0,'Alto'),
(33, 'RH',                    15000, 'MXN', '2026-03-12', '2026-04-12', 1, '',               1, 0, 0, 0, 'No crítico.',                                                            500000,'Baja','Esperar',  'Baja',  0,'Bajo'),
(34, 'Cemento',              115000, 'MXN', '2026-02-18', '2026-03-18', 1, '',               1, 1, 0, 0, 'Alta prioridad.',                                                        500000,'Alta','Pagar',    'Crítica',0,'Medio'),
(35, 'Servicios',             42000, 'MXN', '2026-03-01', '2026-04-01', 0, 'Falta XML',      1, 0, 0, 2, 'Pendiente.',                                                             500000,'Revisión','Pendiente','Media',0,'Bajo'),
(36, 'Material',              60000, 'MXN', '2025-12-05', '2026-01-05', 1, '',               1, 0, 0, 2, 'Retraso.',                                                               500000,'Alta','Revisar',  'Media', 0,'Alto'),
(37, 'Internet',              18000, 'MXN', '2026-03-20', '2026-04-20', 1, '',               1, 1, 0, 0, 'Constante.',                                                             500000,'Media','Programar','Media', 0,'Bajo'),
(38, 'Refacciones',           75000, 'MXN', '2026-02-25', '2026-03-25', 1, '',               1, 1, 0, 1, 'Clave.',                                                                 500000,'Alta','Pagar',    'Alta',  0,'Medio'),
(39, 'Consultoría',           35000, 'MXN', '2026-03-05', '2026-04-05', 1, '',               1, 0, 0, 1, 'Soporte.',                                                               500000,'Media','Esperar',  'Media', 0,'Medio'),
(40, 'Acero',                130000, 'MXN', '2026-02-01', '2026-03-01', 1, '',               1, 1, 0, 0, 'Fundamental.',                                                           500000,'Alta','Pagar',    'Crítica',0,'Alto');
GO

-- Actualizar fechas de recepción y expediente
UPDATE Movimientos_CxP SET fecha_recepcion_real       = fecha_factura WHERE fecha_recepcion_real IS NULL;
UPDATE Movimientos_CxP SET fecha_expediente_completo  = fecha_factura WHERE expediente_completo = 1 AND fecha_expediente_completo IS NULL;
GO

-- Casos especiales de escalamiento y canal (Proveedor J=10, P=16, AD=30)
UPDATE Movimientos_CxP SET nivel_escalamiento = 'Legal',     canal_presion = 'WhatsApp' WHERE id_proveedor = 10;
UPDATE Movimientos_CxP SET nivel_escalamiento = 'Legal',     canal_presion = 'WhatsApp' WHERE id_proveedor = 16;
UPDATE Movimientos_CxP SET nivel_escalamiento = 'Directivo', canal_presion = 'Llamada'  WHERE id_proveedor = 1;
UPDATE Movimientos_CxP SET nivel_escalamiento = 'Directivo', canal_presion = 'Llamada'  WHERE id_proveedor = 30;
GO

-- =====================================================
-- FASE 5: HISTÓRICO DE DESEMPEÑO (datos semilla)
-- =====================================================
-- Proveedores con historial negativo documentado

INSERT INTO Historico_Desempeño
    (id_proveedor, fecha_corte, promedio_dias_vencidos, total_documentos_procesados,
     documentos_rechazados, historial_rechazos, tasa_expediente_completo,
     promedio_dias_retrabajo, monto_promedio_mensual, frecuencia_pagos_mes, puntualidad_score)
VALUES
-- Proveedor J: mal historial (expediente siempre incompleto)
(10, '2026-04-01', 25.0, 10, 4, 4, 60.00, 3.5,  50000, 2, 40.00),
-- Proveedor H: presión recurrente
(8,  '2026-04-01', 70.0, 8,  2, 2, 75.00, 1.0,  70000, 1, 45.00),
-- Proveedor P: riesgo legal histórico
(16, '2026-04-01', 95.0, 6,  3, 4, 50.00, 4.0,  90000, 1, 30.00),
-- Proveedores confiables (buenos scores)
(1,  '2026-04-01', 5.0,  24, 0, 0, 100.00, 0.0, 120000, 4, 95.00),
(13, '2026-04-01', 3.0,  20, 0, 0, 100.00, 0.0, 110000, 3, 98.00),
(15, '2026-04-01', 2.0,  18, 0, 0, 100.00, 0.0,  45000, 3, 99.00),
-- Proveedor AD: tendencia empeorando
(30, '2026-04-01', 45.0, 12, 2, 3, 83.00, 2.0,  50000, 2, 50.00),
-- Proveedor X: atraso histórico moderado
(24, '2026-04-01', 60.0, 10, 1, 1, 90.00, 1.0,  58000, 2, 55.00);
GO

-- =====================================================
-- FASE 6: INCIDENCIAS HISTÓRICAS
-- =====================================================

INSERT INTO Incidencias_Proveedor (id_proveedor, tipo_incidencia, gravedad, descripcion, costo_incidencia)
VALUES
(10, 'Rechazo',         'Alta',     'Documentación incompleta repetida (4ta vez)',              5000.00),
(10, 'Retrabajo',       'Media',    'XML con datos erróneos, reenvío requerido',                1500.00),
(16, 'Presión Legal',   'Crítica',  'Amenaza formal de demanda por adeudo > 120 días',         15000.00),
(8,  'Presión Legal',   'Alta',     'Llamadas insistentes a dirección',                         2000.00),
(30, 'Paro Operativo',  'Alta',     'Detuvo servicio de transporte por falta de pago',          8000.00),
(1,  'Paro Operativo',  'Crítica',  'Aviso: si no se paga en 24h detienen entrega de acero',  50000.00);
GO

-- =====================================================
-- FASE 7: VISTA CONSOLIDADA CON SCORING v2
-- =====================================================

CREATE OR ALTER VIEW vw_Consolidado_CxP AS
WITH Historico AS (
    SELECT
        id_proveedor,
        promedio_dias_vencidos,
        historial_rechazos,
        tasa_expediente_completo,
        puntualidad_score,
        monto_promedio_mensual,
        ROW_NUMBER() OVER (PARTITION BY id_proveedor ORDER BY fecha_corte DESC) AS rn
    FROM Historico_Desempeño
),
ConfigParams AS (
    SELECT parametro, valor_peso
    FROM Config_Scoring
    WHERE activo = 1
),
MaxDias AS (
    SELECT ISNULL(MAX(DATEDIFF(DAY, fecha_vencimiento, GETDATE())), 1) AS max_dias_vencidos
    FROM Movimientos_CxP
    WHERE monto_pendiente > 0
)
SELECT
    -- Identificadores
    cp.id_proveedor,
    cp.nombre_comercial                                AS proveedor_nombre,

    -- Datos operativos
    m.monto_pendiente,
    cp.criticidad_operativa,
    cp.riesgo_operativo,
    cp.condicion_pago,
    cp.sustituibilidad,
    cp.acepta_pago_parcial,
    cp.es_proveedor_estrategico,

    -- Trazabilidad
    m.fecha_recepcion_real,
    m.fecha_expediente_completo,
    m.fecha_vencimiento,
    m.riesgo_paro_operativo,
    m.canal_presion,
    m.nivel_escalamiento,

    -- Urgencia temporal
    DATEDIFF(DAY, m.fecha_vencimiento, GETDATE())     AS dias_vencidos,
    CASE
        WHEN m.fecha_expediente_completo IS NOT NULL
        THEN DATEDIFF(DAY, m.fecha_expediente_completo, GETDATE())
        ELSE DATEDIFF(DAY, m.fecha_vencimiento, GETDATE())
    END                                                AS dias_vencidos_reales,

    -- Documentación
    m.expediente_completo,
    m.orden_compra_valida,
    m.documentos_faltantes,
    m.riesgo_legal_presion,
    m.retrabajos,
    m.notas_operacion,

    -- Histórico predictivo
    ISNULL(h.promedio_dias_vencidos,    0)    AS promedio_dias_anterior,
    ISNULL(h.historial_rechazos,        0)    AS historial_rechazos,
    ISNULL(h.tasa_expediente_completo, 100.0) AS tasa_expediente_completo,
    ISNULL(h.puntualidad_score,        100.0) AS puntualidad_score,
    ISNULL(h.monto_promedio_mensual,     0.0) AS monto_promedio_mensual,

    -- Variable causal: tendencia empeorando
    CASE
        WHEN DATEDIFF(DAY, m.fecha_vencimiento, GETDATE()) > (ISNULL(h.promedio_dias_vencidos, 0) + 5)
        THEN 1 ELSE 0
    END AS tendencia_empeorando,

    -- Días vencidos normalizado (0-100)
    CASE
        WHEN md.max_dias_vencidos > 0
        THEN (CAST(DATEDIFF(DAY, m.fecha_vencimiento, GETDATE()) AS DECIMAL(10,2)) / md.max_dias_vencidos) * 100
        ELSE 0
    END AS dias_vencidos_normalizado,

    -- ── SCORING v2 ──────────────────────────────────────────────────
    (
        -- 1. Criticidad operativa (hasta 40 pts)
        (CASE cp.criticidad_operativa
            WHEN 'Crítica' THEN 100 WHEN 'Alta' THEN 70
            WHEN 'Media'   THEN 40  WHEN 'Baja' THEN 10
            ELSE 40
        END) * (SELECT valor_peso FROM ConfigParams WHERE parametro = 'peso_criticidad_operativa') / 100.0

        -- 2. Riesgo legal (hasta 50 pts, binario)
        + (m.riesgo_legal_presion
            * (SELECT valor_peso FROM ConfigParams WHERE parametro = 'peso_riesgo_legal'))

        -- 3. Días vencidos normalizados (hasta 20 pts)
        + (CASE WHEN md.max_dias_vencidos > 0
            THEN (CAST(DATEDIFF(DAY, m.fecha_vencimiento, GETDATE()) AS DECIMAL(10,2)) / md.max_dias_vencidos)
            ELSE 0 END
            * (SELECT valor_peso FROM ConfigParams WHERE parametro = 'peso_dias_vencidos'))

        -- 4. Riesgo operativo (hasta 10 pts)
        + ((CASE cp.riesgo_operativo
            WHEN 'Alto' THEN 100 WHEN 'Medio' THEN 50 WHEN 'Bajo' THEN 10
            ELSE 50 END)
            * (SELECT valor_peso FROM ConfigParams WHERE parametro = 'peso_riesgo_operativo') / 100.0)

        -- BONO: Proveedor único (30 pts)
        + (CASE WHEN cp.sustituibilidad = 'Único'
            THEN (SELECT valor_peso FROM ConfigParams WHERE parametro = 'peso_proveedor_unico')
            ELSE 0 END)

        -- BONO: Riesgo de paro operativo (50 pts)
        + (CASE WHEN m.riesgo_paro_operativo = 1
            THEN (SELECT valor_peso FROM ConfigParams WHERE parametro = 'peso_riesgo_paro')
            ELSE 0 END)

        -- MALUS: Retrabajos (-15 pts c/u)
        + (m.retrabajos
            * (SELECT valor_peso FROM ConfigParams WHERE parametro = 'malus_retrabajo'))

        -- BONO: Condición contado (20 pts)
        + (CASE WHEN cp.condicion_pago = 'Contado'
            THEN (SELECT valor_peso FROM ConfigParams WHERE parametro = 'bono_contado')
            ELSE 0 END)

        -- MALUS: Tendencia empeorando (15 pts)
        + (CASE
            WHEN DATEDIFF(DAY, m.fecha_vencimiento, GETDATE()) > (ISNULL(h.promedio_dias_vencidos, 0) + 5)
            THEN (SELECT valor_peso FROM ConfigParams WHERE parametro = 'malus_tendencia_empeorando')
            ELSE 0 END)

        -- MALUS: Historial rechazos (-5 pts c/u)
        + (ISNULL(h.historial_rechazos, 0)
            * (SELECT valor_peso FROM ConfigParams WHERE parametro = 'peso_historial_rechazos'))

        -- BONO: Puntualidad histórica (hasta 10 pts)
        + ((ISNULL(h.puntualidad_score, 100.0) / 100.0)
            * (SELECT valor_peso FROM ConfigParams WHERE parametro = 'peso_puntualidad'))

        -- BONO: Proveedor estratégico (25 pts)
        + (CASE WHEN cp.es_proveedor_estrategico = 1
            THEN (SELECT valor_peso FROM ConfigParams WHERE parametro = 'umbral_proveedor_estrategico')
            ELSE 0 END)

    ) AS score_prioridad_v2,

    -- Filtro documental
    CASE
        WHEN m.expediente_completo = 1 AND m.orden_compra_valida = 1 THEN 1
        ELSE 0
    END AS apto_para_pago

FROM Movimientos_CxP m
INNER JOIN Cat_Proveedores cp ON m.id_proveedor = cp.id_proveedor
LEFT  JOIN Historico h        ON cp.id_proveedor = h.id_proveedor AND h.rn = 1
CROSS JOIN MaxDias md
WHERE m.monto_pendiente > 0;
GO

-- =====================================================
-- FASE 8: VISTAS DE ANÁLISIS
-- =====================================================

CREATE OR ALTER VIEW vw_Proveedores_Riesgo_Critico AS
SELECT
    proveedor_nombre, monto_pendiente, dias_vencidos,
    score_prioridad_v2, criticidad_operativa,
    riesgo_paro_operativo, riesgo_legal_presion,
    nivel_escalamiento, canal_presion, notas_operacion
FROM vw_Consolidado_CxP
WHERE score_prioridad_v2 >= 100
   OR riesgo_paro_operativo = 1
   OR (riesgo_legal_presion = 1 AND nivel_escalamiento IN ('Directivo', 'Legal'));
GO

CREATE OR ALTER VIEW vw_Proveedores_Tendencia_Negativa AS
SELECT
    proveedor_nombre, monto_pendiente,
    dias_vencidos, promedio_dias_anterior,
    (dias_vencidos - promedio_dias_anterior) AS dias_diferencia,
    historial_rechazos, puntualidad_score, score_prioridad_v2
FROM vw_Consolidado_CxP
WHERE tendencia_empeorando = 1;
GO

-- =====================================================
-- FASE 9: PROCEDIMIENTOS ALMACENADOS
-- =====================================================

CREATE OR ALTER PROCEDURE sp_ActualizarHistorialDesempeño
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Historico_Desempeño (
        id_proveedor, fecha_corte, promedio_dias_vencidos,
        total_documentos_procesados, documentos_rechazados,
        historial_rechazos, tasa_expediente_completo,
        promedio_dias_retrabajo, monto_promedio_mensual,
        frecuencia_pagos_mes, puntualidad_score
    )
    SELECT
        id_proveedor,
        CAST(GETDATE() AS DATE),
        AVG(DATEDIFF(DAY, fecha_vencimiento, ISNULL(fecha_pago_realizado, GETDATE()))),
        COUNT(*),
        SUM(CASE WHEN expediente_completo = 0 THEN 1 ELSE 0 END),
        SUM(CASE WHEN expediente_completo = 0 THEN 1 ELSE 0 END),
        (CAST(SUM(CASE WHEN expediente_completo = 1 THEN 1 ELSE 0 END) AS DECIMAL(10,2)) / COUNT(*)) * 100,
        AVG(CASE WHEN retrabajos > 0 THEN CAST(retrabajos AS DECIMAL) ELSE NULL END),
        AVG(monto_pendiente),
        COUNT(*),
        CASE
            WHEN AVG(DATEDIFF(DAY, fecha_vencimiento, ISNULL(fecha_pago_realizado, GETDATE()))) <= 0  THEN 100.00
            WHEN AVG(DATEDIFF(DAY, fecha_vencimiento, ISNULL(fecha_pago_realizado, GETDATE()))) <= 15 THEN 80.00
            WHEN AVG(DATEDIFF(DAY, fecha_vencimiento, ISNULL(fecha_pago_realizado, GETDATE()))) <= 30 THEN 60.00
            ELSE 40.00
        END
    FROM Movimientos_CxP
    WHERE fecha_vencimiento >= DATEADD(MONTH, -1, GETDATE())
    GROUP BY id_proveedor;

    PRINT 'Historial de desempeño actualizado.';
END;
GO

CREATE OR ALTER PROCEDURE sp_RegistrarIncidencia
    @id_proveedor    INT,
    @tipo_incidencia VARCHAR(50),
    @gravedad        VARCHAR(20),
    @descripcion     VARCHAR(500) = NULL,
    @costo_incidencia DECIMAL(18,2) = 0.00
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO Incidencias_Proveedor (id_proveedor, tipo_incidencia, gravedad, descripcion, costo_incidencia)
    VALUES (@id_proveedor, @tipo_incidencia, @gravedad, @descripcion, @costo_incidencia);
    PRINT 'Incidencia registrada.';
END;
GO

-- =====================================================
-- VERIFICACIÓN FINAL
-- =====================================================
DECLARE @Cant_Prov INT;
DECLARE @Cant_Mov INT;
DECLARE @Cant_Hist INT;
DECLARE @Cant_Incidencias INT;
DECLARE @Cant_Config INT;

SELECT @Cant_Prov = COUNT(*) FROM Cat_Proveedores;
SELECT @Cant_Mov = COUNT(*) FROM Movimientos_CxP;
SELECT @Cant_Hist = COUNT(*) FROM Historico_Desempeño;
SELECT @Cant_Incidencias = COUNT(*) FROM Incidencias_Proveedor;
SELECT @Cant_Config = COUNT(*) FROM Config_Scoring;

PRINT 'Script ejecutado exitosamente.';
PRINT '';
PRINT 'RESUMEN:';
PRINT '   Cat_Proveedores      : ' + CAST(@Cant_Prov AS VARCHAR) + ' registros';
PRINT '   Movimientos_CxP      : ' + CAST(@Cant_Mov AS VARCHAR) + ' registros';
PRINT '   Historico_Desempeño  : ' + CAST(@Cant_Hist AS VARCHAR) + ' registros';
PRINT '   Incidencias_Proveedor: ' + CAST(@Cant_Incidencias AS VARCHAR) + ' registros';
PRINT '   Config_Scoring       : ' + CAST(@Cant_Config AS VARCHAR) + ' parámetros';
PRINT '';
PRINT 'Top 10 por Score v2:';

SELECT TOP 10
    proveedor_nombre,
    monto_pendiente,
    criticidad_operativa,
    dias_vencidos,
    ROUND(score_prioridad_v2, 1) AS score_v2,
    apto_para_pago,
    CASE WHEN riesgo_paro_operativo = 1 THEN 'PARO' ELSE '' END AS alerta_paro
FROM vw_Consolidado_CxP
ORDER BY score_prioridad_v2 DESC;

--consolidados
CREATE OR ALTER VIEW vw_Consolidado_CxP AS

WITH Historico AS (
    SELECT
        id_proveedor,
        promedio_dias_vencidos,
        historial_rechazos,
        tasa_expediente_completo,
        puntualidad_score,
        monto_promedio_mensual,
        ROW_NUMBER() OVER (PARTITION BY id_proveedor ORDER BY fecha_corte DESC) AS rn
    FROM Historico_Desempeño
),
HistoricoGauss AS (
    SELECT
        id_proveedor,
        COUNT(*)             AS total_operaciones,
        AVG(dias_vencidos)   AS media_dias,
        STDEV(dias_vencidos) AS std_dias
    FROM Historico_Pagos
    GROUP BY id_proveedor
),
MaxDias AS (
    SELECT ISNULL(MAX(DATEDIFF(DAY, fecha_vencimiento, GETDATE())), 1) AS max_dias_vencidos
    FROM Movimientos_CxP
    WHERE monto_pendiente > 0
),
ConfigParams AS (
    SELECT parametro, valor_peso
    FROM Config_Scoring
    WHERE activo = 1
)
SELECT
    -- ── Identificación ──────────────────────────────────────────
    cp.id_proveedor,
    cp.nombre_comercial        AS proveedor_nombre,
    cp.nombre_contacto         AS contacto,
    cp.telefono_contacto       AS telefono,

    -- ── Catálogo ────────────────────────────────────────────────
    cp.categoria,
    cp.criticidad_operativa,
    cp.riesgo_operativo,
    cp.condicion_pago,
    cp.sustituibilidad,
    cp.acepta_pago_parcial,
    cp.es_proveedor_estrategico,

    -- ── Movimiento ──────────────────────────────────────────────
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

    -- ── Días vencidos ───────────────────────────────────────────
    DATEDIFF(DAY, m.fecha_vencimiento, GETDATE()) AS dias_vencidos,

    CASE
        WHEN m.fecha_expediente_completo IS NOT NULL
        THEN DATEDIFF(DAY, m.fecha_expediente_completo, GETDATE())
        ELSE DATEDIFF(DAY, m.fecha_vencimiento,         GETDATE())
    END AS dias_vencidos_reales,

    -- ── Histórico desempeño (Historico_Desempeño) ───────────────
    ISNULL(h.promedio_dias_vencidos,    0)      AS promedio_dias_anterior,
    ISNULL(h.historial_rechazos,        0)      AS historial_rechazos,
    ISNULL(h.tasa_expediente_completo, 100.0)   AS tasa_expediente_completo,
    ISNULL(h.puntualidad_score,        100.0)   AS puntualidad_score,
    ISNULL(h.monto_promedio_mensual,     0.0)   AS monto_promedio_mensual,

    -- ── Tendencia ───────────────────────────────────────────────
    CASE
        WHEN DATEDIFF(DAY, m.fecha_vencimiento, GETDATE())
             > (ISNULL(h.promedio_dias_vencidos, 0) + 5)
        THEN 1 ELSE 0
    END AS tendencia_empeorando,

    -- ── Días normalizados ────────────────────────────────────────
    CASE
        WHEN md.max_dias_vencidos > 0
        THEN (CAST(DATEDIFF(DAY, m.fecha_vencimiento, GETDATE()) AS DECIMAL(10,2))
              / md.max_dias_vencidos) * 100
        ELSE 0
    END AS dias_vencidos_normalizado,

    -- ── SCORING v2 (completo) ───────────────────────────────────
    (
        (CASE cp.criticidad_operativa
            WHEN 'Crítica' THEN 100 WHEN 'Alta' THEN 70
            WHEN 'Media'   THEN 40  WHEN 'Baja' THEN 10
            ELSE 40
        END) * (SELECT valor_peso FROM ConfigParams WHERE parametro = 'peso_criticidad_operativa') / 100.0

        + (m.riesgo_legal_presion
           * (SELECT valor_peso FROM ConfigParams WHERE parametro = 'peso_riesgo_legal'))

        + (CASE WHEN md.max_dias_vencidos > 0
            THEN CAST(DATEDIFF(DAY, m.fecha_vencimiento, GETDATE()) AS DECIMAL(10,2))
                 / md.max_dias_vencidos
            ELSE 0 END
           * (SELECT valor_peso FROM ConfigParams WHERE parametro = 'peso_dias_vencidos'))

        + ((CASE cp.riesgo_operativo
            WHEN 'Alto' THEN 100 WHEN 'Medio' THEN 50 WHEN 'Bajo' THEN 10
            ELSE 50 END)
           * (SELECT valor_peso FROM ConfigParams WHERE parametro = 'peso_riesgo_operativo') / 100.0)

        + (CASE WHEN cp.sustituibilidad = 'Único'
            THEN (SELECT valor_peso FROM ConfigParams WHERE parametro = 'peso_proveedor_unico')
            ELSE 0 END)

        + (CASE WHEN m.riesgo_paro_operativo = 1
            THEN (SELECT valor_peso FROM ConfigParams WHERE parametro = 'peso_riesgo_paro')
            ELSE 0 END)

        + (m.retrabajos
           * (SELECT valor_peso FROM ConfigParams WHERE parametro = 'malus_retrabajo'))

        + (CASE WHEN cp.condicion_pago = 'Contado'
            THEN (SELECT valor_peso FROM ConfigParams WHERE parametro = 'bono_contado')
            ELSE 0 END)

        + (CASE
            WHEN DATEDIFF(DAY, m.fecha_vencimiento, GETDATE())
                 > (ISNULL(h.promedio_dias_vencidos, 0) + 5)
            THEN (SELECT valor_peso FROM ConfigParams WHERE parametro = 'malus_tendencia_empeorando')
            ELSE 0 END)

        + (ISNULL(h.historial_rechazos, 0)
           * (SELECT valor_peso FROM ConfigParams WHERE parametro = 'peso_historial_rechazos'))

        + ((ISNULL(h.puntualidad_score, 100.0) / 100.0)
           * (SELECT valor_peso FROM ConfigParams WHERE parametro = 'peso_puntualidad'))

        + (CASE WHEN cp.es_proveedor_estrategico = 1
            THEN (SELECT valor_peso FROM ConfigParams WHERE parametro = 'umbral_proveedor_estrategico')
            ELSE 0 END)

    ) AS score_prioridad_v2,

    -- ── Filtro documental ────────────────────────────────────────
    CASE
        WHEN m.expediente_completo = 1 AND m.orden_compra_valida = 1 THEN 1
        ELSE 0
    END AS apto_para_pago,

    -- ── GAUSSIANO (Historico_Pagos) ──────────────────────────────
    ISNULL(hg.total_operaciones, 0)  AS total_operaciones,
    hg.media_dias,
    hg.std_dias,

    CASE
        WHEN ISNULL(hg.total_operaciones, 0) >= 100 THEN 1
        ELSE 0
    END AS data_confiable,

    CASE
        WHEN ISNULL(hg.total_operaciones, 0) <  30  THEN 'Muy poca data'
        WHEN ISNULL(hg.total_operaciones, 0) <  60  THEN 'Limitada'
        WHEN ISNULL(hg.total_operaciones, 0) < 100  THEN 'Moderada'
        WHEN ISNULL(hg.total_operaciones, 0) < 200  THEN 'Confiable'
        ELSE                                              'Alta confiabilidad'
    END AS nivel_confianza_datos,

    -- Z-Score (calculado una sola vez via CROSS APPLY)
    z_calc.z                         AS z_score_dias,
    ng.nivel_gauss,
    ng.impacto_gauss

FROM Movimientos_CxP m
JOIN  Cat_Proveedores cp ON cp.id_proveedor = m.id_proveedor
LEFT JOIN Historico   h  ON h.id_proveedor  = cp.id_proveedor AND h.rn = 1
LEFT JOIN HistoricoGauss hg ON hg.id_proveedor = cp.id_proveedor
CROSS JOIN MaxDias md

CROSS APPLY (
    SELECT z = CASE
        WHEN hg.std_dias IS NULL OR hg.std_dias = 0 THEN 0
        ELSE (DATEDIFF(DAY, m.fecha_vencimiento, GETDATE()) - hg.media_dias)
             / NULLIF(hg.std_dias, 0)
    END
) z_calc

CROSS APPLY (
    SELECT
        nivel_gauss = CASE
            WHEN hg.std_dias IS NULL OR hg.std_dias = 0 THEN 'NORMAL'
            WHEN ABS(z_calc.z) > 3 THEN 'CRÍTICO (99.7%)'
            WHEN ABS(z_calc.z) > 2 THEN 'ATÍPICO (95%)'
            WHEN ABS(z_calc.z) > 1 THEN 'ALERTA (68%)'
            ELSE                        'NORMAL'
        END,
        impacto_gauss = CASE
            WHEN hg.std_dias IS NULL OR hg.std_dias = 0 THEN 0
            WHEN ABS(z_calc.z) > 3 THEN 30
            WHEN ABS(z_calc.z) > 2 THEN 20
            WHEN ABS(z_calc.z) > 1 THEN 10
            ELSE 0
        END
) ng

WHERE m.monto_pendiente > 0;
GO