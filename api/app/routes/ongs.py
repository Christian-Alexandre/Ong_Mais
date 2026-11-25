from collections import Counter
from datetime import timedelta

from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required

from ..extensions import db
from ..catalogo import areas_validas, normalizar_telefone
from ..models import STATUS_INSCRICAO, Campanha, Ong, utcnow
from ..schemas import AtualizarOngSchema
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
    categoria = dados.get("categoria", ong.categoria)
    areas = dados.pop("areas_atuacao", None)
    if areas is not None:
        aceitas, invalidas = areas_validas(categoria, areas)
        if invalidas:
            return erro(f"Áreas que não pertencem a {categoria}: {', '.join(invalidas)}.", 422)
        ong.areas_atuacao = aceitas
    elif categoria != ong.categoria:
        # Trocou a causa sem mandar áreas: mantém só as que valem para a nova categoria
        ong.areas_atuacao = areas_validas(categoria, ong.areas_atuacao)[0]

    for campo, valor in dados.items():
        if campo == "whatsapp":
            valor = normalizar_telefone(valor)
        setattr(ong, campo, valor)

    if endereco_mudou and "latitude" not in dados and ong.endereco:
        lat, lng = geocodificar(ong.endereco)
        if lat is not None:
            ong.latitude, ong.longitude = lat, lng

    db.session.commit()
    return jsonify(ong.to_dict())


SEMANAS_ATIVIDADE = 8


@bp.get("/me/impacto")
@papel_requerido(ONG)
def impacto():
    """Números de impacto da ONG: alcance, funil de inscrições, horas doadas,
    campanhas que mais engajam, atividade semanal e o que os voluntários curtem."""
    ong = db.session.get(Ong, usuario_id_atual())
    if not ong:
        return erro("ONG não encontrada.", 404)
    campanhas: list[Campanha] = list(ong.campanhas)
    inscricoes = [i for c in campanhas for i in c.inscricoes]
    curtidas = [ct for c in campanhas for ct in c.curtidas]
    # comentários dos voluntários (as respostas da própria ONG não contam como engajamento)
    comentarios = [cm for c in campanhas for cm in c.comentarios if cm.usuario_id != ong.id]

    status = Counter(i.status for i in inscricoes)
    voluntarios = {i.voluntario_id for i in inscricoes}
    horas = sum(i.horas or 0 for i in inscricoes if i.status == "CONCLUIDO")
    decididas = status["APROVADO"] + status["CONCLUIDO"] + status["RECUSADO"]

    por_campanha = []
    for c in campanhas:
        n_coment = sum(1 for cm in c.comentarios if cm.usuario_id != ong.id)
        por_campanha.append(
            {
                "id": c.id,
                "titulo": c.titulo,
                "tipo": c.tipo,
                "ativa": c.ativa,
                "curtidas": len(c.curtidas),
                "comentarios": n_coment,
                "inscritos": len(c.inscricoes),
                "engajamento": len(c.curtidas) + n_coment + len(c.inscricoes),
            }
        )
    por_campanha.sort(key=lambda x: x["engajamento"], reverse=True)

    # Atividade das últimas semanas (a última barra é a semana atual)
    agora = utcnow().replace(tzinfo=None)  # o banco devolve datas UTC sem fuso
    semanas = []
    for k in range(SEMANAS_ATIVIDADE - 1, -1, -1):
        fim = agora - timedelta(days=7 * k)
        ini = fim - timedelta(days=7)
        dentro = lambda d: d is not None and ini < d.replace(tzinfo=None) <= fim  # noqa: E731
        semanas.append(
            {
                "inicio": ini.date().isoformat(),
                "inscricoes": sum(1 for i in inscricoes if dentro(i.criado_em)),
                "comentarios": sum(1 for cm in comentarios if dentro(cm.criado_em)),
                "curtidas": sum(1 for ct in curtidas if dentro(ct.criado_em)),
            }
        )

    # Interesses mais comuns entre os voluntários que já se inscreveram
    interesses = Counter()
    for i in inscricoes:
        if i.voluntario:
            interesses.update(set(i.voluntario.interesses or []))

    return jsonify(
        {
            "campanhas_total": len(campanhas),
            "campanhas_ativas": sum(1 for c in campanhas if c.ativa),
            "voluntarios": len(voluntarios),
            "horas_doadas": horas,
            "curtidas": len(curtidas),
            "comentarios": len(comentarios),
            "inscricoes": len(inscricoes),
            "status": {s: status[s] for s in STATUS_INSCRICAO},
            "taxa_aprovacao": round(100 * (status["APROVADO"] + status["CONCLUIDO"]) / decididas) if decididas else None,
            "por_campanha": por_campanha,
            "semanas": semanas,
            "interesses_voluntarios": [{"interesse": k, "voluntarios": v} for k, v in interesses.most_common(8)],
        }
    )
