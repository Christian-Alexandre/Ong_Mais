import os
from datetime import timedelta

from dotenv import load_dotenv

load_dotenv()


class Config:
    SQLALCHEMY_DATABASE_URI = os.getenv("DATABASE_URL", "sqlite:///ong_mais.db")
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SQLALCHEMY_ENGINE_OPTIONS = {"pool_pre_ping": True}

    JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", "dev-secret-troque-em-producao-0123456789abcdef")
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(days=30)

    # Fotos/logos em Base64 podem ser grandes
    MAX_CONTENT_LENGTH = 16 * 1024 * 1024

    AUTO_SEED = os.getenv("AUTO_SEED", "1") == "1"
    # Só vale para SQLite: cria as tabelas no start. Em MySQL use `flask db upgrade`.
    AUTO_CREATE_TABLES = os.getenv("AUTO_CREATE_TABLES", "1") == "1"
