from fastapi import FastAPI
import pandas as pd
import traceback
import numpy as np
import math

from database import get_engine
from services.gauss_service import GaussService
from services.presupuesto_service import PresupuestoService
from services.decision_service import DecisionService
from services.dashboard_service import DashboardService

from pydantic import BaseModel
from typing import Optional


# ── Utilidad: limpiar NaN, NaT, inf para JSON ──────────────────────────────
def limpiar_nan(obj):
    """
    Reemplaza recursivamente NaN, NaT, inf con None en dicts y listas.
    Necesario porque JSON no puede serializar estos valores.
    """
    if isinstance(obj, dict):
        return {k: limpiar_nan(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [limpiar_nan(item) for item in obj]
    elif isinstance(obj, float):
        if math.isnan(obj) or math.isinf(obj):
            return None
        return obj
    elif pd.isna(obj):  # Captura NaT, None, NaN
        return None
    else:
        return obj


# ======================================
# 📦 MODELO COMPARTIDO
# ======================================
class PresupuestoRequest(BaseModel):
    monto: Optional[float] = None  # null | 0 → sugerido automático


# ======================================
# 🚀 APP + SERVICIOS
# ======================================
app = FastAPI()

engine = get_engine()

gauss         = GaussService()
presupuesto_srv = PresupuestoService(engine)
decision_srv  = DecisionService()


# ── Helpers ───────────────────────────────────────────────────────────

def _resolver_presupuesto(monto: Optional[float]) -> tuple[float, str]:
    """
    Centraliza la lógica de resolución de presupuesto.
    Devuelve (monto_final, fuente) donde fuente es 'manual' | 'sugerido' | 'fallback'.
    """
    print(f"DEBUG monto recibido: {monto!r}")
    if monto:                          # valor real > 0 enviado por el cliente
        return monto, "manual"

    resultado = presupuesto_srv.sugerir_presupuesto()
    sugerido  = resultado.get("presupuesto_sugerido")

    if sugerido and not pd.isna(sugerido) and sugerido > 0:
        return float(sugerido), "sugerido"

    return 500_000.0, "fallback"       # nunca regresa null

dashboard_srv = DashboardService(engine)

# ======================================
# 📈 DASHBOARD / REPORTE
# ======================================
@app.get("/reporte-semanal")  # Agregamos el decorador de FastAPI
def reporte_semanal(presupuesto: float = 500000.0, categoria: Optional[str] = None):
    """
    Endpoint para obtener los datos del dashboard.
    """
    # 1. Obtener datos de los servicios
    proveedores = dashboard_srv.obtener_proveedores(categoria)
    kpis = dashboard_srv.obtener_kpis(presupuesto, proveedores)

    # 2. Cálculos de lógica de negocio
    categorias_lista = ["Materia Prima", "Servicio Crítico", "Operativo", "Administrativo"]
    
    score_pct = round(kpis["score_promedio"] / 85 * 100, 1) if kpis.get("score_promedio") else 0
    
    presupuesto_disponible = kpis.get("presupuesto_disponible", 0)
    presupuesto_pct = round(kpis["sugerido_ia"] / presupuesto_disponible * 100, 1) if presupuesto_disponible else 0

    # 3. Retornar JSON (Diccionario de Python)
    resultado = {
        "proveedores": proveedores,
        "kpis": kpis,
        "categorias": categorias_lista,
        "categoria_activa": categoria,
        "score_pct": score_pct,
        "presupuesto_pct": presupuesto_pct,
    }
    
    # 🔧 LIMPIAR NaN, NaT, inf ANTES DE RETORNAR
    resultado = limpiar_nan(resultado)
    
    return resultado

# ======================================
# 📊 ANÁLISIS GENERAL
# ======================================
@app.get("/analisis")
def analisis():
    """
    Devuelve todas las cuentas por pagar con análisis gaussiano aplicado.
    """
    try:
        print("\n🔍 [/analisis] Iniciando consulta...")
        df = pd.read_sql("SELECT * FROM vw_Consolidado_CxP", engine)
        
        if df.empty:
            print("⚠️ [/analisis] Dataframe vacío")
            return {"mensaje": "No hay datos en vw_Consolidado_CxP", "datos": []}
        
        print(f"✅ [/analisis] Datos cargados: {df.shape[0]} filas")
        
        df = gauss.aplicar_gauss(df)
        
        resultado = df.to_dict(orient="records")
        # 🔧 LIMPIAR NaN, NaT, inf RECURSIVAMENTE
        resultado = limpiar_nan(resultado)
        
        print(f"✅ [/analisis] Análisis completado. Retornando {len(resultado)} registros")
        return resultado
    
    except Exception as e:
        error_msg = f"{type(e).__name__}: {str(e)}"
        print(f"\n❌ [/analisis] ERROR: {error_msg}")
        print(traceback.format_exc())
        return {
            "error": error_msg, 
            "tipo": type(e).__name__,
            "stacktrace": traceback.format_exc()
        }


# ======================================
# 🚨 ALERTAS
# ======================================
@app.get("/alertas")
def alertas():
    """
    Devuelve solo los proveedores marcados como outlier por el análisis gaussiano.
    """
    try:
        print("\n🔍 [/alertas] Iniciando consulta...")
        df = pd.read_sql("SELECT * FROM vw_Consolidado_CxP", engine)
        
        if df.empty:
            print("⚠️ [/alertas] Dataframe vacío")
            return {"mensaje": "No hay datos en vw_Consolidado_CxP", "alertas": []}
        
        print(f"✅ [/alertas] Datos cargados: {df.shape[0]} filas")
        
        df = gauss.aplicar_gauss(df)
        
        if "es_outlier" not in df.columns:
            print("❌ [/alertas] Columna 'es_outlier' no encontrada")
            return {"error": "Columna 'es_outlier' no generada por GaussService", "alertas": []}
        
        outliers_df = df[df["es_outlier"] == True].copy()
        
        outliers = outliers_df.to_dict(orient="records")
        # 🔧 LIMPIAR NaN, NaT, inf RECURSIVAMENTE
        outliers = limpiar_nan(outliers)
        
        print(f"✅ [/alertas] Análisis completado. Encontrados {len(outliers)} outliers")
        
        return {"total_outliers": len(outliers), "alertas": outliers}
    
    except Exception as e:
        error_msg = f"{type(e).__name__}: {str(e)}"
        print(f"\n❌ [/alertas] ERROR: {error_msg}")
        print(traceback.format_exc())
        return {
            "error": error_msg,
            "tipo": type(e).__name__, 
            "stacktrace": traceback.format_exc(),
            "alertas": []
        }


# ======================================
# 💰 PRESUPUESTO
# ======================================
@app.post("/presupuesto")
def presupuesto(body: PresupuestoRequest):
    """
    Devuelve el presupuesto semanal con su análisis completo.

    - monto > 0  → usa ese monto (fuente: manual)
    - monto = 0  → calcula el sugerido desde el histórico (fuente: sugerido)
    - monto null → igual que 0 (fuente: sugerido)
    - falla todo → 500,000 por defecto (fuente: fallback)

    Ejemplo de body:
        { "monto": 750000 }   ← manual
        { "monto": 0 }        ← sugerido
        {}                    ← sugerido
    """
    monto_final, fuente = _resolver_presupuesto(body.monto)

    # Incluir el análisis completo del servicio para transparencia
    analisis_srv = presupuesto_srv.sugerir_presupuesto()

    resultado = {
        "presupuesto_semanal"  : monto_final,
        "fuente"               : fuente,
        "diferencia_vs_sugerido": round(monto_final - analisis_srv.get("presupuesto_sugerido", 0), 2),
        "analisis": {
            "promedio_base"      : analisis_srv.get("promedio_base"),
            "desviacion"         : analisis_srv.get("desviacion"),
            "factor_estacional"  : analisis_srv.get("factor_estacional"),
            "factor_exageracion" : analisis_srv.get("factor_exageracion"),
            "rango_bajo"         : analisis_srv.get("rango_bajo"),
            "rango_alto"         : analisis_srv.get("rango_alto"),
            "tendencia"          : analisis_srv.get("tendencia"),
            "presupuesto_sugerido": analisis_srv.get("presupuesto_sugerido"),
        }
    }
    
    # 🔧 LIMPIAR NaN, NaT, inf ANTES DE RETORNAR
    resultado = limpiar_nan(resultado)
    
    return resultado


# ======================================
# 🤖 DECISIÓN FINAL
# ======================================
@app.post("/decision")
def decision(body: PresupuestoRequest):
    """
    Genera las decisiones de pago priorizadas contra el presupuesto.

    Acepta el mismo body que /presupuesto — si no se envía monto (o es 0/null)
    calcula el presupuesto sugerido automáticamente antes de tomar decisiones.

    Ejemplo de body:
        { "monto": 750000 }   ← decide contra ese monto
        {}                    ← decide contra el monto sugerido
    """
    try:
        monto_final, fuente = _resolver_presupuesto(body.monto)

        print(f"\n🔍 [/decision] Presupuesto resuelto: {monto_final} ({fuente})")
        df = pd.read_sql("SELECT * FROM vw_Consolidado_CxP", engine)

        if df.empty:
            print("⚠️ [/decision] Dataframe vacío")
            return {"presupuesto": monto_final, "fuente": fuente, "decisiones": []}

        decisiones = decision_srv.generar_decisiones(df, monto_final)
        print(f"✅ [/decision] Decisiones generadas: {len(decisiones)}")

        resultado = {
            "presupuesto" : monto_final,
            "fuente"      : fuente,
            "decisiones"  : decisiones
        }
        
        # 🔧 LIMPIAR NaN, NaT, inf ANTES DE RETORNAR
        resultado = limpiar_nan(resultado)
        
        return resultado
    
    except Exception as e:
        error_msg = f"{type(e).__name__}: {str(e)}"
        print(f"\n❌ [/decision] ERROR: {error_msg}")
        print(traceback.format_exc())
        return {
            "error": error_msg,
            "tipo": type(e).__name__,
            "stacktrace": traceback.format_exc(),
            "decisiones": []
        }