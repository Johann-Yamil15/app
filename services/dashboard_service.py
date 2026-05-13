# services/dashboard_service.py

import pandas as pd
from sqlalchemy import Engine
import math


def _limpiar_nan(obj):
    """Limpia NaN, NaT, inf recursivamente para JSON."""
    if isinstance(obj, dict):
        return {k: _limpiar_nan(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [_limpiar_nan(item) for item in obj]
    elif isinstance(obj, float):
        if math.isnan(obj) or math.isinf(obj):
            return None
        return obj
    elif pd.isna(obj):
        return None
    else:
        return obj


CATEGORIA_MAP = {
    "Material crítico"   : "Materia Prima",
    "Operativo crítico"  : "Servicio Crítico",
    "Servicio recurrente": "Servicio Crítico",
    "Administrativo"     : "Administrativo",
    "Antigüedad alta"    : "Operativo",
    "Revisión"           : "Operativo",
}

URGENCIA_MAP = {
    # (riesgo_paro_operativo, dias_vencidos, criticidad) → label
}


def _resolver_urgencia(row: dict) -> str:
    if row.get("riesgo_paro_operativo") == 1:
        return "Riesgo de Paro de Línea"
    dias = row.get("dias_vencidos", 0)
    critica = row.get("criticidad_operativa", "")
    riesgo_legal = row.get("riesgo_legal_presion", 0)

    if riesgo_legal == 1 and dias > 60:
        return "Suspensión por Presión Legal"
    if critica == "Crítica" and dias > 30:
        return "Alta — Crítico Vencido"
    if critica == "Alta" and dias > 15:
        return "Alta — Servicio en Riesgo"
    if dias > 30:
        return "Retraso Significativo"
    if dias > 0:
        return "Moderado"
    return "Al corriente"


def _resolver_doc_status(row: dict) -> tuple[str, str]:
    """Devuelve (status_label, detalle)"""
    if row.get("expediente_completo") == 1 and row.get("orden_compra_valida") == 1:
        return "Completa", ""
    if row.get("expediente_completo") == 0:
        faltante = row.get("documentos_faltantes") or "Documentos pendientes"
        return "Incompleta", faltante
    if row.get("orden_compra_valida") == 0:
        return "En revisión", "OC no válida"
    return "En revisión", ""


def _normalizar_nivel_gauss(nivel_raw: str) -> str:
    """Limpia los emojis/prefijos que vienen de la vista SQL."""
    if not nivel_raw:
        return "NORMAL"
    # La vista puede traer '✅ NORMAL', '⚠️ ALERTA (68%)', etc.
    limpio = nivel_raw.strip()
    for prefix in ["✅ ", "⚠️ ", "🔶 ", "🔴 ", "?? ", "? "]:
        limpio = limpio.replace(prefix, "")
    return limpio.strip()


class DashboardService:

    def __init__(self, engine: Engine):
        self.engine = engine

    # ─────────────────────────────────────────────────────────────
    # MÉTODO PRINCIPAL
    # ─────────────────────────────────────────────────────────────
    def obtener_proveedores(self, categoria: str | None = None) -> list[dict]:
        """
        Lee vw_Consolidado_CxP y lo transforma al formato que
        espera el template dashboard/reporte_semanal.html.

        Parámetros:
            categoria: filtro opcional ('Materia Prima', 'Servicio Crítico',
                       'Operativo', 'Administrativo')
        """
        df = pd.read_sql("""
    SELECT v.*, 
           cp.nombre_contacto AS contacto,
           cp.telefono_contacto AS telefono
    FROM vw_Consolidado_CxP v
    JOIN Cat_Proveedores cp ON v.id_proveedor = cp.id_proveedor
""", self.engine)

        if df.empty:
            return []

        # 🔧 LIMPIAR NaN PARA JSON
        df = df.where(pd.notna(df), None)

        proveedores = []
        for idx, row in enumerate(df.to_dict(orient="records"), start=1):

            doc_status, doc_detalle = _resolver_doc_status(row)

            nivel_gauss_raw = row.get("nivel_gauss") or row.get("nivel_confianza_datos") or ""
            nivel_gauss     = _normalizar_nivel_gauss(nivel_gauss_raw)

            # Score: usar v2 de la vista, normalizado a 0-100
            score_raw  = float(row.get("score_prioridad_v2") or 0)
            score_norm = min(round(score_raw), 100)   # el score v2 puede superar 100 con bonos

            item = {
                "id"              : row.get("id_proveedor", idx),
                "proveedor"       : row.get("proveedor_nombre", ""),
                "categoria"       : CATEGORIA_MAP.get(
                                        row.get("categoria", ""), "Operativo"
                                    ),
                "score_ia"        : score_norm,
                "monto"           : float(row.get("monto_pendiente", 0)),
                "doc_status"      : doc_status,
                "doc_detalle"     : doc_detalle,
                "urgencia"        : _resolver_urgencia(row),
                "condicion"       : row.get("condicion_pago", "Crédito"),
                "dias_vencidos"   : int(row.get("dias_vencidos", 0)),
                "sustituibilidad" : row.get("sustituibilidad", "Media"),
                # Gaussiano
                "z_score"         : round(float(row.get("z_score_dias") or 0), 2),
                "nivel_gauss"     : nivel_gauss,
                "data_confiable"  : int(row.get("data_confiable", 0)),
                "nivel_confianza" : _normalizar_nivel_gauss(
                                        str(row.get("nivel_confianza_datos") or "Muy poca data")
                                    ),
                "total_operaciones": int(row.get("total_operaciones", 0)),
                # Campos extra que el template muestra en el blade/modal
                "causa_demora"    : _inferir_causa(row),
                "contacto"        : row.get("contacto", ""),
                "telefono"        : row.get("telefono", ""),
            }

            proveedores.append(item)

        # Filtro de categoría
        if categoria:
            proveedores = [p for p in proveedores if p["categoria"] == categoria]

        # Ordenar por score descendente (igual que la vista SQL)
        proveedores.sort(key=lambda p: p["score_ia"], reverse=True)

        # 🔧 LIMPIAR NaN, NaT, inf ANTES DE RETORNAR
        proveedores = _limpiar_nan(proveedores)
        
        return proveedores

    # ─────────────────────────────────────────────────────────────
    # KPIs para el bloque superior del template
    # ─────────────────────────────────────────────────────────────
    def obtener_kpis(self, presupuesto: float, proveedores: list[dict]) -> dict:
        from datetime import date

        total          = len(proveedores)
        scores         = [p["score_ia"] for p in proveedores]
        montos         = [p["monto"]    for p in proveedores]
        contado        = [p for p in proveedores if p["condicion"] == "Contado"]
        criticos       = [p for p in proveedores if p["score_ia"] >= 80]
        paro_linea     = [p for p in proveedores if "Paro" in p["urgencia"]]
        bajo_benchmark = [p for p in proveedores if p["score_ia"] < 85]

        score_promedio = round(sum(scores) / total, 1) if total else 0

        # Presupuesto sugerido por IA (acumulado de los que se pagarían)
        acumulado  = 0
        sugerido   = 0
        for p in sorted(proveedores, key=lambda x: x["score_ia"], reverse=True):
            if p["doc_status"] == "Completa":
                acumulado += p["monto"]
                if acumulado <= presupuesto:
                    sugerido = acumulado

        return {
            "semana"                : date.today().isocalendar()[1],
            "presupuesto_disponible": presupuesto,
            "sugerido_ia"           : round(sugerido, 2),
            "porcentaje_contado"    : round(len(contado) / total * 100, 1) if total else 0,
            "casos_criticos"        : len(criticos),
            "casos_paro_linea"      : len(paro_linea),
            "score_promedio"        : score_promedio,
            "benchmark_objetivo"    : 85,
            "proveedores_bajo_benchmark": len(bajo_benchmark),
            "ahorro_potencial"      : round(sum(montos) - sugerido, 2),
            "facturas_pendientes"   : total,
        }


# ─────────────────────────────────────────────────────────────────────
# Helper privado — inferencia de causa de demora
# ─────────────────────────────────────────────────────────────────────
def _inferir_causa(row: dict) -> str:
    if row.get("expediente_completo") == 0:
        return "Documentación"
    if row.get("orden_compra_valida") == 0:
        return "OC Inválida"
    if row.get("riesgo_legal_presion") == 1:
        return "Presión Legal"
    if row.get("retrabajos", 0) > 0:
        return "Retrabajo"
    if int(row.get("dias_vencidos", 0)) > 30:
        return "Antigüedad"
    return "Operativa"
