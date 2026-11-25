from flask import Blueprint, jsonify, request

from ..extensions import db
from ..models import Campanha, Inscricao, Voluntario
from ..schemas import AtualizarVoluntarioSchema
from ..utils import ONG, VOLUNTARIO, erro, papel_atual, papel_requerido, usuario_id_atual, validar

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
    if "foto_base64" in dados:
        vol.foto_base64 = dados["foto_base64"] or None  # null/"" remove a foto
    db.session.commit()
    return jsonify(vol.to_dict())


@bp.get("/<int:voluntario_id>")
@papel_requerido(ONG, VOLUNTARIO)
def perfil_publico(voluntario_id: int):
    """Perfil do voluntário.

    - ONG: interesses, números, e-mail e a participação nas campanhas dela.
    - Outro voluntário (ex.: pelos comentários): sem e-mail e sem participação.
    """
    vol = db.session.get(Voluntario, voluntario_id)
    if not vol:
        return erro("Voluntário não encontrado.", 404)
    if papel_atual() == VOLUNTARIO:
        return jsonify(vol.to_dict(publico=True))
    ong_id = usuario_id_atual()
    inscricoes = db.session.scalars(
        db.select(Inscricao)
        .join(Campanha, Inscricao.campanha_id == Campanha.id)
        .filter(Inscricao.voluntario_id == voluntario_id, Campanha.ong_id == ong_id)
        .order_by(Inscricao.criado_em.desc())
    ).all()
    dados = vol.to_dict()
    dados["inscricoes_na_ong"] = [i.to_dict(incluir_campanha=True) for i in inscricoes]
    return jsonify(dados)
