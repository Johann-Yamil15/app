import pandas as pd
from services.ollama_service import OllamaService
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


class DecisionService:

    MAPEO_CRITICIDAD = {
        "Baja": 1,
        "Media": 2,
        "Alta": 3,
        "Crítica": 4
    }

    def __init__(self):
        self.ollama = OllamaService()

    def generar_decisiones(self, df: pd.DataFrame, presupuesto: float):

        # =====================================================
        # 🔧 1. LIMPIEZA Y NORMALIZACIÓN
        # =====================================================

        df = df.copy()
        
        # 🔧 LIMPIAR NaN PARA JSON
        df = df.where(pd.notna(df), None)

        # Convertir criticidad (STRING → NUM)
        df["criticidad_operativa"] = (
            df["criticidad_operativa"]
            .map(self.MAPEO_CRITICIDAD)
            .fillna(1)
        )

        # Convertir a numéricos seguros
        df["impacto_gauss"] = pd.to_numeric(df["impacto_gauss"], errors="coerce").fillna(0)
        df["riesgo_paro_operativo"] = pd.to_numeric(df["riesgo_paro_operativo"], errors="coerce").fillna(0)
        df["data_confiable"] = pd.to_numeric(df["data_confiable"], errors="coerce").fillna(0)

        # =====================================================
        # 📊 2. SCORE INTELIGENTE
        # =====================================================
        df["score"] = (
            df["impacto_gauss"] * 0.4 +
            df["criticidad_operativa"] * 0.3 +
            df["riesgo_paro_operativo"] * 0.2 +
            df["data_confiable"] * 0.1
        )

        # Ordenar por prioridad real
        df = df.sort_values(by="score", ascending=False)

        # =====================================================
        # 💰 3. ASIGNACIÓN DE PRESUPUESTO
        # =====================================================
        disponible = presupuesto
        decisiones = []

        for _, row in df.iterrows():

            decision = "⏳ ESPERAR"

            if row["monto_pendiente"] <= disponible:

                if row["score"] > 20:
                    decision = "🔥 PAGAR URGENTE"
                elif row["score"] > 10:
                    decision = "⚠️ REVISAR"
                else:
                    decision = "📅 PROGRAMAR"

                disponible -= row["monto_pendiente"]

            else:
                decision = "❌ SIN PRESUPUESTO"

            # =====================================================
            # 🤖 EXPLICACIÓN IA (ARREGLADA)
            # =====================================================
            explicacion = self.ollama.explicar_decision(
                proveedor=row["proveedor_nombre"],
                monto=row["monto_pendiente"],
                z_score=row["z_score_dias"],
                riesgo_paro_operativo=row["riesgo_paro_operativo"],
                criticidad_operativa=row["criticidad_operativa"],
                decision=decision
            )

            decisiones.append({
                "proveedor": row["proveedor_nombre"],
                "monto": float(row["monto_pendiente"]),
                "score": float(row["score"]),
                "nivel": row["nivel_gauss"],
                "decision": decision,
                "explicacion": explicacion
            })

        # 🔧 LIMPIAR NaN, NaT, inf ANTES DE RETORNAR
        decisiones = _limpiar_nan(decisiones)
        
        return decisiones