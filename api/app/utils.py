import math
from functools import wraps

from flask import jsonify
from flask_jwt_extended import get_jwt, get_jwt_identity, verify_jwt_in_request
from marshmallow import ValidationError

from .models import PAPEL_ONG, PAPEL_VOLUNTARIO

RAIO_TERRA_KM = 6371.0


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Distância em km entre dois pontos (fórmula de Haversine)."""
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlmb = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlmb / 2) ** 2
    return 2 * RAIO_TERRA_KM * math.asin(math.sqrt(a))


def erro(mensagem, status: int = 400):
    return jsonify({"erro": mensagem}), status


def validar(schema, dados, partial: bool = False):
    """Retorna (dados_validados, None) ou (None, resposta_de_erro)."""
    try:
        return schema.load(dados or {}, partial=partial), None
    except ValidationError as e:
        return None, (jsonify({"erro": "Dados inválidos.", "detalhes": e.messages}), 422)


def papel_requerido(*papeis):
    """Exige JWT válido e papel (claim 'papel') dentro dos permitidos."""

    def decorator(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            verify_jwt_in_request()
            claims = get_jwt()
            if claims.get("papel") not in papeis:
                return erro("Acesso permitido apenas para: " + ", ".join(papeis), 403)
            return fn(*args, **kwargs)

        return wrapper

    return decorator


def usuario_id_atual() -> int:
    return int(get_jwt_identity())


def papel_atual() -> str | None:
    try:
        verify_jwt_in_request(optional=True)
        return get_jwt().get("papel")
    except Exception:
        return None


ONG = PAPEL_ONG
VOLUNTARIO = PAPEL_VOLUNTARIO
