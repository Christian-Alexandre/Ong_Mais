"""Modelo de dados do ONG Mais (ver ONG_MAIS_ESPECIFICACAO.md, seção "Modelo de dados")."""
from datetime import datetime, timezone

from sqlalchemy import JSON, Boolean, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.mysql import MEDIUMTEXT
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .extensions import db

PAPEL_ONG = "ONG"
PAPEL_VOLUNTARIO = "VOLUNTARIO"

TIPOS_CAMPANHA = ("VOLUNTARIADO", "DOACAO", "FINANCEIRO")
CATEGORIAS_ONG = ("Animais", "Educação", "Alimentação", "Saúde", "Meio Ambiente", "Outros")

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

    usuario: Mapped[Usuario] = relationship(back_populates="ong")
    campanhas: Mapped[list["Campanha"]] = relationship(back_populates="ong", cascade="all, delete-orphan")

    def to_dict(self, incluir_logo: bool = True) -> dict:
        return {
            "id": self.id,
            "email": self.usuario.email if self.usuario else None,
            "nome_fantasia": self.nome_fantasia,
            "cnpj": self.cnpj,
            "categoria": self.categoria,
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

    usuario: Mapped[Usuario] = relationship(back_populates="voluntario")
    inscricoes: Mapped[list["Inscricao"]] = relationship(back_populates="voluntario", cascade="all, delete-orphan")

    def to_dict(self) -> dict:
        acoes_apoiadas = sum(1 for i in self.inscricoes if i.status in (STATUS_APROVADO, STATUS_CONCLUIDO))
        return {
            "id": self.id,
            "email": self.usuario.email if self.usuario else None,
            "nome_completo": self.nome_completo,
            "interesses": self.interesses or [],
            "horas_trabalhadas": self.horas_trabalhadas,
            "acoes_apoiadas": acoes_apoiadas,
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
            "tipo": self.tipo,
            "titulo": self.titulo,
            "descricao": self.descricao,
            "foto_base64": self.foto_base64 if incluir_foto else None,
            "criado_em": iso_utc(self.criado_em),
            "ativa": self.ativa,
            "curtidas": len(self.curtidas),
            "curtiu": curtiu,
            "inscritos": len(self.inscricoes),
            "minha_inscricao": minha_inscricao,
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

    campanha: Mapped[Campanha] = relationship(back_populates="inscricoes")
    voluntario: Mapped[Voluntario] = relationship(back_populates="inscricoes")

    __table_args__ = (db.UniqueConstraint("campanha_id", "voluntario_id", name="uq_inscricao_campanha_voluntario"),)

    def to_dict(self, incluir_campanha: bool = True, incluir_voluntario: bool = False) -> dict:
        d = {
            "id": self.id,
            "campanha_id": self.campanha_id,
            "voluntario_id": self.voluntario_id,
            "status": self.status,
            "horas": self.horas,
            "criado_em": iso_utc(self.criado_em),
        }
        if incluir_campanha and self.campanha:
            d["campanha_titulo"] = self.campanha.titulo
            d["campanha_tipo"] = self.campanha.tipo
            d["ong_nome"] = self.campanha.ong.nome_fantasia if self.campanha.ong else None
            d["ong_whatsapp"] = self.campanha.ong.whatsapp if self.campanha.ong else None
        if incluir_voluntario and self.voluntario:
            d["voluntario_nome"] = self.voluntario.nome_completo
            d["voluntario_email"] = self.voluntario.usuario.email if self.voluntario.usuario else None
            d["voluntario_interesses"] = self.voluntario.interesses or []
        return d


class Curtida(db.Model):
    __tablename__ = "tb_curtidas"

    campanha_id: Mapped[int] = mapped_column(ForeignKey("tb_campanhas.id", ondelete="CASCADE"), primary_key=True)
    voluntario_id: Mapped[int] = mapped_column(ForeignKey("tb_voluntarios.id", ondelete="CASCADE"), primary_key=True)
    criado_em: Mapped[datetime] = mapped_column(DateTime, default=utcnow, nullable=False)

    campanha: Mapped[Campanha] = relationship(back_populates="curtidas")
