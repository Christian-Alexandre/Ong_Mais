from flask import Blueprint, jsonify, request

from ..catalogo import AREAS_POR_CATEGORIA
from ..services.geocoding import endereco_de_coordenadas
from ..utils import erro

bp = Blueprint("geo", __name__)


@bp.get("/geo/endereco")
def endereco():
    """Endereço a partir de lat/lng (usado no cadastro da ONG, antes do login)."""
    lat = request.args.get("lat", type=float)
    lng = request.args.get("lng", type=float)
    if lat is None or lng is None or not (-90 <= lat <= 90) or not (-180 <= lng <= 180):
        return erro("Informe lat e lng válidos.", 400)
    texto = endereco_de_coordenadas(lat, lng)
    if not texto:
        return erro("Não foi possível descobrir o endereço desta localização.", 502)
    return jsonify({"endereco": texto, "latitude": lat, "longitude": lng})


@bp.get("/catalogo")
def catalogo():
    """Categorias de causa e suas áreas de atuação."""
    return jsonify({"categorias": AREAS_POR_CATEGORIA})
