from flask import Blueprint, jsonify, request

from ..extensions import db
from ..models import (
    STATUS_APROVADO,
    STATUS_CONCLUIDO,
    STATUS_PENDENTE,
    STATUS_RECUSADO,
    Campanha,
    Inscricao,
    Mensagem,
    utcnow,
)
from ..schemas import AtualizarInscricaoSchema, MensagemSchema
from ..utils import ONG, VOLUNTARIO, erro, papel_atual, papel_requerido, usuario_id_atual, validar

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
    vol_id = usuario_id_atual()
    stmt = db.select(Inscricao).filter_by(voluntario_id=vol_id).order_by(Inscricao.criado_em.desc())
    return jsonify([i.to_dict(leitor_id=vol_id) for i in db.session.scalars(stmt).all()])


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
        if horas is None and insc.turno is not None:
            horas = insc.turno.horas  # com turno, as horas saem da duração dele
        if horas is None:
            return erro("Informe as horas trabalhadas para concluir.", 422)
        insc.horas = int(horas)
        insc.voluntario.horas_trabalhadas = (insc.voluntario.horas_trabalhadas or 0) + insc.horas

    insc.status = novo
    # Avisa o voluntário na conversa
    aviso = {
        STATUS_APROVADO: "✅ Sua inscrição foi aprovada! Qualquer dúvida, é só responder por aqui.",
        STATUS_RECUSADO: "Sua inscrição não foi aprovada desta vez. Obrigado pelo interesse! Esta conversa foi encerrada.",
        STATUS_CONCLUIDO: f"🎉 Participação concluída: {insc.horas}h registradas no seu perfil. Muito obrigado! Esta conversa foi encerrada.",
    }[novo]
    insc.mensagens.append(Mensagem(autor_id=usuario_id_atual(), texto=aviso))
    db.session.commit()
    return jsonify(insc.to_dict(incluir_campanha=False, incluir_voluntario=True, leitor_id=usuario_id_atual()))


# ---------- Conversa (chat) da inscrição ----------

def _inscricao_da_conversa(inscricao_id: int):
    """Só o voluntário da inscrição e a ONG dona da campanha participam da conversa."""
    insc = db.session.get(Inscricao, inscricao_id)
    uid = usuario_id_atual()
    if not insc or uid not in (insc.voluntario_id, insc.campanha.ong_id):
        return None, erro("Conversa não encontrada.", 404)
    return insc, None


@bp.get("/<int:inscricao_id>/mensagens")
@papel_requerido(ONG, VOLUNTARIO)
def mensagens(inscricao_id: int):
    """Mensagens da conversa (mais antigas primeiro). Marca como lidas as recebidas."""
    insc, err = _inscricao_da_conversa(inscricao_id)
    if err:
        return err
    uid = usuario_id_atual()
    agora = utcnow().replace(tzinfo=None)
    mudou = False
    for m in insc.mensagens:
        if m.autor_id != uid and m.lida_em is None:
            m.lida_em = agora
            mudou = True
    if mudou:
        db.session.commit()
    return jsonify(
        {
            "inscricao": insc.to_dict(incluir_campanha=True, incluir_voluntario=True, leitor_id=uid),
            "mensagens": [m.to_dict(leitor_id=uid) for m in insc.mensagens],
        }
    )


@bp.post("/<int:inscricao_id>/mensagens")
@papel_requerido(ONG, VOLUNTARIO)
def enviar_mensagem(inscricao_id: int):
    insc, err = _inscricao_da_conversa(inscricao_id)
    if err:
        return err
    if insc.conversa_encerrada:
        motivo = "a participação foi concluída" if insc.status == STATUS_CONCLUIDO else "a inscrição foi recusada"
        return erro(f"Esta conversa foi encerrada porque {motivo}.", 409)
    dados, err = validar(MensagemSchema(), request.get_json(silent=True))
    if err:
        return err
    texto = dados["texto"].strip()
    if not texto:
        return erro("Escreva uma mensagem.", 422)
    m = Mensagem(autor_id=usuario_id_atual(), texto=texto)
    insc.mensagens.append(m)
    db.session.commit()
    return jsonify(m.to_dict(leitor_id=usuario_id_atual())), 201


@bp.get("/nao-lidas")
@papel_requerido(ONG, VOLUNTARIO)
def nao_lidas():
    """Total de mensagens não lidas (para o contador nas abas)."""
    uid = usuario_id_atual()
    if papel_atual() == ONG:
        stmt = db.select(Inscricao).join(Campanha, Inscricao.campanha_id == Campanha.id).filter(Campanha.ong_id == uid)
    else:
        stmt = db.select(Inscricao).filter_by(voluntario_id=uid)
    total = sum(1 for i in db.session.scalars(stmt).all() for m in i.mensagens if m.autor_id != uid and m.lida_em is None)
    return jsonify({"total": total})
