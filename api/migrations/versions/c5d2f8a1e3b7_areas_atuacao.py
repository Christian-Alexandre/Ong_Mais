"""areas de atuacao das ONGs

Revision ID: c5d2f8a1e3b7
Revises: a7c3e91d2b45
Create Date: 2026-11-24 23:30:00.000000

"""
import json

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = 'c5d2f8a1e3b7'
down_revision = 'a7c3e91d2b45'
branch_labels = None
depends_on = None

SEED_ONG = 'contato@patinhascarentes.org.br'
SEED_VOL = 'voluntario@teste.com'


def upgrade():
    with op.batch_alter_table('tb_ongs', schema=None) as batch_op:
        batch_op.add_column(sa.Column('areas_atuacao', sa.JSON(), nullable=True))

    # Contas do Teste Rápido ganham dados de exemplo para mostrar os "pontos em comum"
    con = op.get_bind()
    con.execute(
        sa.text(
            "UPDATE tb_ongs SET areas_atuacao = :areas "
            "WHERE id = (SELECT id FROM tb_usuarios WHERE email = :email)"
        ),
        {"areas": json.dumps(["Adoção", "Resgate de animais", "Cuidados veterinários"]), "email": SEED_ONG},
    )
    vol = con.execute(
        sa.text(
            "SELECT v.id, v.interesses FROM tb_voluntarios v JOIN tb_usuarios u ON u.id = v.id WHERE u.email = :email"
        ),
        {"email": SEED_VOL},
    ).first()
    if vol is not None:
        atuais = vol[1]
        if isinstance(atuais, str):
            try:
                atuais = json.loads(atuais)
            except ValueError:
                atuais = []
        if not atuais:
            con.execute(
                sa.text("UPDATE tb_voluntarios SET interesses = :i WHERE id = :id"),
                {"i": json.dumps(["Animais", "Adoção", "Lar temporário", "Educação ambiental", "Reforço escolar"]), "id": vol[0]},
            )


def downgrade():
    with op.batch_alter_table('tb_ongs', schema=None) as batch_op:
        batch_op.drop_column('areas_atuacao')
