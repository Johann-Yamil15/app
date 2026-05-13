import os
import urllib
from sqlalchemy import create_engine
from dotenv import load_dotenv

load_dotenv()

def get_engine():
    usuario = os.getenv("DB_USER")
    password = os.getenv("DB_PASSWORD")
    host = os.getenv("DB_HOST")
    base_datos = os.getenv("DB_NAME")
    driver = os.getenv("DB_DRIVER")

    params = urllib.parse.quote_plus(
        f"DRIVER={{{driver}}};"
        f"SERVER={host};"
        f"DATABASE={base_datos};"
        f"UID={usuario};"
        f"PWD={password};"
        f"TrustServerCertificate=yes;"
    )

    engine = create_engine(
        f"mssql+pyodbc:///?odbc_connect={params}",
        pool_pre_ping=True  # 🔥 evita conexiones muertas
    )

    return engine