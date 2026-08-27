"""add exccodes to servicestates

A WARNING state can batch several distinct causes together (see
SiteRMLibs.Warnings.checkAndRaiseWarnings). exccode (added in
ed19ae0bfcc2) only ever holds the first/primary code; this column holds
the full list reported that cycle, in first-seen order.

Refs sdn-sense/siterm exccodes follow-up to #1000

Revision ID: e4230cde706c
Revises: ed19ae0bfcc2
Create Date: 2026-08-26

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "e4230cde706c"
down_revision: Union[str, Sequence[str], None] = "ed19ae0bfcc2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TABLE = "servicestates"
COLUMN = "exccodes"


def _has_column(bind, table, column) -> bool:
    inspector = sa.inspect(bind)
    return any(col["name"] == column for col in inspector.get_columns(table))


def upgrade() -> None:
    """Add the exccodes column if it isn't already present.

    Nullable, no default: unlike exccode this doesn't need a backfill
    value -- existing rows simply have NULL until their next report.
    """
    bind = op.get_bind()
    if not _has_column(bind, TABLE, COLUMN):
        op.add_column(TABLE, sa.Column(COLUMN, sa.JSON(), nullable=True))


def downgrade() -> None:
    bind = op.get_bind()
    if _has_column(bind, TABLE, COLUMN):
        op.drop_column(TABLE, COLUMN)
