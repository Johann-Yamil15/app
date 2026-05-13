import requests

class OllamaService:

    def __init__(self, model="llama3.1"):
        self.url = "http://localhost:11434/api/generate"
        self.model = model

    def explicar_decision(
        self, 
        proveedor, 
        monto, 
        z_score, 
        riesgo_paro_operativo=None, 
        criticidad_operativa=None, 
        decision=None,
        **kwargs  # 👈 acepta nombres alternos
    ):

        # 🔄 Compatibilidad por si vienen con otros nombres
        if riesgo_paro_operativo is None:
            riesgo_paro_operativo = kwargs.get("riesgo_paro")

        if criticidad_operativa is None:
            criticidad_operativa = kwargs.get("criticidad")

        prompt = f"""
Eres un analista financiero experto en cuentas por pagar.

Proveedor: {proveedor}
Monto pendiente: {monto}
Z-Score: {z_score}
Riesgo de paro operativo: {riesgo_paro_operativo}
Criticidad: {criticidad_operativa}

El sistema ya tomó esta decisión:
{decision}

Explica el porqué de esta decisión.

Responde en formato:

Decisión: {decision}
Justificación: máximo 3 líneas claras.
"""

        try:
            response = requests.post(self.url, json={
                "model": self.model,
                "prompt": prompt,
                "stream": False
            })

            response.raise_for_status()

            data = response.json()

            return data.get("response", "Sin respuesta del modelo")

        except requests.exceptions.RequestException as e:
            return f"Error en Ollama: {str(e)}"