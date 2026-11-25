from flask import Blueprint, jsonify, request
from flask_jwt_extended import create_access_token, jwt_required

from ..extensions import bcrypt, db
from ..models import PAPEL_ONG, PAPEL_VOLUNTARIO, Ong, Usuario, Voluntario
from ..catalogo import areas_validas, normalizar_telefone
from ..schemas import CadastroOngSchema, CadastroVoluntarioSchema, LoginSchema, formatar_cnpj
from ..services.geocoding import geocodificar
from ..utils import erro, usuario_id_atual, validar

bp = Blueprint("auth", __name__, url_prefix="/auth")


def _resposta_login(usuario: Usuario):
    token = create_access_token(identity=str(usuario.id), additional_claims={"papel": usuario.papel})
    perfil = usuario.ong.to_dict() if usuario.papel == PAPEL_ONG else usuario.voluntario.to_dict()
    return jsonify({"access_token": token, "papel": usuario.papel, "perfil": perfil})


@bp.post("/login")
def login():
    dados, err = validar(LoginSchema(), request.get_json(silent=True))
    if err:
        return err
    usuario = db.session.scalar(db.select(Usuario).filter_by(email=dados["email"].lower().strip()))
    if not usuario or not bcrypt.check_password_hash(usuario.senha_hash, dados["senha"]):
        return erro("E-mail ou senha inválidos.", 401)
    return _resposta_login(usuario)


def _limpar_interesses(lista) -> list[str]:
    vistos: list[str] = []
    for i in lista or []:
        i = (i or "").strip()
        if i and i not in vistos:
            vistos.append(i)
    return vistos


@bp.post("/registro/voluntario")
def registro_voluntario():
    dados, err = validar(CadastroVoluntarioSchema(), request.get_json(silent=True))
    if err:
        return err
    email = dados["email"].lower().strip()
    if db.session.scalar(db.select(Usuario).filter_by(email=email)):
        return erro("Já existe uma conta com este e-mail.", 409)

    usuario = Usuario(
        email=email,
        senha_hash=bcrypt.generate_password_hash(dados["senha"]).decode("utf-8"),
        papel=PAPEL_VOLUNTARIO,
    )
    usuario.voluntario = Voluntario(
        nome_completo=dados["nome_completo"].strip(),
        interesses=_limpar_interesses(dados.get("interesses")),
        foto_base64=dados.get("foto_base64") or None,
        horas_trabalhadas=0,
    )
    db.session.add(usuario)
    db.session.commit()
    return _resposta_login(usuario), 201


@bp.post("/registro/ong")
def registro_ong():
    dados, err = validar(CadastroOngSchema(), request.get_json(silent=True))
    if err:
        return err
    email = dados["email"].lower().strip()
    if db.session.scalar(db.select(Usuario).filter_by(email=email)):
        return erro("Já existe uma conta com este e-mail.", 409)
    cnpj = formatar_cnpj(dados["cnpj"])
    if db.session.scalar(db.select(Ong).filter_by(cnpj=cnpj)):
        return erro("Já existe uma ONG com este CNPJ.", 409)

    lat, lng = dados.get("latitude"), dados.get("longitude")
    if (lat is None or lng is None) and dados.get("endereco"):
        # Sem captura de GPS: tenta geocodificar o endereço digitado
        lat, lng = geocodificar(dados["endereco"])

    usuario = Usuario(
        email=email,
        senha_hash=bcrypt.generate_password_hash(dados["senha"]).decode("utf-8"),
        papel=PAPEL_ONG,
    )
    usuario.ong = Ong(
        nome_fantasia=dados["nome_fantasia"].strip(),
        cnpj=cnpj,
        categoria=dados["categoria"],
        whatsapp=normalizar_telefone(dados["whatsapp"]),
        areas_atuacao=areas_validas(dados["categoria"], dados.get("areas_atuacao"))[0],
        endereco=dados.get("endereco"),
        latitude=lat,
        longitude=lng,
        descricao=dados.get("descricao"),
        logo_base64=dados.get("logo_base64"),
    )
    db.session.add(usuario)
    db.session.commit()
    return _resposta_login(usuario), 201


@bp.get("/me")
@jwt_required()
def me():
    usuario = db.session.get(Usuario, usuario_id_atual())
    if not usuario:
        return erro("Usuário não encontrado.", 404)
    perfil = usuario.ong.to_dict() if usuario.papel == PAPEL_ONG else usuario.voluntario.to_dict()
    return jsonify({"papel": usuario.papel, "perfil": perfil})
