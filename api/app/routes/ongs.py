from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required

from ..extensions import db
from ..models import Ong
from ..schemas import AtualizarOngSchema, somente_digitos
from ..services.geocoding import geocodificar
from ..utils import ONG, erro, haversine_km, papel_requerido, usuario_id_atual, validar

bp = Blueprint("ongs", __name__, url_prefix="/ongs")


@bp.get("")
@jwt_required()
def listar():
    """Lista ONGs para o mapa.

    Query: lat, lng (opcionais — calculam distancia_km), raio_km (filtra), categoria, q (nome/causa).
    Busca por raio em laço O(n) com Haversine (T(n) = 23n), conforme trabalho acadêmico.
    """
    lat = request.args.get("lat", type=float)
    lng = request.args.get("lng", type=float)
    raio = request.args.get("raio_km", type=float)
    categoria = request.args.get("categoria")
    q = (request.args.get("q") or "").strip().lower()

    stmt = db.select(Ong)
    if categoria and categoria.lower() not in ("todas", "todos"):
        stmt = stmt.filter(Ong.categoria == categoria)
    ongs = db.session.scalars(stmt).all()

    resultado = []
    for ong in ongs:  # laço linear O(n)
        if q and q not in ong.nome_fantasia.lower() and q not in ong.categoria.lower():
            continue
        item = ong.to_dict()
        if lat is not None and lng is not None and ong.latitude is not None and ong.longitude is not None:
            d = haversine_km(lat, lng, ong.latitude, ong.longitude)
            if raio is not None and d > raio:
                continue
            item["distancia_km"] = round(d, 2)
        else:
            item["distancia_km"] = None
        resultado.append(item)

    resultado.sort(key=lambda o: (o["distancia_km"] is None, o["distancia_km"] or 0))
    return jsonify(resultado)


@bp.get("/<int:ong_id>")
@jwt_required()
def perfil_publico(ong_id: int):
    ong = db.session.get(Ong, ong_id)
    if not ong:
        return erro("ONG não encontrada.", 404)
    dados = ong.to_dict()
    dados["campanhas"] = [
        c.to_dict(incluir_foto=False) for c in sorted(ong.campanhas, key=lambda c: c.criado_em, reverse=True) if c.ativa
    ]
    return jsonify(dados)


@bp.put("/me")
@papel_requerido(ONG)
def atualizar_me():
    ong = db.session.get(Ong, usuario_id_atual())
    if not ong:
        return erro("ONG não encontrada.", 404)
    dados, err = validar(AtualizarOngSchema(), request.get_json(silent=True), partial=True)
    if err:
        return err

    endereco_mudou = "endereco" in dados and dados["endereco"] != ong.endereco
    for campo, valor in dados.items():
        if campo == "whatsapp":
            valor = somente_digitos(valor)
        setattr(ong, campo, valor)

    if endereco_mudou and "latitude" not in dados and ong.endereco:
        lat, lng = geocodificar(ong.endereco)
        if lat is not None:
            ong.latitude, ong.longitude = lat, lng

    db.session.commit()
    return jsonify(ong.to_dict())
