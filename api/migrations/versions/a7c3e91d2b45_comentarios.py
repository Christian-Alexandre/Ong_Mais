"""comentarios nas campanhas

Revision ID: a7c3e91d2b45
Revises: 31cf7507f679
Create Date: 2026-11-18 10:50:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = 'a7c3e91d2b45'
down_revision = '31cf7507f679'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table('tb_comentarios',
    sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
    sa.Column('campanha_id', sa.Integer(), nullable=False),
    sa.Column('usuario_id', sa.Integer(), nullable=False),
    sa.Column('texto', sa.Text(), nullable=False),
    sa.Column('criado_em', sa.DateTime(), nullable=False),
    sa.ForeignKeyConstraint(['campanha_id'], ['tb_campanhas.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['usuario_id'], ['tb_usuarios.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    with op.batch_alter_table('tb_comentarios', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_tb_comentarios_campanha_id'), ['campanha_id'], unique=False)
        batch_op.create_index(batch_op.f('ix_tb_comentarios_usuario_id'), ['usuario_id'], unique=False)


def downgrade():
    with op.batch_alter_table('tb_comentarios', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_tb_comentarios_usuario_id'))
        batch_op.drop_index(batch_op.f('ix_tb_comentarios_campanha_id'))
    op.drop_table('tb_comentarios')
