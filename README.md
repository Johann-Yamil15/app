# 📊 Sistema de Gestión Inteligente de Cuentas por Pagar (SAI)

API REST avanzada para optimizar decisiones de pago, presupuestos y análisis de proveedores usando análisis estadístico gaussiano, scoring dinámico e IA local.

---

## 🎯 Descripción General

Este sistema automatiza la gestión de cuentas por pagar mediante:
- **Análisis gaussiano**: Detección automática de comportamientos atípicos en proveedores
- **Scoring dinámico v2**: Algoritmo complejo que pondera criticidad, riesgo, plazo y confiabilidad
- **Sugerencias de presupuesto**: Basadas en histórico de 52 semanas con factores estacionales
- **Decisiones de pago automáticas**: Prioriza pagos según presupuesto disponible
- **Explicaciones IA**: Justificaciones automáticas de decisiones usando Ollama

---

## 🔌 Variables de Entorno (.env)

```plaintext
# Conexión a SQL Server
DB_USER=usuario_sql
DB_PASSWORD=contraseña_sql
DB_HOST=servidor_sql.com
DB_NAME=SAI
DB_DRIVER=ODBC Driver 17 for SQL Server

# Ollama (IA Local)
OLLAMA_URL=http://localhost:11434
OLLAMA_MODEL=llama3.1
```

**Archivo `.env` ubicación**: `c:\Users\USUARIO\Proyectos\trabajo\app\.env`

---

## 📡 Endpoints Detallados

### 1️⃣ GET `/reporte-semanal`
**Dashboard ejecutivo con análisis consolidado de cuentas por pagar**

#### Parámetros Query
| Parámetro | Tipo | Requerido | Default | Descripción |
|-----------|------|-----------|---------|-------------|
| `presupuesto` | float | No | 500000 | Presupuesto semanal disponible en MXN |
| `categoria` | string | No | null | Filtro por categoría (Materia Prima, Servicio Crítico, Operativo, Administrativo) |

#### Ejemplo Request
```bash
GET http://localhost:8000/reporte-semanal?presupuesto=600000&categoria=Servicio%20Crítico
```

#### Respuesta Exitosa (200)
```json
{
  "proveedores": [
    {
      "id": 1,
      "proveedor": "Proveedor A",
      "categoria": "Materia Prima",
      "score_ia": 95,
      "monto": 120000.50,
      "doc_status": "Completa",
      "doc_detalle": "",
      "urgencia": "Riesgo de Paro de Línea",
      "condicion": "Crédito",
      "dias_vencidos": 65,
      "sustituibilidad": "Único",
      "z_score": 2.35,
      "nivel_gauss": "ATÍPICO (95%)",
      "data_confiable": 1,
      "nivel_confianza": "Alta confiabilidad",
      "total_operaciones": 150,
      "causa_demora": "Antigüedad",
      "contacto": "Juan García",
      "telefono": "+52 555 1234567"
    }
    // ... más proveedores
  ],
  "kpis": {
    "semana": 19,
    "presupuesto_disponible": 600000,
    "sugerido_ia": 450000.75,
    "porcentaje_contado": 5.2,
    "casos_criticos": 12,
    "casos_paro_linea": 3,
    "score_promedio": 72.5,
    "benchmark_objetivo": 85,
    "proveedores_bajo_benchmark": 18,
    "ahorro_potencial": 250000.25,
    "facturas_pendientes": 40
  },
  "categorias": ["Materia Prima", "Servicio Crítico", "Operativo", "Administrativo"],
  "categoria_activa": "Servicio Crítico",
  "score_pct": 85.3,
  "presupuesto_pct": 75.0
}
```

---

### 2️⃣ GET `/analisis`
**Análisis gaussiano completo de todos los proveedores**

Devuelve todos los proveedores pendientes con métricas estadísticas de desviación.

#### Ejemplo Request
```bash
GET http://localhost:8000/analisis
```

#### Respuesta Exitosa (200)
```json
[
  {
    "id_proveedor": 1,
    "proveedor_nombre": "Proveedor A",
    "monto_pendiente": 120000.50,
    "criticidad_operativa": "Crítica",
    "riesgo_operativo": "Alto",
    "dias_vencidos": 65,
    "z_score_dias": 2.35,
    "nivel_gauss": "ATÍPICO (95%)",
    "impacto_gauss": 20,
    "es_outlier": true,
    "total_operaciones": 150,
    "media_dias": 30.5,
    "std_dias": 15.2,
    "data_confiable": 1,
    "score_prioridad_v2": 125.5,
    // ... más campos
  }
  // ... más proveedores (40 total)
]
```

---

### 3️⃣ GET `/alertas`
**Alertas críticas: proveedores con comportamiento atípico**

Filtra solo los outliers detectados por análisis gaussiano (desv. > 2σ).

#### Ejemplo Request
```bash
GET http://localhost:8000/alertas
```

#### Respuesta Exitosa (200)
```json
{
  "total_outliers": 16,
  "alertas": [
    {
      "id_proveedor": 1,
      "proveedor_nombre": "Proveedor A",
      "monto_pendiente": 120000.50,
      "dias_vencidos": 65,
      "z_score_dias": 2.35,
      "nivel_gauss": "ATÍPICO (95%)",
      "impacto_gauss": 20,
      "es_outlier": true,
      "riesgo_paro_operativo": 1,
      "riesgo_legal_presion": 1,
      "canal_presion": "Llamada",
      "nivel_escalamiento": "Directivo"
    }
    // ... 15 alertas más
  ]
}
```

---

### 4️⃣ POST `/presupuesto`
**Cálculo inteligente de presupuesto semanal recomendado**

Analiza histórico de 52 semanas con factores estacionales y tendencias.

#### Request Body
```json
{
  "monto": null
}
```

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `monto` | float &#124; null | null/0 → calcula sugerido | valor > 0 → usa ese monto |

#### Ejemplo 1: Presupuesto Sugerido
```bash
curl -X POST http://localhost:8000/presupuesto \
  -H "Content-Type: application/json" \
  -d '{"monto": null}'
```

#### Ejemplo 2: Presupuesto Manual
```bash
curl -X POST http://localhost:8000/presupuesto \
  -H "Content-Type: application/json" \
  -d '{"monto": 750000}'
```

#### Respuesta Exitosa (200)
```json
{
  "presupuesto_semanal": 518750.25,
  "fuente": "sugerido",
  "diferencia_vs_sugerido": 0.0,
  "analisis": {
    "promedio_base": 450000.0,
    "desviacion": 45000.5,
    "factor_estacional": 1.15,
    "factor_exageracion": 1.15,
    "rango_bajo": 473750.25,
    "rango_alto": 563750.25,
    "tendencia": "📈 CRECIENTE (+12.3%)",
    "presupuesto_sugerido": 518750.25
  }
}
```

#### Campos de Respuesta
| Campo | Descripción |
|-------|-------------|
| `presupuesto_semanal` | Monto final recomendado |
| `fuente` | Origen del presupuesto: "manual", "sugerido" o "fallback" |
| `diferencia_vs_sugerido` | Variación vs. propuesta automática |
| `promedio_base` | Promedio de últimas 12 semanas |
| `desviacion` | Desviación estándar del período |
| `factor_estacional` | Multiplicador por mes (0.85 - 1.25) |
| `factor_exageracion` | Margen de seguridad (1.15 = 15% sobre) |
| `rango_bajo/alto` | Intervalo de confianza ±1σ |
| `tendencia` | Crecimiento/decrecimiento % |

---

### 5️⃣ POST `/decision`
**Decisiones automáticas de pago con justificaciones IA**

Genera lista priorizada de qué pagar con el presupuesto disponible.

#### Request Body
```json
{
  "monto": 600000
}
```

#### Ejemplo Request
```bash
curl -X POST http://localhost:8000/decision \
  -H "Content-Type: application/json" \
  -d '{"monto": 600000}'
```

#### Respuesta Exitosa (200)
```json
{
  "presupuesto": 600000.0,
  "fuente": "manual",
  "decisiones": [
    {
      "proveedor": "Proveedor A",
      "monto": 120000.50,
      "score": 145.5,
      "nivel": "ATÍPICO (95%)",
      "decision": "🔥 PAGAR URGENTE",
      "explicacion": "Riesgo de paro operativo inminente (24h). Material crítico con supplier único. Presión legal activa a nivel directivo. Z-score=2.35 indica variación extrema en plazo. Recomendación: pago inmediato para evitar detención de línea 3."
    },
    {
      "proveedor": "Proveedor B",
      "monto": 95000.0,
      "score": 125.3,
      "nivel": "ALERTA (68%)",
      "decision": "🔥 PAGAR URGENTE",
      "explicacion": "Criticidad alta con 62 días vencidos. Dependencia operativa directa. Score acumulado (125.3) supera umbral de 100. Histórico: 4 rechazos previos (malus -20pts). Recomendación: pago esta semana."
    },
    {
      "proveedor": "Proveedor C",
      "monto": 80000.0,
      "score": 95.5,
      "nivel": "NORMAL",
      "decision": "⚠️ REVISAR",
      "explicacion": "Score alto (95.5) pero documentación incompleta (falta XML). Documento crítico pero expediente debe completarse. Recomendación: acelerar validación paralela a pago, máximo 3 días."
    },
    {
      "proveedor": "Proveedor F",
      "monto": 10000.0,
      "score": 15.0,
      "nivel": "NORMAL",
      "decision": "⏳ ESPERAR",
      "explicacion": "No crítico (papelería). Score bajo (15.0). Sin presión legal ni riesgo operativo. Histórico limpio. Presupuesto insuficiente para incluir. Recomendación: pagar en siguiente ciclo (próxima semana)."
    },
    {
      "proveedor": "Proveedor G",
      "monto": 40000.0,
      "score": 50.0,
      "nivel": "NORMAL",
      "decision": "❌ SIN PRESUPUESTO",
      "explicacion": "Presupuesto agotado tras prioridades críticas. Score moderado (50.0) pero sin urgencia extrema. Condición: Crédito (flexible). Recomendación: agendar para semana siguiente con presupuesto separado."
    }
  ]
}
```

#### Estados de Decisión
| Estado | Símbolo | Significa |
|--------|---------|----------|
| PAGAR URGENTE | 🔥 | Score > 20 + presupuesto disponible |
| REVISAR | ⚠️ | Score > 10 + presupuesto disponible |
| PROGRAMAR | 📅 | Score <= 10 + presupuesto disponible |
| ESPERAR | ⏳ | Presupuesto agotado pero posible después |
| SIN PRESUPUESTO | ❌ | Presupuesto insuficiente |

---

## 🗄️ Estructura de Base de Datos SQL Server

### Vista Principal: `vw_Consolidado_CxP`
La vista consolida datos de múltiples tablas para análisis:

```sql
SELECT
  -- Identificación
  id_proveedor, proveedor_nombre, contacto, telefono,
  
  -- Catálogo
  categoria, criticidad_operativa, riesgo_operativo,
  condicion_pago, sustituibilidad, es_proveedor_estrategico,
  
  -- Movimiento actual
  monto_pendiente, fecha_factura, fecha_vencimiento,
  expediente_completo, documentos_faltantes,
  
  -- Urgencia
  dias_vencidos, dias_vencidos_reales,
  
  -- Histórico
  promedio_dias_anterior, historial_rechazos,
  tasa_expediente_completo, puntualidad_score,
  
  -- SCORING v2 (algoritmo completo)
  score_prioridad_v2,
  
  -- GAUSSIANO (análisis estadístico)
  z_score_dias, nivel_gauss, impacto_gauss,
  data_confiable, nivel_confianza_datos
FROM vw_Consolidado_CxP
```

### Tablas Principales

#### 1. `Cat_Proveedores`
| Campo | Tipo | Descripción |
|-------|------|-------------|
| id_proveedor | INT PK | Identificador único |
| nombre_comercial | VARCHAR | Nombre del proveedor |
| categoria | VARCHAR | Tipo de bien/servicio |
| criticidad_operativa | VARCHAR | Crítica, Alta, Media, Baja |
| riesgo_operativo | VARCHAR | Alto, Medio, Bajo |
| condicion_pago | VARCHAR | Crédito, Contado |
| sustituibilidad | VARCHAR | Único, Difícil, Media, Fácil |
| es_proveedor_estrategico | BIT | Flag booleano |
| nombre_contacto | VARCHAR | Responsable |
| telefono_contacto | VARCHAR | Teléfono |

#### 2. `Movimientos_CxP`
| Campo | Tipo | Descripción |
|-------|------|-------------|
| id_movimiento | INT PK | Identificador único |
| id_proveedor | INT FK | Referencia a proveedor |
| monto_pendiente | DECIMAL | Cantidad a pagar |
| fecha_factura | DATE | Fecha de emisión |
| fecha_vencimiento | DATE | Fecha de vencimiento |
| expediente_completo | BIT | Documentación ok |
| orden_compra_valida | BIT | OC validada |
| riesgo_paro_operativo | BIT | Amenaza de paro |
| riesgo_legal_presion | BIT | Presión legal |
| retrabajos | INT | # de correcciones |
| notas_operacion | VARCHAR | Observaciones |
| canal_presion | VARCHAR | Email, WhatsApp, Llamada |
| nivel_escalamiento | VARCHAR | Operativo, Gerencial, Directivo, Legal |

#### 3. `Historico_Desempeño`
| Campo | Tipo | Descripción |
|-------|------|-------------|
| id_historico | INT PK | Identificador único |
| id_proveedor | INT FK | Referencia a proveedor |
| fecha_corte | DATE | Fecha de cálculo |
| promedio_dias_vencidos | DECIMAL | Promedio histórico |
| historial_rechazos | INT | Cantidad de rechazos |
| tasa_expediente_completo | DECIMAL | % documentos ok |
| puntualidad_score | DECIMAL | Score puntualidad 0-100 |
| monto_promedio_mensual | DECIMAL | Gasto promedio/mes |

#### 4. `Historico_Pagos`
| Campo | Tipo | Descripción |
|-------|------|-------------|
| id | INT PK | Identificador único |
| id_proveedor | INT FK | Referencia a proveedor |
| fecha_pago | DATE | Cuándo se pagó |
| dias_vencidos | INT | Días transcurridos |
| monto_pagado | DECIMAL | Cantidad pagada |
| expediente_completo | BIT | Documentos ok |

#### 5. `Config_Scoring`
Parámetros configurables del scoring v2:

| Parámetro | Valor | Descripción |
|-----------|-------|-------------|
| peso_criticidad_operativa | 40.0 | Impacto en producción |
| peso_riesgo_legal | 50.0 | Presión legal |
| peso_dias_vencidos | 20.0 | Antigüedad normalizada |
| peso_riesgo_operativo | 10.0 | Fiabilidad histórica |
| peso_proveedor_unico | 30.0 | Bono si es único |
| peso_riesgo_paro | 50.0 | Bono si hay riesgo paro |
| malus_retrabajo | -15.0 | -15pts por retrabajo |
| bono_contado | 20.0 | Bono si compra al contado |
| malus_tendencia_empeorando | 15.0 | Si está peor que promedio |
| peso_historial_rechazos | -5.0 | -5pts por rechazo |
| peso_puntualidad | 10.0 | Bono historial limpio |
| umbral_proveedor_estrategico | 25.0 | Bono si estratégico |

---

## 📐 Algoritmos y Cálculos

### Scoring v2 (Fórmula Completa)

```
SCORE_v2 = 
  (criticidad × 40/100) 
  + (riesgo_legal × 50) 
  + (dias_normalizado × 20)
  + (riesgo_operativo × 10/100)
  + [bono_unico × 30]
  + [bono_paro × 50]
  + (retrabajos × -15)
  + [bono_contado × 20]
  + [malus_tendencia × 15]
  + (rechazos × -5)
  + (puntualidad × 10/100)
  + [bono_estrategico × 25]
```

**Rango**: 0 - 500+ (sin techo)
**Umbral de pago urgente**: > 20
**Benchmark objetivo**: 85

### Análisis Gaussiano (Z-Score)

```
Z_SCORE = (dias_vencidos - promedio) / desviacion_estandar

Clasificación:
- |Z| > 3.0 → CRÍTICO (99.7%) → Impacto: 30
- |Z| > 2.0 → ATÍPICO (95%)   → Impacto: 20
- |Z| > 1.0 → ALERTA (68%)    → Impacto: 10
- |Z| ≤ 1.0 → NORMAL          → Impacto: 0

es_outlier = |Z| > 2.0
```

### Presupuesto Sugerido

```
HISTÓRICO = últimas 52 semanas desde Historico_Pagos
PROMEDIO = MEDIA(últimas 12 semanas)
SIGMA = STDEV(últimas 12 semanas)

factor_estacional = FACTORES_ESTACIONALES[mes_actual]
  Enero:12 = 0.85-1.25 (enero es pico)

presupuesto_ajustado = promedio × factor_estacional
presupuesto_final = presupuesto_ajustado × 1.15 (factor exageración)

rango = presupuesto_final ± sigma

tendencia = si(promedio_nuevo > promedio_viejo) creciente
```

---

## 🛠️ Servicios Internos

### `GaussService`
**Archivo**: `services/gauss_service.py`

```python
class GaussService:
    def aplicar_gauss(df: DataFrame) -> DataFrame:
        # Calcula z_score_dias, nivel_gauss, impacto_gauss, es_outlier
        # Entradas: DataFrame con columnas z_score_dias
        # Salidas: Mismas columnas + outliers
```

### `PresupuestoService`
**Archivo**: `services/presupuesto_service.py`

```python
class PresupuestoService:
    def cargar_historico() -> DataFrame
    def limpiar_outliers(df) -> DataFrame  
    def calcular_presupuesto() -> Dict
    def detectar_tendencia(df) -> str
    def sugerir_presupuesto() -> Dict
```

### `DecisionService`
**Archivo**: `services/decision_service.py`

```python
class DecisionService:
    def generar_decisiones(df, presupuesto) -> List[Dict]:
        # Por cada proveedor:
        # 1. Calcula score = impacto*0.4 + criticidad*0.3 + paro*0.2 + data*0.1
        # 2. Ordena por score DESC
        # 3. Asigna presupuesto secuencialmente
        # 4. Genera explicación con Ollama
```

### `DashboardService`
**Archivo**: `services/dashboard_service.py`

```python
class DashboardService:
    def obtener_proveedores(categoria?) -> List[Dict]:
        # Lee vw_Consolidado_CxP
        # Normaliza campos
        # Filtra por categoría (opcional)
        
    def obtener_kpis(presupuesto, proveedores) -> Dict:
        # Calcula:
        # - score_promedio
        # - sugerido_ia (presupuesto acumulado hasta límite)
        # - casos_criticos
        # - casos_paro_linea
        # - ahorro_potencial
        # - facturas_pendientes
```

### `OllamaService`
**Archivo**: `services/ollama_service.py`

```python
class OllamaService:
    def explicar_decision(
        proveedor, monto, z_score,
        riesgo_paro_operativo, criticidad_operativa,
        decision
    ) -> str:
        # Llama modelo local en http://localhost:11434
        # Retorna explicación natural de la decisión
```

---

## 📦 Dependencias (requirements.txt)

```
annotated-doc==0.0.4
annotated-types==0.7.0
anyio==4.13.0
certifi==2026.4.22
charset-normalizer==3.4.7
click==8.3.3
colorama==0.4.6
fastapi==0.136.1
greenlet==3.5.0
h11==0.16.0
idna==3.13
numpy==2.4.4
pandas==3.0.2
pydantic==2.13.3
pydantic-core==2.27.1
pyodbc==5.1.1
python-dotenv==1.0.1
requests==2.32.3
sqlalchemy==2.1.0
starlette==0.38.1
typing-extensions==4.12.2
uvicorn==0.30.1
```

---

## 🚀 Flujo de Ejecución Típico

```
1. GET /reporte-semanal
   ├─ Lee vw_Consolidado_CxP
   ├─ Aplica análisis gaussiano
   ├─ Calcula KPIs
   └─ Retorna dashboard ejecutivo

2. GET /analisis
   ├─ Lee vw_Consolidado_CxP (40 proveedores)
   ├─ Calcula z_score para cada uno
   ├─ Identifica outliers (16 alertas)
   └─ Retorna lista completa con métricas

3. GET /alertas
   ├─ Filtra es_outlier = true
   ├─ Ordena por impacto
   └─ Retorna solo los 16 críticos

4. POST /presupuesto
   ├─ Lee Historico_Pagos (últimas 52 semanas)
   ├─ Calcula promedio y σ
   ├─ Aplica factor estacional
   ├─ Detecta tendencia
   └─ Retorna sugerencia con rango

5. POST /decision
   ├─ Resuelve presupuesto (_resolver_presupuesto)
   ├─ Lee vw_Consolidado_CxP
   ├─ Por cada proveedor:
   │  ├─ Calcula score dinámico
   │  ├─ Asigna presupuesto
   │  └─ Solicita explicación a Ollama
   └─ Retorna decisiones priorizadas
```

---

## 💾 Instalación Completa

### 1. Clone/Setup
```bash
cd c:\Users\USUARIO\Proyectos\trabajo\app
python -m venv venv
venv\Scripts\activate
```

### 2. Instale Dependencias
```bash
pip install -r requirements.txt
```

### 3. Configure .env
```
DB_USER=sa
DB_PASSWORD=tu_password
DB_HOST=localhost\SQLEXPRESS
DB_NAME=SAI
DB_DRIVER=ODBC Driver 17 for SQL Server
```

### 4. Ejecute Script SQL
```sql
-- En SQL Server Management Studio
USE master;
exec sp_executesql N'EXECUTE sp_createdbfile @dbname=N''SAI''';
-- Luego ejecute SAI.sql completo
```

### 5. Inicie API
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### 6. Acceda a Documentación
```
Swagger UI:  http://localhost:8000/docs
ReDoc:       http://localhost:8000/redoc
```

---

## 📊 Ejemplo de Caso Real

**Escenario**: Presupuesto semanal de 600,000 MXN, 40 proveedores, 16 alertas gaussianas

1. **Dashboard**: Muestra 40 proveedores ordenados por score, 12 críticos, 3 con riesgo de paro
2. **Análisis**: Z-score de cada uno, 16 outliers detectados
3. **Alertas**: Solo los 16 atípicos (días_vencidos >> promedio)
4. **Presupuesto**: Sugiere 518,750 (histórico de 12 semanas × factor estacional × 1.15)
5. **Decisiones**: 
   - Proveedores A,B,C,M,L → "🔥 PAGAR URGENTE" (agotan ~400k)
   - Proveedores D,E,O → "⚠️ REVISAR" (doctos incompletos)
   - Proveedores F,K → "📅 PROGRAMAR" (no críticos, presupuesto)
   - Resto → "⏳ ESPERAR" o "❌ SIN PRESUPUESTO"

---

## 🎓 Documentación de API

Acceso automático en:
- **Swagger**: `http://localhost:8000/docs` (interactivo)
- **OpenAPI JSON**: `http://localhost:8000/openapi.json`
- **ReDoc**: `http://localhost:8000/redoc` (lectura)

---

## 🤝 Soporte

Para errores o preguntas:
1. Revisar logs en consola de uvicorn
2. Verificar conexión a BD: `python -c "from database import get_engine; get_engine()"`
3. Verificar Ollama: `curl http://localhost:11434/api/tags`
4. Validar archivos .env</content>
<parameter name="filePath">c:\Users\USUARIO\Proyectos\trabajo\app\README.md