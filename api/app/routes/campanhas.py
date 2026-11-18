from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required

from ..extensions import db
from ..models import (
    PAPEL_VOLUNTARIO,
    STATUS_PENDENTE,
    Campanha,
    Curtida,
    Inscricao,
)
from ..schemas import AtualizarCampanhaSchema, CampanhaSchema
from ..utils import ONG, VOLUNTARIO, erro, papel_atual, papel_requerido, usuario_id_atual, validar

bp = Blueprint("campanhas", __name__, url_prefix="/campanhas")


def _vol_id_se_voluntario() -> int | None:
    return usuario_id_atual() if papel_atual() == PAPEL_VOLUNTARIO else None


@bp.get("")
@jwt_required()
def feed():
    """Feed de campanhas ativas (mais recentes primeiro). Query: tipo, q."""
    tipo = request.args.get("tipo")
    q = (request.args.get("q") or "").strip().lower()
    stmt = db.select(Campanha).filter_by(ativa=True).order_by(Campanha.criado_em.desc())
    if tipo and tipo.upper() != "TODOS":
        stmt = stmt.filter(Campanha.tipo == tipo.upper())
    campanhas = db.session.scalars(stmt).all()
    vol_id = _vol_id_se_voluntario()
    itens = []
    for c in campanhas:
        if q and q not in c.titulo.lower() and q not in (c.descricao or "").lower() and q not in c.ong.nome_fantasia.lower():
            continue
        itens.append(c.to_dict(voluntario_id=vol_id))
    return jsonify(itens)


@bp.get("/minhas")
@papel_requerido(ONG)
def minhas():
    """Campanhas da ONG logada (Meu Painel), incluindo inativas."""
    stmt = db.select(Campanha).filter_by(ong_id=usuario_id_atual()).order_by(Campanha.criado_em.desc())
    return jsonify([c.to_dict() for c in db.session.scalars(stmt).all()])


@bp.get("/<int:campanha_id>")
@jwt_required()
def detalhe(campanha_id: int):
    c = db.session.get(Campanha, campanha_id)
    if not c:
        return erro("Campanha não encontrada.", 404)
    return jsonify(c.to_dict(voluntario_id=_vol_id_se_voluntario()))


@bp.post("")
@papel_requerido(ONG)
def criar():
    dados, err = validar(CampanhaSchema(), request.get_json(silent=True))
    if err:
        return err
    c = Campanha(ong_id=usuario_id_atual(), **dados)
    db.session.add(c)
    db.session.commit()
    return jsonify(c.to_dict()), 201


def _campanha_da_ong(campanha_id: int):
    c = db.session.get(Campanha, campanha_id)
    if not c:
        return None, erro("Campanha não encontrada.", 404)
    if c.ong_id != usuario_id_atual():
        return None, erro("Esta campanha não pertence à sua ONG.", 403)
    return c, None


@bp.put("/<int:campanha_id>")
@papel_requerido(ONG)
def atualizar(campanha_id: int):
    c, err = _campanha_da_ong(campanha_id)
    if err:
        return err
    dados, err = validar(AtualizarCampanhaSchema(), request.get_json(silent=True), partial=True)
    if err:
        return err
    for campo, valor in dados.items():
        setattr(c, campo, valor)
    db.session.commit()
    return jsonify(c.to_dict())


@bp.delete("/<int:campanha_id>")
@papel_requerido(ONG)
def excluir(campanha_id: int):
    c, err = _campanha_da_ong(campanha_id)
    if err:
        return err
    db.session.delete(c)
    db.session.commit()
    return jsonify({"ok": True})


# ---------- Curtidas (voluntário) ----------

@bp.post("/<int:campanha_id>/curtir")
@papel_requerido(VOLUNTARIO)
def curtir(campanha_id: int):
    """Alterna a curtida: retorna {curtiu, curtidas}."""
    c = db.session.get(Campanha, campanha_id)
    if not c:
        return erro("Campanha não encontrada.", 404)
    vol_id = usuario_id_atual()
    curtida = db.session.get(Curtida, (campanha_id, vol_id))
    if curtida:
        db.session.delete(curtida)
        curtiu = False
    else:
        db.session.add(Curtida(campanha_id=campanha_id, voluntario_id=vol_id))
        curtiu = True
    db.session.commit()
    db.session.refresh(c)
    return jsonify({"curtiu": curtiu, "curtidas": len(c.curtidas)})


# ---------- Inscrições por campanha ----------

@bp.post("/<int:campanha_id>/inscricoes")
@papel_requerido(VOLUNTARIO)
def inscrever(campanha_id: int):
    """Quero Ajudar (Voluntariado): cria inscrição Pendente."""
    c = db.session.get(Campanha, campanha_id)
    if not c or not c.ativa:
        return erro("Campanha não encontrada ou encerrada.", 404)
    if c.tipo != "VOLUNTARIADO":
        return erro("Inscrição só é possível em campanhas de Voluntariado.", 400)
    vol_id = usuario_id_atual()
    existente = db.session.scalar(db.select(Inscricao).filter_by(campanha_id=campanha_id, voluntario_id=vol_id))
    if existente:
        return jsonify(existente.to_dict()), 200
    insc = Inscricao(campanha_id=campanha_id, voluntario_id=vol_id, status=STATUS_PENDENTE)
    db.session.add(insc)
    db.session.commit()
    return jsonify(insc.to_dict()), 201


@bp.get("/<int:campanha_id>/inscricoes")
@papel_requerido(ONG)
def inscritos(campanha_id: int):
    """Gerenciar Voluntários Inscritos."""
    c, err = _campanha_da_ong(campanha_id)
    if err:
        return err
    lista = sorted(c.inscricoes, key=lambda i: i.criado_em, reverse=True)
    return jsonify([i.to_dict(incluir_campanha=False, incluir_voluntario=True) for i in lista])
