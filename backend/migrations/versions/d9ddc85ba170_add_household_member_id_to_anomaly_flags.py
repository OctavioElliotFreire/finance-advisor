"""add household_member_id to anomaly_flags

Revision ID: d9ddc85ba170
Revises: f08e50848c8c
Create Date: 2026-08-11 08:36:45.483039

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd9ddc85ba170'
down_revision: Union[str, Sequence[str], None] = 'f08e50848c8c'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column('anomaly_flags', sa.Column('household_member_id', sa.UUID(), nullable=True))
    op.create_foreign_key(
        'fk_anomaly_flags_household_member_id',
        'anomaly_flags', 'household_members', ['household_member_id'], ['id'],
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_constraint(
        'fk_anomaly_flags_household_member_id',
        'anomaly_flags', type_='foreignkey',
    )
    op.drop_column('anomaly_flags', 'household_member_id')
