from flask import Blueprint, jsonify, request

from ..extensions import db
from ..models import Voluntario
from ..schemas import AtualizarVoluntarioSchema
from ..utils import VOLUNTARIO, erro, papel_requerido, usuario_id_atual, validar

bp = Blueprint("voluntarios", __name__, url_prefix="/voluntarios")


@bp.get("/me")
@papel_requerido(VOLUNTARIO)
def me():
    vol = db.session.get(Voluntario, usuario_id_atual())
    if not vol:
        return erro("Voluntário não encontrado.", 404)
    return jsonify(vol.to_dict())


@bp.put("/me")
@papel_requerido(VOLUNTARIO)
def atualizar_me():
    vol = db.session.get(Voluntario, usuario_id_atual())
    if not vol:
        return erro("Voluntário não encontrado.", 404)
    dados, err = validar(AtualizarVoluntarioSchema(), request.get_json(silent=True), partial=True)
    if err:
        return err
    if "nome_completo" in dados:
        vol.nome_completo = dados["nome_completo"].strip()
    if "interesses" in dados:
        vol.interesses = [i.strip() for i in (dados["interesses"] or []) if i and i.strip()]
    db.session.commit()
    return jsonify(vol.to_dict())
