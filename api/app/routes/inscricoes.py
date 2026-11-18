from flask import Blueprint, jsonify, request

from ..extensions import db
from ..models import (
    STATUS_APROVADO,
    STATUS_CONCLUIDO,
    STATUS_PENDENTE,
    STATUS_RECUSADO,
    Inscricao,
)
from ..schemas import AtualizarInscricaoSchema
from ..utils import ONG, VOLUNTARIO, erro, papel_requerido, usuario_id_atual, validar

bp = Blueprint("inscricoes", __name__, url_prefix="/inscricoes")

# Transições permitidas: Pendente -> Aprovado | Recusado ; Aprovado -> Concluído | Recusado
TRANSICOES = {
    STATUS_PENDENTE: {STATUS_APROVADO, STATUS_RECUSADO},
    STATUS_APROVADO: {STATUS_CONCLUIDO, STATUS_RECUSADO},
    STATUS_CONCLUIDO: set(),
    STATUS_RECUSADO: set(),
}


@bp.get("/minhas")
@papel_requerido(VOLUNTARIO)
def minhas():
    stmt = db.select(Inscricao).filter_by(voluntario_id=usuario_id_atual()).order_by(Inscricao.criado_em.desc())
    return jsonify([i.to_dict() for i in db.session.scalars(stmt).all()])


@bp.delete("/<int:inscricao_id>")
@papel_requerido(VOLUNTARIO)
def cancelar(inscricao_id: int):
    insc = db.session.get(Inscricao, inscricao_id)
    if not insc or insc.voluntario_id != usuario_id_atual():
        return erro("Inscrição não encontrada.", 404)
    if insc.status != STATUS_PENDENTE:
        return erro("Só é possível cancelar inscrições pendentes.", 400)
    db.session.delete(insc)
    db.session.commit()
    return jsonify({"ok": True})


@bp.patch("/<int:inscricao_id>")
@papel_requerido(ONG)
def atualizar_status(inscricao_id: int):
    """Aprovar / Recusar / Concluir. Ao concluir, 'horas' é obrigatório e soma ao voluntário."""
    insc = db.session.get(Inscricao, inscricao_id)
    if not insc or insc.campanha.ong_id != usuario_id_atual():
        return erro("Inscrição não encontrada.", 404)
    dados, err = validar(AtualizarInscricaoSchema(), request.get_json(silent=True))
    if err:
        return err
    novo = dados["status"]
    if novo not in TRANSICOES[insc.status]:
        return erro(f"Transição inválida: {insc.status} -> {novo}.", 400)

    if novo == STATUS_CONCLUIDO:
        horas = dados.get("horas")
        if horas is None:
            return erro("Informe as horas trabalhadas para concluir.", 422)
        insc.horas = int(horas)
        insc.voluntario.horas_trabalhadas = (insc.voluntario.horas_trabalhadas or 0) + insc.horas

    insc.status = novo
    db.session.commit()
    return jsonify(insc.to_dict(incluir_campanha=False, incluir_voluntario=True))
