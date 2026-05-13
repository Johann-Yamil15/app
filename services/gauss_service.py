import pandas as pd
import numpy as np

class GaussService:

    def __init__(self, umbral=2.0):
        self.umbral = umbral

    def aplicar_gauss(self, df: pd.DataFrame) -> pd.DataFrame:

        df = df.copy()

        print(f"DEBUG GaussService - Columnas entrada: {df.columns.tolist()}")

        # ── Z-score ──────────────────────────────────────────────────────
        # La vista ya calcula z_score_dias; solo rellenar nulos
        if "z_score_dias" in df.columns:
            df["z_score_dias"] = df["z_score_dias"].fillna(0)
        else:
            print("⚠️ WARNING: z_score_dias no está en la vista, inicializando en 0")
            df["z_score_dias"] = 0

        # ── nivel_gauss ──────────────────────────────────────────────────
        # Si la vista ya lo trajo (no nulo/vacío), lo respetamos.
        # Solo calculamos para filas que la vista dejó vacías.
        def clasificar(z):
            if abs(z) > 3:
                return "CRÍTICO (99.7%)"   # mismo texto que el CASE SQL
            elif abs(z) > 2:
                return "ATÍPICO (95%)"
            elif abs(z) > 1:
                return "ALERTA (68%)"
            return "NORMAL"

        nivel_vacio = df.get("nivel_gauss", pd.Series(dtype=str)).isna() \
                    | df.get("nivel_gauss", pd.Series(dtype=str)).eq("")
        
        if "nivel_gauss" not in df.columns:
            df["nivel_gauss"] = df["z_score_dias"].apply(clasificar)
        else:
            df.loc[nivel_vacio, "nivel_gauss"] = df.loc[nivel_vacio, "z_score_dias"].apply(clasificar)

        # ── impacto_gauss ────────────────────────────────────────────────
        # Igual: respetar el valor de la vista, calcular solo si falta
        def impacto(z):
            if abs(z) > 3:  return 30
            elif abs(z) > 2: return 20
            elif abs(z) > 1: return 10
            return 0

        impacto_vacio = df.get("impacto_gauss", pd.Series(dtype=float)).isna()

        if "impacto_gauss" not in df.columns:
            df["impacto_gauss"] = df["z_score_dias"].apply(impacto)
        else:
            df.loc[impacto_vacio, "impacto_gauss"] = df.loc[impacto_vacio, "z_score_dias"].apply(impacto)

        # ── es_outlier ───────────────────────────────────────────────────
        # Esto sí se recalcula siempre (la vista no tiene esta columna)
        df["es_outlier"] = df["z_score_dias"].abs() > self.umbral

        print(f"DEBUG GaussService - Columnas salida: {df.columns.tolist()}")
        print(f"DEBUG GaussService - Outliers encontrados: {df['es_outlier'].sum()}")

        return df