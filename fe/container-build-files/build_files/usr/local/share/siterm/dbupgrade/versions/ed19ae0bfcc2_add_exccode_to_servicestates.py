"""add exccode to servicestates

Refs sdn-sense/siterm#1000

Revision ID: ed19ae0bfcc2
Revises:
Create Date: 2026-08-26

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "ed19ae0bfcc2"
down_revision: Union[str, Sequence[str], None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TABLE = "servicestates"
COLUMN = "exccode"


def _has_column(bind, table, column) -> bool:
    inspector = sa.inspect(bind)
    return any(col["name"] == column for col in inspector.get_columns(table))


def upgrade() -> None:
    """Add the exccode column if it isn't already present.

    Runs both against installs where the table predates this column, and
    against fresh installs where createdb() already created the column via
    the current ORM model (Base.metadata.create_all() runs before this) --
    the check keeps both paths a no-op after the first successful apply.
    """
    bind = op.get_bind()
    if not _has_column(bind, TABLE, COLUMN):
        op.add_column(
            TABLE,
            sa.Column(COLUMN, sa.Integer(), nullable=False, server_default="-100"),
        )


def downgrade() -> None:
    bind = op.get_bind()
    if _has_column(bind, TABLE, COLUMN):
        op.drop_column(TABLE, COLUMN)
