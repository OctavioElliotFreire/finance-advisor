"""add created_by to pluggy_connections

Revision ID: ca9f891bc0f7
Revises: 552093f65de2
Create Date: 2026-07-30 19:06:43.277116

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'ca9f891bc0f7'
down_revision: Union[str, Sequence[str], None] = '552093f65de2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column('pluggy_connections', sa.Column('created_by_app_user_id', sa.UUID(), nullable=True))
    op.create_foreign_key(
        'fk_pluggy_connections_created_by_app_user_id',
        'pluggy_connections', 'app_users', ['created_by_app_user_id'], ['id'],
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_constraint(
        'fk_pluggy_connections_created_by_app_user_id',
        'pluggy_connections', type_='foreignkey',
    )
    op.drop_column('pluggy_connections', 'created_by_app_user_id')
