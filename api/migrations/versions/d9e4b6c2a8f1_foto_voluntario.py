"""foto de perfil do voluntario

Revision ID: d9e4b6c2a8f1
Revises: c5d2f8a1e3b7
Create Date: 2026-11-25 00:30:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import mysql

# revision identifiers, used by Alembic.
revision = 'd9e4b6c2a8f1'
down_revision = 'c5d2f8a1e3b7'
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table('tb_voluntarios', schema=None) as batch_op:
        batch_op.add_column(sa.Column('foto_base64', sa.Text().with_variant(mysql.MEDIUMTEXT(), 'mysql'), nullable=True))


def downgrade():
    with op.batch_alter_table('tb_voluntarios', schema=None) as batch_op:
        batch_op.drop_column('foto_base64')
