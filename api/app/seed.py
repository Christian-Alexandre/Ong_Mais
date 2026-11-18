"""Dados do "Teste Rápido 1-clique" (ver spec, seção Seed)."""
from .extensions import bcrypt, db
from .models import PAPEL_ONG, PAPEL_VOLUNTARIO, Campanha, Ong, Usuario, Voluntario

SEED_ONG_EMAIL = "contato@patinhascarentes.org.br"
SEED_VOL_EMAIL = "voluntario@teste.com"
SEED_SENHA = "123456"


def semear(forcar: bool = False) -> bool:
    """Cria ONG + voluntário de teste. Retorna True se semeou algo."""
    if not forcar and db.session.scalar(db.select(Usuario).filter_by(email=SEED_ONG_EMAIL)):
        return False

    senha_hash = bcrypt.generate_password_hash(SEED_SENHA).decode("utf-8")

    if not db.session.scalar(db.select(Usuario).filter_by(email=SEED_ONG_EMAIL)):
        ong_user = Usuario(email=SEED_ONG_EMAIL, senha_hash=senha_hash, papel=PAPEL_ONG)
        ong_user.ong = Ong(
            nome_fantasia="Instituto Patinhas Carentes",
            cnpj="12.345.678/0001-95",  # dígitos verificadores válidos
            categoria="Animais",
            whatsapp="11987654321",
            endereco="Av. Paulista, 1000 - Bela Vista, São Paulo - SP",
            latitude=-23.5653,
            longitude=-46.6520,
            descricao=(
                "Somos uma instituição sem fins lucrativos dedicada ao resgate, reabilitação "
                "e adoção responsável de cães e gatos em situação de vulnerabilidade e abandono."
            ),
        )
        ong_user.ong.campanhas = [
            Campanha(
                tipo="VOLUNTARIADO",
                titulo="Voluntários para Passeio e Cuidados",
                descricao=(
                    "Precisamos de voluntários aos sábados pela manhã para passear com os cães, "
                    "ajudar na limpeza dos canis e dar carinho aos animais do abrigo."
                ),
            ),
            Campanha(
                tipo="DOACAO",
                titulo="Campanha do Agasalho e Ração",
                descricao=(
                    "Estamos arrecadando cobertores e ração para os 80 animais do abrigo "
                    "enfrentarem o inverno. Entregas na sede ou combine a retirada pelo WhatsApp."
                ),
            ),
        ]
        db.session.add(ong_user)

    if not db.session.scalar(db.select(Usuario).filter_by(email=SEED_VOL_EMAIL)):
        vol_user = Usuario(email=SEED_VOL_EMAIL, senha_hash=senha_hash, papel=PAPEL_VOLUNTARIO)
        vol_user.voluntario = Voluntario(nome_completo="Lucas Silva", interesses=[], horas_trabalhadas=0)
        db.session.add(vol_user)

    db.session.commit()
    return True
