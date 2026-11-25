"""Modelo de dados do ONG Mais (ver ONG_MAIS_ESPECIFICACAO.md, seção "Modelo de dados")."""
import math
from datetime import datetime, timezone

from sqlalchemy import JSON, Boolean, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.mysql import MEDIUMTEXT
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .extensions import db

PAPEL_ONG = "ONG"
PAPEL_VOLUNTARIO = "VOLUNTARIO"

TIPOS_CAMPANHA = ("VOLUNTARIADO", "DOACAO", "FINANCEIRO")
from .catalogo import CATEGORIAS as CATEGORIAS_ONG  # noqa: E402  (Animais, Educação, ...)

STATUS_PENDENTE = "PENDENTE"
STATUS_APROVADO = "APROVADO"
STATUS_CONCLUIDO = "CONCLUIDO"
STATUS_RECUSADO = "RECUSADO"
STATUS_INSCRICAO = (STATUS_PENDENTE, STATUS_APROVADO, STATUS_CONCLUIDO, STATUS_RECUSADO)


# Texto grande (Base64): TEXT no SQLite, MEDIUMTEXT (16 MB) no MySQL
BigText = Text().with_variant(MEDIUMTEXT, "mysql")


def utcnow() -> datetime:
    """Servidor sempre grava UTC; o app converte para o fuso local."""
    return datetime.now(timezone.utc)


def iso_utc(dt: datetime | None) -> str | None:
    """Serializa com sufixo 'Z' para o Dart interpretar como UTC."""
    if dt is None:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


class Usuario(db.Model):
    __tablename__ = "tb_usuarios"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    email: Mapped[str] = mapped_column(String(180), unique=True, nullable=False, index=True)
    senha_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    papel: Mapped[str] = mapped_column(String(20), nullable=False)  # ONG | VOLUNTARIO
    criado_em: Mapped[datetime] = mapped_column(DateTime, default=utcnow, nullable=False)

    ong: Mapped["Ong | None"] = relationship(back_populates="usuario", uselist=False, cascade="all, delete-orphan")
    voluntario: Mapped["Voluntario | None"] = relationship(
        back_populates="usuario", uselist=False, cascade="all, delete-orphan"
    )


class Ong(db.Model):
    __tablename__ = "tb_ongs"

    id: Mapped[int] = mapped_column(ForeignKey("tb_usuarios.id", ondelete="CASCADE"), primary_key=True)
    nome_fantasia: Mapped[str] = mapped_column(String(150), nullable=False)
    cnpj: Mapped[str] = mapped_column(String(18), nullable=False, unique=True)
    categoria: Mapped[str] = mapped_column(String(40), nullable=False)
    whatsapp: Mapped[str] = mapped_column(String(20), nullable=False)
    endereco: Mapped[str | None] = mapped_column(String(255))
    latitude: Mapped[float | None] = mapped_column(Float)
    longitude: Mapped[float | None] = mapped_column(Float)
    descricao: Mapped[str | None] = mapped_column(Text)
    logo_base64: Mapped[str | None] = mapped_column(BigText)
    # Áreas de atuação dentro da categoria (ex.: Animais -> Adoção, Resgate de animais)
    areas_atuacao: Mapped[list | None] = mapped_column(JSON, default=list)
    chave_pix: Mapped[str | None] = mapped_column(String(120))  # mostrada em campanhas financeiras

    usuario: Mapped[Usuario] = relationship(back_populates="ong")
    campanhas: Mapped[list["Campanha"]] = relationship(back_populates="ong", cascade="all, delete-orphan")

    def to_dict(self, incluir_logo: bool = True) -> dict:
        return {
            "id": self.id,
            "email": self.usuario.email if self.usuario else None,
            "nome_fantasia": self.nome_fantasia,
            "cnpj": self.cnpj,
            "categoria": self.categoria,
            "areas_atuacao": self.areas_atuacao or [],
            "chave_pix": self.chave_pix,
            "whatsapp": self.whatsapp,
            "endereco": self.endereco,
            "latitude": self.latitude,
            "longitude": self.longitude,
            "descricao": self.descricao,
            "logo_base64": self.logo_base64 if incluir_logo else None,
            "campanhas_ativas": sum(1 for c in self.campanhas if c.ativa),
        }


class Voluntario(db.Model):
    __tablename__ = "tb_voluntarios"

    id: Mapped[int] = mapped_column(ForeignKey("tb_usuarios.id", ondelete="CASCADE"), primary_key=True)
    nome_completo: Mapped[str] = mapped_column(String(150), nullable=False)
    interesses: Mapped[list | None] = mapped_column(JSON, default=list)
    horas_trabalhadas: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    foto_base64: Mapped[str | None] = mapped_column(BigText)  # foto de perfil (opcional)

    usuario: Mapped[Usuario] = relationship(back_populates="voluntario")
    inscricoes: Mapped[list["Inscricao"]] = relationship(back_populates="voluntario", cascade="all, delete-orphan")

    def to_dict(self, publico: bool = False) -> dict:
        """publico=True: visto por outro voluntário (sem e-mail)."""
        acoes_apoiadas = sum(1 for i in self.inscricoes if i.status in (STATUS_APROVADO, STATUS_CONCLUIDO))
        return {
            "id": self.id,
            "email": None if publico else (self.usuario.email if self.usuario else None),
            "nome_completo": self.nome_completo,
            "interesses": self.interesses or [],
            "foto_base64": self.foto_base64,
            "horas_trabalhadas": self.horas_trabalhadas,
            "acoes_apoiadas": acoes_apoiadas,
            "membro_desde": iso_utc(self.usuario.criado_em) if self.usuario else None,
        }


class Campanha(db.Model):
    __tablename__ = "tb_campanhas"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    ong_id: Mapped[int] = mapped_column(ForeignKey("tb_ongs.id", ondelete="CASCADE"), nullable=False, index=True)
    tipo: Mapped[str] = mapped_column(String(20), nullable=False)  # VOLUNTARIADO | DOACAO | FINANCEIRO
    titulo: Mapped[str] = mapped_column(String(150), nullable=False)
    descricao: Mapped[str | None] = mapped_column(Text)
    foto_base64: Mapped[str | None] = mapped_column(BigText)
    criado_em: Mapped[datetime] = mapped_column(DateTime, default=utcnow, nullable=False)
    ativa: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    ong: Mapped[Ong] = relationship(back_populates="campanhas")
    inscricoes: Mapped[list["Inscricao"]] = relationship(back_populates="campanha", cascade="all, delete-orphan")
    curtidas: Mapped[list["Curtida"]] = relationship(back_populates="campanha", cascade="all, delete-orphan")
    comentarios: Mapped[list["Comentario"]] = relationship(
        back_populates="campanha", cascade="all, delete-orphan", order_by="Comentario.criado_em"
    )
    turnos: Mapped[list["Turno"]] = relationship(
        back_populates="campanha", cascade="all, delete-orphan", order_by="Turno.inicio"
    )
    itens: Mapped[list["ItemDoacao"]] = relationship(
        back_populates="campanha", cascade="all, delete-orphan", order_by="ItemDoacao.id"
    )

    def to_dict(self, voluntario_id: int | None = None, incluir_foto: bool = True) -> dict:
        minha_inscricao = None
        curtiu = False
        if voluntario_id is not None:
            for i in self.inscricoes:
                if i.voluntario_id == voluntario_id:
                    minha_inscricao = i.to_dict(incluir_campanha=False)
                    break
            curtiu = any(c.voluntario_id == voluntario_id for c in self.curtidas)
        return {
            "id": self.id,
            "ong_id": self.ong_id,
            "ong_nome": self.ong.nome_fantasia if self.ong else None,
            "ong_logo_base64": self.ong.logo_base64 if self.ong else None,
            "ong_whatsapp": self.ong.whatsapp if self.ong else None,
            "ong_categoria": self.ong.categoria if self.ong else None,
            "ong_areas_atuacao": (self.ong.areas_atuacao or []) if self.ong else [],
            "tipo": self.tipo,
            "titulo": self.titulo,
            "descricao": self.descricao,
            "foto_base64": self.foto_base64 if incluir_foto else None,
            "criado_em": iso_utc(self.criado_em),
            "ativa": self.ativa,
            "curtidas": len(self.curtidas),
            "curtiu": curtiu,
            "inscritos": len(self.inscricoes),
            "comentarios": len(self.comentarios),
            "minha_inscricao": minha_inscricao,
            "ong_chave_pix": self.ong.chave_pix if self.ong else None,
            "turnos": [t.to_dict() for t in self.turnos],
            "itens": [i.to_dict() for i in self.itens],
        }


class Inscricao(db.Model):
    __tablename__ = "tb_inscricoes"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    campanha_id: Mapped[int] = mapped_column(
        ForeignKey("tb_campanhas.id", ondelete="CASCADE"), nullable=False, index=True
    )
    voluntario_id: Mapped[int] = mapped_column(
        ForeignKey("tb_voluntarios.id", ondelete="CASCADE"), nullable=False, index=True
    )
    status: Mapped[str] = mapped_column(String(20), default=STATUS_PENDENTE, nullable=False)
    horas: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    criado_em: Mapped[datetime] = mapped_column(DateTime, default=utcnow, nullable=False)
    turno_id: Mapped[int | None] = mapped_column(ForeignKey("tb_turnos.id", ondelete="SET NULL"), index=True)

    campanha: Mapped[Campanha] = relationship(back_populates="inscricoes")
    voluntario: Mapped[Voluntario] = relationship(back_populates="inscricoes")
    turno: Mapped["Turno | None"] = relationship(back_populates="inscricoes")
    mensagens: Mapped[list["Mensagem"]] = relationship(
        back_populates="inscricao", cascade="all, delete-orphan", order_by="Mensagem.criado_em"
    )

    __table_args__ = (db.UniqueConstraint("campanha_id", "voluntario_id", name="uq_inscricao_campanha_voluntario"),)

    def to_dict(self, incluir_campanha: bool = True, incluir_voluntario: bool = False, leitor_id: int | None = None) -> dict:
        d = {
            "id": self.id,
            "campanha_id": self.campanha_id,
            "voluntario_id": self.voluntario_id,
            "status": self.status,
            "horas": self.horas,
            "criado_em": iso_utc(self.criado_em),
            "turno": self.turno.to_dict(com_ocupacao=False) if self.turno else None,
        }
        if leitor_id is not None:
            # conversa: não lidas para quem está vendo + prévia da última mensagem
            d["mensagens_nao_lidas"] = sum(1 for m in self.mensagens if m.autor_id != leitor_id and m.lida_em is None)
            ultima = self.mensagens[-1] if self.mensagens else None
            d["ultima_mensagem"] = (
                {"texto": ultima.texto, "criado_em": iso_utc(ultima.criado_em), "minha": ultima.autor_id == leitor_id}
                if ultima else None
            )
        if incluir_campanha and self.campanha:
            d["campanha_titulo"] = self.campanha.titulo
            d["campanha_tipo"] = self.campanha.tipo
            d["ong_nome"] = self.campanha.ong.nome_fantasia if self.campanha.ong else None
            d["ong_whatsapp"] = self.campanha.ong.whatsapp if self.campanha.ong else None
            d["ong_id"] = self.campanha.ong_id
            d["ong_logo_base64"] = self.campanha.ong.logo_base64 if self.campanha.ong else None
        if incluir_voluntario and self.voluntario:
            d["voluntario_nome"] = self.voluntario.nome_completo
            d["voluntario_email"] = self.voluntario.usuario.email if self.voluntario.usuario else None
            d["voluntario_interesses"] = self.voluntario.interesses or []
            d["voluntario_foto_base64"] = self.voluntario.foto_base64
        return d


class Curtida(db.Model):
    __tablename__ = "tb_curtidas"

    campanha_id: Mapped[int] = mapped_column(ForeignKey("tb_campanhas.id", ondelete="CASCADE"), primary_key=True)
    voluntario_id: Mapped[int] = mapped_column(ForeignKey("tb_voluntarios.id", ondelete="CASCADE"), primary_key=True)
    criado_em: Mapped[datetime] = mapped_column(DateTime, default=utcnow, nullable=False)

    campanha: Mapped[Campanha] = relationship(back_populates="curtidas")


class Comentario(db.Model):
    """Comentário em uma campanha. Voluntários e a ONG dona da campanha podem comentar."""

    __tablename__ = "tb_comentarios"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    campanha_id: Mapped[int] = mapped_column(
        ForeignKey("tb_campanhas.id", ondelete="CASCADE"), nullable=False, index=True
    )
    usuario_id: Mapped[int] = mapped_column(ForeignKey("tb_usuarios.id", ondelete="CASCADE"), nullable=False, index=True)
    texto: Mapped[str] = mapped_column(Text, nullable=False)
    criado_em: Mapped[datetime] = mapped_column(DateTime, default=utcnow, nullable=False)

    campanha: Mapped[Campanha] = relationship(back_populates="comentarios")
    usuario: Mapped[Usuario] = relationship()

    def autor_nome(self) -> str:
        u = self.usuario
        if u is None:
            return "Usuário"
        if u.papel == PAPEL_ONG and u.ong:
            return u.ong.nome_fantasia
        if u.voluntario:
            return u.voluntario.nome_completo
        return u.email

    def to_dict(self, usuario_logado: int | None = None) -> dict:
        u = self.usuario
        dono_campanha = self.campanha.ong_id if self.campanha else None
        return {
            "id": self.id,
            "campanha_id": self.campanha_id,
            "usuario_id": self.usuario_id,
            "autor_nome": self.autor_nome(),
            "autor_papel": u.papel if u else None,
            "autor_logo_base64": u.ong.logo_base64 if u and u.papel == PAPEL_ONG and u.ong else None,
            "autor_foto_base64": u.voluntario.foto_base64 if u and u.papel != PAPEL_ONG and u.voluntario else None,
            "texto": self.texto,
            "criado_em": iso_utc(self.criado_em),
            # pode apagar: o autor ou a ONG dona da campanha (moderação)
            "pode_apagar": usuario_logado is not None and usuario_logado in (self.usuario_id, dono_campanha),
        }


class Turno(db.Model):
    """Turno de uma campanha de voluntariado: data/horário e número de vagas."""

    __tablename__ = "tb_turnos"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    campanha_id: Mapped[int] = mapped_column(ForeignKey("tb_campanhas.id", ondelete="CASCADE"), nullable=False, index=True)
    inicio: Mapped[datetime] = mapped_column(DateTime, nullable=False)  # UTC
    fim: Mapped[datetime] = mapped_column(DateTime, nullable=False)  # UTC
    vagas: Mapped[int] = mapped_column(Integer, nullable=False)

    campanha: Mapped[Campanha] = relationship(back_populates="turnos")
    inscricoes: Mapped[list[Inscricao]] = relationship(back_populates="turno")

    @property
    def ocupadas(self) -> int:
        return sum(1 for i in self.inscricoes if i.status != STATUS_RECUSADO)

    @property
    def horas(self) -> int:
        """Duração arredondada para cima (2h30 -> 3h), usada ao concluir a participação."""
        return max(1, math.ceil((self.fim - self.inicio).total_seconds() / 3600))

    def encerrado(self, agora: datetime | None = None) -> bool:
        agora = (agora or utcnow()).replace(tzinfo=None)
        return self.fim.replace(tzinfo=None) <= agora

    def to_dict(self, com_ocupacao: bool = True) -> dict:
        d = {"id": self.id, "inicio": iso_utc(self.inicio), "fim": iso_utc(self.fim), "vagas": self.vagas, "horas": self.horas}
        if com_ocupacao:
            d["ocupadas"] = self.ocupadas
            d["encerrado"] = self.encerrado()
        return d


class Mensagem(db.Model):
    """Conversa entre voluntário e ONG dentro de uma inscrição."""

    __tablename__ = "tb_mensagens"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    inscricao_id: Mapped[int] = mapped_column(ForeignKey("tb_inscricoes.id", ondelete="CASCADE"), nullable=False, index=True)
    autor_id: Mapped[int] = mapped_column(ForeignKey("tb_usuarios.id", ondelete="CASCADE"), nullable=False)
    texto: Mapped[str] = mapped_column(Text, nullable=False)
    criado_em: Mapped[datetime] = mapped_column(DateTime, default=utcnow, nullable=False)
    lida_em: Mapped[datetime | None] = mapped_column(DateTime)

    inscricao: Mapped[Inscricao] = relationship(back_populates="mensagens")

    def to_dict(self, leitor_id: int | None = None) -> dict:
        return {
            "id": self.id,
            "inscricao_id": self.inscricao_id,
            "autor_id": self.autor_id,
            "texto": self.texto,
            "criado_em": iso_utc(self.criado_em),
            "lida": self.lida_em is not None,
            "minha": leitor_id is not None and self.autor_id == leitor_id,
        }


class ItemDoacao(db.Model):
    """Item que uma campanha de doação precisa, com meta e quanto já foi arrecadado."""

    __tablename__ = "tb_itens_doacao"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    campanha_id: Mapped[int] = mapped_column(ForeignKey("tb_campanhas.id", ondelete="CASCADE"), nullable=False, index=True)
    nome: Mapped[str] = mapped_column(String(80), nullable=False)
    unidade: Mapped[str] = mapped_column(String(20), nullable=False, default="un")
    meta: Mapped[float] = mapped_column(Float, nullable=False)
    arrecadado: Mapped[float] = mapped_column(Float, nullable=False, default=0)

    campanha: Mapped[Campanha] = relationship(back_populates="itens")

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "nome": self.nome,
            "unidade": self.unidade,
            "meta": self.meta,
            "arrecadado": self.arrecadado,
            "percentual": min(100, round(100 * self.arrecadado / self.meta)) if self.meta else 0,
        }
