import re
from datetime import timezone

from marshmallow import EXCLUDE, Schema, ValidationError, fields, validate, validates, validates_schema

from .catalogo import areas_validas, telefone_erro
from .models import CATEGORIAS_ONG, STATUS_INSCRICAO, TIPOS_CAMPANHA


def somente_digitos(valor: str) -> str:
    return re.sub(r"\D", "", valor or "")


def cnpj_valido(cnpj: str) -> bool:
    """Validação offline dos dígitos verificadores do CNPJ."""
    d = somente_digitos(cnpj)
    if len(d) != 14 or d == d[0] * 14:
        return False

    def dv(nums: str, pesos: list[int]) -> int:
        soma = sum(int(n) * p for n, p in zip(nums, pesos))
        resto = soma % 11
        return 0 if resto < 2 else 11 - resto

    pesos1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
    pesos2 = [6] + pesos1
    dv1 = dv(d[:12], pesos1)
    dv2 = dv(d[:12] + str(dv1), pesos2)
    return d[12:] == f"{dv1}{dv2}"


def formatar_cnpj(cnpj: str) -> str:
    d = somente_digitos(cnpj)
    return f"{d[:2]}.{d[2:5]}.{d[5:8]}/{d[8:12]}-{d[12:]}"


class LoginSchema(Schema):
    email = fields.Email(required=True)
    senha = fields.Str(required=True, validate=validate.Length(min=1))


class _SenhaMixin(Schema):
    senha = fields.Str(required=True, validate=validate.Length(min=6, error="Senha deve ter no mínimo 6 caracteres."))
    confirmar_senha = fields.Str(required=False, load_default=None)

    @validates_schema
    def senhas_conferem(self, data, **kwargs):
        if data.get("confirmar_senha") is not None and data["confirmar_senha"] != data["senha"]:
            raise ValidationError("As senhas não conferem.", field_name="confirmar_senha")


def _lista_interesses(**kw):
    return fields.List(
        fields.Str(validate=validate.Length(max=60)),
        validate=validate.Length(max=30, error="Escolha no máximo 30 interesses."),
        **kw,
    )


# Foto de perfil em Base64: até ~1,5 MB de texto (o app já envia reduzida)
_FOTO_MAX = 1_500_000


class CadastroVoluntarioSchema(_SenhaMixin):
    nome_completo = fields.Str(required=True, validate=validate.Length(min=2, max=150))
    email = fields.Email(required=True)
    interesses = _lista_interesses(load_default=list)
    foto_base64 = fields.Str(load_default=None, allow_none=True, validate=validate.Length(max=_FOTO_MAX, error="Foto muito grande."))


class CadastroOngSchema(_SenhaMixin):
    nome_fantasia = fields.Str(required=True, validate=validate.Length(min=2, max=150))
    cnpj = fields.Str(required=True)
    categoria = fields.Str(required=True, validate=validate.OneOf(CATEGORIAS_ONG))
    whatsapp = fields.Str(required=True)
    endereco = fields.Str(load_default=None, allow_none=True)
    latitude = fields.Float(load_default=None, allow_none=True)
    longitude = fields.Float(load_default=None, allow_none=True)
    descricao = fields.Str(load_default=None, allow_none=True)
    logo_base64 = fields.Str(load_default=None, allow_none=True)
    areas_atuacao = fields.List(fields.Str(), load_default=list)
    email = fields.Email(required=True)

    @validates("cnpj")
    def valida_cnpj(self, valor, **kwargs):
        if not cnpj_valido(valor):
            raise ValidationError("CNPJ inválido.")

    @validates("whatsapp")
    def valida_whatsapp(self, valor, **kwargs):
        msg = telefone_erro(valor)
        if msg:
            raise ValidationError(msg)

    @validates_schema
    def valida_areas(self, data, **kwargs):
        _, invalidas = areas_validas(data.get("categoria", ""), data.get("areas_atuacao"))
        if invalidas:
            raise ValidationError(f"Áreas que não pertencem a {data.get('categoria')}: {', '.join(invalidas)}.", field_name="areas_atuacao")


class AtualizarOngSchema(Schema):
    nome_fantasia = fields.Str(validate=validate.Length(min=2, max=150))
    chave_pix = fields.Str(allow_none=True, validate=validate.Length(max=120))
    categoria = fields.Str(validate=validate.OneOf(CATEGORIAS_ONG))
    areas_atuacao = fields.List(fields.Str())
    whatsapp = fields.Str()

    @validates("whatsapp")
    def valida_whatsapp(self, valor, **kwargs):
        msg = telefone_erro(valor)
        if msg:
            raise ValidationError(msg)

    endereco = fields.Str(allow_none=True)
    latitude = fields.Float(allow_none=True)
    longitude = fields.Float(allow_none=True)
    descricao = fields.Str(allow_none=True)
    logo_base64 = fields.Str(allow_none=True)


class AtualizarVoluntarioSchema(Schema):
    nome_completo = fields.Str(validate=validate.Length(min=2, max=150))
    interesses = _lista_interesses(allow_none=True)
    foto_base64 = fields.Str(allow_none=True, validate=validate.Length(max=_FOTO_MAX, error="Foto muito grande."))


class TurnoSchema(Schema):
    class Meta:
        unknown = EXCLUDE  # aceita o turno como a API devolve (com ocupadas, horas...)

    id = fields.Int(load_default=None, allow_none=True)
    inicio = fields.AwareDateTime(required=True, default_timezone=timezone.utc)
    fim = fields.AwareDateTime(required=True, default_timezone=timezone.utc)
    vagas = fields.Int(required=True, validate=validate.Range(min=1, max=500, error="Vagas entre 1 e 500."))

    @validates_schema
    def periodo(self, data, **kwargs):
        if data["fim"] <= data["inicio"]:
            raise ValidationError("O turno precisa terminar depois de começar.", field_name="fim")
        if (data["fim"] - data["inicio"]).total_seconds() > 24 * 3600:
            raise ValidationError("Um turno pode ter no máximo 24 horas.", field_name="fim")


class ItemDoacaoSchema(Schema):
    class Meta:
        unknown = EXCLUDE

    id = fields.Int(load_default=None, allow_none=True)
    nome = fields.Str(required=True, validate=validate.Length(min=1, max=80))
    unidade = fields.Str(load_default="un", validate=validate.Length(min=1, max=20))
    meta = fields.Float(required=True, validate=validate.Range(min=0.01, max=1_000_000, error="Meta precisa ser maior que zero."))
    arrecadado = fields.Float(load_default=0, validate=validate.Range(min=0, max=1_000_000))


class CampanhaSchema(Schema):
    tipo = fields.Str(required=True, validate=validate.OneOf(TIPOS_CAMPANHA))
    titulo = fields.Str(required=True, validate=validate.Length(min=2, max=150))
    descricao = fields.Str(load_default=None, allow_none=True)
    foto_base64 = fields.Str(load_default=None, allow_none=True)
    turnos = fields.List(fields.Nested(TurnoSchema), load_default=list, validate=validate.Length(max=30))
    itens = fields.List(fields.Nested(ItemDoacaoSchema), load_default=list, validate=validate.Length(max=30))


class AtualizarCampanhaSchema(Schema):
    tipo = fields.Str(validate=validate.OneOf(TIPOS_CAMPANHA))
    titulo = fields.Str(validate=validate.Length(min=2, max=150))
    descricao = fields.Str(allow_none=True)
    foto_base64 = fields.Str(allow_none=True)
    ativa = fields.Bool()
    turnos = fields.List(fields.Nested(TurnoSchema), validate=validate.Length(max=30))
    itens = fields.List(fields.Nested(ItemDoacaoSchema), validate=validate.Length(max=30))


class InscreverSchema(Schema):
    turno_id = fields.Int(load_default=None, allow_none=True)


class MensagemSchema(Schema):
    texto = fields.Str(required=True, validate=validate.Length(min=1, max=1000, error="A mensagem deve ter entre 1 e 1000 caracteres."))


class AtualizarItemSchema(Schema):
    arrecadado = fields.Float(required=True, validate=validate.Range(min=0, max=1_000_000))


class AtualizarInscricaoSchema(Schema):
    status = fields.Str(required=True, validate=validate.OneOf(STATUS_INSCRICAO))
    horas = fields.Int(load_default=None, allow_none=True, validate=validate.Range(min=0, max=10000))


class ComentarioSchema(Schema):
    texto = fields.Str(
        required=True,
        validate=validate.Length(min=1, max=500, error="O comentário deve ter entre 1 e 500 caracteres."),
    )
