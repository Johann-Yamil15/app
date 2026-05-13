import pandas as pd
import numpy as np
from datetime import datetime
from typing import Optional, Dict
from sqlalchemy import Engine


class PresupuestoService:

    FACTORES_ESTACIONALES = {
        1: 0.85, 2: 0.9, 3: 1.0, 4: 1.05,
        5: 1.1, 6: 1.15, 7: 0.95, 8: 0.9,
        9: 1.0, 10: 1.05, 11: 1.1, 12: 1.25
    }

    def __init__(
        self,
        engine: Optional[Engine] = None,
        factor_exageracion: float = 1.15,
        ventana_semanas: int = 12
    ):
        self.engine = engine
        self.factor_exageracion = factor_exageracion
        self.ventana_semanas = ventana_semanas

    # =====================================================
    # 📊 1. CARGAR HISTÓRICO
    # =====================================================
    def cargar_historico(self) -> pd.DataFrame:

        if self.engine is None:
            return self._simular_datos()

        query = """
        SELECT 
            DATEPART(YEAR, fecha_pago) AS anio,
            DATEPART(WEEK, fecha_pago) AS semana,
            DATEPART(MONTH, fecha_pago) AS mes,
            SUM(monto_pagado) AS total_pagado
        FROM Historico_Pagos
        WHERE fecha_pago >= DATEADD(WEEK, -52, GETDATE())
        GROUP BY 
            DATEPART(YEAR, fecha_pago),
            DATEPART(WEEK, fecha_pago),
            DATEPART(MONTH, fecha_pago)
        ORDER BY anio DESC, semana DESC
        """

        try:
            df = pd.read_sql(query, self.engine)

            if df.empty:
                return self._simular_datos()

            df["total_pagado"] = pd.to_numeric(
                df["total_pagado"], errors="coerce"
            ).fillna(0)

            return df

        except Exception as e:
            print(f"Error cargando histórico: {e}")
            return self._simular_datos()

    # =====================================================
    # 🔄 2. SIMULACIÓN
    # =====================================================
    def _simular_datos(self) -> pd.DataFrame:

        np.random.seed(42)
        base = 450000
        data = []

        for i in range(52):
            fecha = datetime.now() - pd.Timedelta(weeks=i)
            mes = fecha.month

            total = base * self.FACTORES_ESTACIONALES[mes] * np.random.uniform(0.9, 1.1)

            data.append({
                "anio": fecha.year,
                "semana": fecha.isocalendar()[1],
                "mes": mes,
                "total_pagado": total
            })

        return pd.DataFrame(data)

    # =====================================================
    # 🧹 3. LIMPIEZA
    # =====================================================
    def limpiar_outliers(self, df: pd.DataFrame) -> pd.DataFrame:

        if df.empty:
            return df

        p5 = df["total_pagado"].quantile(0.05)
        p95 = df["total_pagado"].quantile(0.95)

        return df[(df["total_pagado"] >= p5) & (df["total_pagado"] <= p95)]

    # =====================================================
    # 📈 4. CALCULAR PRESUPUESTO
    # =====================================================
    def calcular_presupuesto(self) -> Dict:

        df = self.cargar_historico()

        if df.empty:
            return self._default()

        df = df.sort_values(by=["anio", "semana"], ascending=False)
        df = self.limpiar_outliers(df)

        df_reciente = df.head(self.ventana_semanas)

        if df_reciente.empty:
            return self._default()

        promedio = df_reciente["total_pagado"].mean()

        std = df_reciente["total_pagado"].std()
        std = 0 if pd.isna(std) else std

        mes_actual = datetime.now().month
        factor = self.FACTORES_ESTACIONALES.get(mes_actual, 1)

        ajustado = promedio * factor
        final = ajustado * self.factor_exageracion

        if pd.isna(final) or np.isinf(final):
            return self._default()

        return {
            "presupuesto_sugerido": float(round(final, 2)),
            "promedio_base": float(round(promedio, 2)),
            "desviacion": float(round(std, 2)),
            "factor_estacional": factor,
            "factor_exageracion": self.factor_exageracion,
            "rango_bajo": float(round(final - std, 2)),
            "rango_alto": float(round(final + std, 2))
        }

    # =====================================================
    # 📉 5. TENDENCIA
    # =====================================================
    def detectar_tendencia(self, df: pd.DataFrame) -> str:

        if len(df) < 6:
            return "Sin datos"

        df = df.sort_values(by=["anio", "semana"], ascending=False)

        mitad = int(len(df) / 2)

        viejo = df.tail(mitad)["total_pagado"].mean()
        nuevo = df.head(mitad)["total_pagado"].mean()

        if viejo == 0:
            return "Sin referencia"

        cambio = ((nuevo - viejo) / viejo) * 100

        if cambio > 10:
            return f"📈 CRECIENTE (+{cambio:.1f}%)"
        elif cambio < -10:
            return f"📉 DECRECIENTE ({cambio:.1f}%)"
        else:
            return f"➡️ ESTABLE ({cambio:.1f}%)"

    # =====================================================
    # 🧠 6. SUGERENCIA (con tendencia incluida)
    # =====================================================
    def sugerir_presupuesto(self) -> Dict:

        df = self.cargar_historico()
        resultado = self.calcular_presupuesto()

        tendencia = self.detectar_tendencia(df.head(self.ventana_semanas))
        resultado["tendencia"] = tendencia

        return resultado

    # =====================================================
    # 💬 7. FLUJO INTERACTIVO  ← NUEVO
    #    Mismo comportamiento que el flujo principal del
    #    segundo archivo (main → PredictorPresupuesto).
    #    Muestra el análisis, pregunta al usuario si acepta
    #    o prefiere ingresar el monto manualmente y devuelve
    #    el presupuesto final confirmado como float.
    # =====================================================
    def sugerir_presupuesto_interactivo(self) -> float:
        """
        Muestra el análisis de presupuesto en consola, le pregunta al usuario
        si acepta el valor sugerido o prefiere ingresar uno manualmente y
        devuelve el presupuesto final como float.

        Flujo:
          1. Calcular sugerencia con tendencia
          2. Imprimir reporte detallado
          3. Preguntar: [S]í / [N]o / [Enter] = Sí
          4a. Si acepta  → retornar presupuesto_sugerido
          4b. Si rechaza → pedir monto manual y retornarlo
        """
        print("\n" + "─" * 60)
        print("💡 ANÁLISIS DE PRESUPUESTO SEMANAL")
        print("─" * 60)

        sugerencia = self.sugerir_presupuesto()

        presupuesto_sugerido = sugerencia["presupuesto_sugerido"]
        promedio_base        = sugerencia["promedio_base"]
        desviacion           = sugerencia["desviacion"]
        factor_estacional    = sugerencia["factor_estacional"]
        factor_exageracion   = sugerencia["factor_exageracion"]
        rango_bajo           = sugerencia["rango_bajo"]
        rango_alto           = sugerencia["rango_alto"]
        tendencia            = sugerencia.get("tendencia", "Sin datos")

        # ── Reporte en consola ────────────────────────────────────────
        mes_nombre = datetime.now().strftime("%B").capitalize()
        print(f"\n  Promedio base ({self.ventana_semanas} semanas) : ${promedio_base:>15,.2f}")
        print(f"  Desviación estándar            : ${desviacion:>15,.2f}")
        print(f"  Factor estacional ({mes_nombre})   :  {factor_estacional:.2f}x")
        print(f"  Factor de seguridad             :  {factor_exageracion:.2f}x  (+{(factor_exageracion-1)*100:.0f}%)")
        print(f"  ─────────────────────────────────────────────────────")
        print(f"  Rango estimado                 : ${rango_bajo:>14,.2f}  —  ${rango_alto:,.2f}")
        print(f"  Tendencia histórica             :  {tendencia}")
        print(f"  ─────────────────────────────────────────────────────")
        print(f"  ✅ PRESUPUESTO SUGERIDO         : ${presupuesto_sugerido:>15,.2f}")
        print("─" * 60)

        # ── Confirmación del usuario ──────────────────────────────────
        respuesta = input(
            f"\n¿Usar el presupuesto sugerido de ${presupuesto_sugerido:,.2f}?\n"
            "  [S]í / [N]o (ingresar manual) / [Enter] = Sí: "
        ).strip().upper()

        if respuesta in ["", "S", "SI", "SÍ", "Y", "YES"]:
            print(f"\n✅ Usando presupuesto sugerido: ${presupuesto_sugerido:,.2f}\n")
            return presupuesto_sugerido

        # ── Ingreso manual ────────────────────────────────────────────
        while True:
            try:
                raw = input("💰 Ingresa el presupuesto disponible esta semana (ej: 500000): ")
                presupuesto_manual = float(raw.replace(",", "").replace("$", "").strip())
                if presupuesto_manual <= 0:
                    print("  ⚠️  El monto debe ser mayor a 0. Intenta de nuevo.")
                    continue
                print(f"\n✅ Usando presupuesto manual: ${presupuesto_manual:,.2f}\n")
                return presupuesto_manual
            except ValueError:
                print("  ❌ Valor inválido. Ingresa solo números (ej: 500000).")

    # =====================================================
    # 🔥 8. MÉTODO QUE USA TU API
    # =====================================================
    def obtener_presupuesto(self) -> float:

        resultado = self.sugerir_presupuesto()

        valor = resultado.get("presupuesto_sugerido", 0)

        if valor is None or pd.isna(valor):
            return 500000.0

        return float(valor)

    # =====================================================
    # 🧯 DEFAULT SAFE
    # =====================================================
    def _default(self):
        return {
            "presupuesto_sugerido": 500000.0,
            "promedio_base": 500000.0,
            "desviacion": 0.0,
            "factor_estacional": 1,
            "factor_exageracion": self.factor_exageracion,
            "rango_bajo": 500000.0,
            "rango_alto": 500000.0
        }

    # =====================================================
    # ⚡ 9. AJUSTE EN VIVO
    # =====================================================
    def ajuste_en_vivo(self, presupuesto, gastado, porcentaje_semana):

        if presupuesto == 0:
            return {"estado": "ERROR", "mensaje": "Presupuesto inválido"}

        uso = (gastado / presupuesto) * 100

        if uso > 90 and porcentaje_semana < 80:
            extra = (gastado / (porcentaje_semana / 100)) - presupuesto

            return {
                "estado": "ALERTA",
                "mensaje": "🚨 Sobreconsumo",
                "sugerencia": float(round(extra * 1.1, 2))
            }

        if uso < 50 and porcentaje_semana > 70:
            return {
                "estado": "HOLGADO",
                "mensaje": "💰 Puedes pagar más proveedores"
            }

        return {
            "estado": "NORMAL",
            "mensaje": "Ejecución estable"
        }