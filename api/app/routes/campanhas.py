from datetime import timezone

from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required

from ..extensions import db
from ..models import (
    PAPEL_ONG,
    PAPEL_VOLUNTARIO,
    STATUS_PENDENTE,
    Campanha,
    Comentario,
    Curtida,
    Inscricao,
    ItemDoacao,
    Mensagem,
    Turno,
)
from ..schemas import (
    AtualizarCampanhaSchema,
    AtualizarItemSchema,
    CampanhaSchema,
    ComentarioSchema,
    InscreverSchema,
)
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
    ong_id = usuario_id_atual()
    stmt = db.select(Campanha).filter_by(ong_id=ong_id).order_by(Campanha.criado_em.desc())
    itens = []
    for c in db.session.scalars(stmt).all():
        d = c.to_dict()
        d["mensagens_nao_lidas"] = sum(
            1 for i in c.inscricoes for m in i.mensagens if m.autor_id != ong_id and m.lida_em is None
        )
        itens.append(d)
    return jsonify(itens)


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
    turnos, itens = dados.pop("turnos", []), dados.pop("itens", [])
    c = Campanha(ong_id=usuario_id_atual(), **dados)
    db.session.add(c)
    _sincronizar_turnos(c, turnos)
    _sincronizar_itens(c, itens)
    db.session.commit()
    return jsonify(c.to_dict()), 201


def _naive_utc(dt):
    return dt.astimezone(timezone.utc).replace(tzinfo=None) if dt.tzinfo else dt


def _sincronizar_turnos(c: Campanha, lista: list[dict]) -> None:
    """Deixa os turnos da campanha iguais à lista: atualiza pelos ids, cria os novos e
    remove os que sumiram (as inscrições desses turnos ficam sem turno)."""
    existentes = {t.id: t for t in c.turnos}
    manter = set()
    for d in lista:
        t = existentes.get(d.get("id")) if d.get("id") else None
        if t is None:
            t = Turno()
            c.turnos.append(t)
        else:
            manter.add(t.id)
        t.inicio, t.fim, t.vagas = _naive_utc(d["inicio"]), _naive_utc(d["fim"]), d["vagas"]
    for tid, t in existentes.items():
        if tid not in manter:
            for i in list(t.inscricoes):
                i.turno = None
            c.turnos.remove(t)


def _sincronizar_itens(c: Campanha, lista: list[dict]) -> None:
    existentes = {i.id: i for i in c.itens}
    manter = set()
    for d in lista:
        item = existentes.get(d.get("id")) if d.get("id") else None
        if item is None:
            item = ItemDoacao()
            c.itens.append(item)
        else:
            manter.add(item.id)
        item.nome, item.unidade, item.meta = d["nome"].strip(), d.get("unidade") or "un", d["meta"]
        item.arrecadado = d.get("arrecadado", item.arrecadado or 0)
    for iid, item in existentes.items():
        if iid not in manter:
            c.itens.remove(item)


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
    if "turnos" in dados:
        _sincronizar_turnos(c, dados.pop("turnos"))
    if "itens" in dados:
        _sincronizar_itens(c, dados.pop("itens"))
    for campo, valor in dados.items():
        setattr(c, campo, valor)
    db.session.commit()
    return jsonify(c.to_dict())


@bp.patch("/itens/<int:item_id>")
@papel_requerido(ONG)
def atualizar_item(item_id: int):
    """A ONG registra quanto já arrecadou de um item."""
    item = db.session.get(ItemDoacao, item_id)
    if not item or item.campanha.ong_id != usuario_id_atual():
        return erro("Item não encontrado.", 404)
    dados, err = validar(AtualizarItemSchema(), request.get_json(silent=True))
    if err:
        return err
    item.arrecadado = dados["arrecadado"]
    db.session.commit()
    return jsonify(item.to_dict())


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
        return jsonify(existente.to_dict(leitor_id=vol_id)), 200
    dados, err = validar(InscreverSchema(), request.get_json(silent=True))
    if err:
        return err

    turno = None
    abertos = [t for t in c.turnos if not t.encerrado()]
    if abertos:
        # campanha com turnos: o voluntário escolhe um com vaga
        turno = next((t for t in abertos if t.id == dados.get("turno_id")), None)
        if turno is None:
            return erro("Escolha um dos turnos disponíveis.", 422)
        if turno.ocupadas >= turno.vagas:
            return erro("Este turno já está lotado. Escolha outro.", 409)

    insc = Inscricao(campanha_id=campanha_id, voluntario_id=vol_id, status=STATUS_PENDENTE, turno=turno)
    db.session.add(insc)
    # Abre a conversa com a ONG já com a primeira mensagem
    texto = f'Olá! Quero ajudar na campanha "{c.titulo}".'
    if turno:
        texto += " Escolhi o turno indicado na inscrição."
    insc.mensagens.append(Mensagem(autor_id=vol_id, texto=texto))
    db.session.commit()
    return jsonify(insc.to_dict(leitor_id=vol_id)), 201


@bp.get("/<int:campanha_id>/inscricoes")
@papel_requerido(ONG)
def inscritos(campanha_id: int):
    """Gerenciar Voluntários Inscritos."""
    c, err = _campanha_da_ong(campanha_id)
    if err:
        return err
    lista = sorted(c.inscricoes, key=lambda i: i.criado_em, reverse=True)
    return jsonify([i.to_dict(incluir_campanha=False, incluir_voluntario=True, leitor_id=c.ong_id) for i in lista])


# ---------- Comentários ----------

@bp.get("/<int:campanha_id>/comentarios")
@jwt_required()
def listar_comentarios(campanha_id: int):
    """Comentários da campanha, do mais antigo para o mais novo."""
    c = db.session.get(Campanha, campanha_id)
    if not c:
        return erro("Campanha não encontrada.", 404)
    uid = usuario_id_atual()
    return jsonify([cm.to_dict(usuario_logado=uid) for cm in c.comentarios])


@bp.post("/<int:campanha_id>/comentarios")
@jwt_required()
def comentar(campanha_id: int):
    """Voluntários comentam em qualquer campanha; a ONG só nas próprias (para responder)."""
    c = db.session.get(Campanha, campanha_id)
    if not c:
        return erro("Campanha não encontrada.", 404)
    uid = usuario_id_atual()
    if papel_atual() == PAPEL_ONG and c.ong_id != uid:
        return erro("A ONG só pode comentar nas próprias campanhas.", 403)
    dados, err = validar(ComentarioSchema(), request.get_json(silent=True))
    if err:
        return err
    texto = dados["texto"].strip()
    if not texto:
        return erro("Escreva um comentário.", 400)
    cm = Comentario(campanha_id=campanha_id, usuario_id=uid, texto=texto)
    db.session.add(cm)
    db.session.commit()
    return jsonify(cm.to_dict(usuario_logado=uid)), 201


@bp.delete("/comentarios/<int:comentario_id>")
@jwt_required()
def apagar_comentario(comentario_id: int):
    """Apaga: o autor do comentário ou a ONG dona da campanha."""
    cm = db.session.get(Comentario, comentario_id)
    if not cm:
        return erro("Comentário não encontrado.", 404)
    uid = usuario_id_atual()
    if uid not in (cm.usuario_id, cm.campanha.ong_id):
        return erro("Você não pode apagar este comentário.", 403)
    db.session.delete(cm)
    db.session.commit()
    return jsonify({"ok": True})
