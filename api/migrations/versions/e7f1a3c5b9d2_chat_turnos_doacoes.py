"""chat, turnos com vagas, itens de doacao e chave PIX

Revision ID: e7f1a3c5b9d2
Revises: d9e4b6c2a8f1
Create Date: 2026-11-25 01:30:00.000000

"""
from datetime import datetime, timedelta, timezone

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = 'e7f1a3c5b9d2'
down_revision = 'd9e4b6c2a8f1'
branch_labels = None
depends_on = None

SEED_ONG = 'contato@patinhascarentes.org.br'


def upgrade():
    op.create_table('tb_turnos',
    sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
    sa.Column('campanha_id', sa.Integer(), nullable=False),
    sa.Column('inicio', sa.DateTime(), nullable=False),
    sa.Column('fim', sa.DateTime(), nullable=False),
    sa.Column('vagas', sa.Integer(), nullable=False),
    sa.ForeignKeyConstraint(['campanha_id'], ['tb_campanhas.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    with op.batch_alter_table('tb_turnos', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_tb_turnos_campanha_id'), ['campanha_id'], unique=False)

    op.create_table('tb_itens_doacao',
    sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
    sa.Column('campanha_id', sa.Integer(), nullable=False),
    sa.Column('nome', sa.String(length=80), nullable=False),
    sa.Column('unidade', sa.String(length=20), nullable=False),
    sa.Column('meta', sa.Float(), nullable=False),
    sa.Column('arrecadado', sa.Float(), nullable=False),
    sa.ForeignKeyConstraint(['campanha_id'], ['tb_campanhas.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    with op.batch_alter_table('tb_itens_doacao', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_tb_itens_doacao_campanha_id'), ['campanha_id'], unique=False)

    op.create_table('tb_mensagens',
    sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
    sa.Column('inscricao_id', sa.Integer(), nullable=False),
    sa.Column('autor_id', sa.Integer(), nullable=False),
    sa.Column('texto', sa.Text(), nullable=False),
    sa.Column('criado_em', sa.DateTime(), nullable=False),
    sa.Column('lida_em', sa.DateTime(), nullable=True),
    sa.ForeignKeyConstraint(['autor_id'], ['tb_usuarios.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['inscricao_id'], ['tb_inscricoes.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    with op.batch_alter_table('tb_mensagens', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_tb_mensagens_inscricao_id'), ['inscricao_id'], unique=False)

    with op.batch_alter_table('tb_inscricoes', schema=None) as batch_op:
        batch_op.add_column(sa.Column('turno_id', sa.Integer(), nullable=True))
        batch_op.create_index(batch_op.f('ix_tb_inscricoes_turno_id'), ['turno_id'], unique=False)
        batch_op.create_foreign_key('fk_inscricoes_turno', 'tb_turnos', ['turno_id'], ['id'], ondelete='SET NULL')

    with op.batch_alter_table('tb_ongs', schema=None) as batch_op:
        batch_op.add_column(sa.Column('chave_pix', sa.String(length=120), nullable=True))

    _dados_de_exemplo()


def _proximo_sabado(base: datetime, semanas: int = 0) -> datetime:
    dias = (5 - base.weekday()) % 7 or 7
    return (base + timedelta(days=dias + 7 * semanas)).replace(minute=0, second=0, microsecond=0)


def _dados_de_exemplo():
    """Contas do Teste Rápido: turnos no voluntariado, itens na doação e chave PIX."""
    con = op.get_bind()
    ong = con.execute(sa.text("SELECT id FROM tb_usuarios WHERE email = :e"), {"e": SEED_ONG}).first()
    if ong is None:
        return
    ong_id = ong[0]
    con.execute(sa.text("UPDATE tb_ongs SET chave_pix = :p WHERE id = :id"), {"p": "contato@patinhascarentes.org.br", "id": ong_id})
    agora = datetime.now(timezone.utc).replace(tzinfo=None)
    vol = con.execute(sa.text("SELECT id FROM tb_campanhas WHERE ong_id = :o AND tipo = 'VOLUNTARIADO' ORDER BY id LIMIT 1"), {"o": ong_id}).first()
    if vol is not None:
        for semanas in (0, 1):
            sab = _proximo_sabado(agora, semanas)
            # 9h-12h no horário de Brasília = 12h-15h UTC
            ini = sab.replace(hour=12)
            con.execute(
                sa.text("INSERT INTO tb_turnos (campanha_id, inicio, fim, vagas) VALUES (:c, :i, :f, :v)"),
                {"c": vol[0], "i": ini, "f": ini + timedelta(hours=3), "v": 8},
            )
    doa = con.execute(sa.text("SELECT id FROM tb_campanhas WHERE ong_id = :o AND tipo = 'DOACAO' ORDER BY id LIMIT 1"), {"o": ong_id}).first()
    if doa is not None:
        for nome, unidade, meta, arrecadado in (("Ração", "kg", 100, 40), ("Cobertores", "un", 80, 25), ("Medicamentos", "caixas", 30, 6)):
            con.execute(
                sa.text("INSERT INTO tb_itens_doacao (campanha_id, nome, unidade, meta, arrecadado) VALUES (:c, :n, :u, :m, :a)"),
                {"c": doa[0], "n": nome, "u": unidade, "m": meta, "a": arrecadado},
            )


def downgrade():
    with op.batch_alter_table('tb_ongs', schema=None) as batch_op:
        batch_op.drop_column('chave_pix')
    with op.batch_alter_table('tb_inscricoes', schema=None) as batch_op:
        batch_op.drop_constraint('fk_inscricoes_turno', type_='foreignkey')
        batch_op.drop_index(batch_op.f('ix_tb_inscricoes_turno_id'))
        batch_op.drop_column('turno_id')
    op.drop_table('tb_mensagens')
    op.drop_table('tb_itens_doacao')
    op.drop_table('tb_turnos')
