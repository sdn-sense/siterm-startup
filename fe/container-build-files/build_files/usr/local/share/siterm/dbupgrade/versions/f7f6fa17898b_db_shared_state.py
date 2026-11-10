"""keep all shared FE state in the database

SiteFE components used to hand data to each other through files under
/opt/siterm (host/service reports, debug requests, model files). Each
component can now run in its own container, so that data moves into the
database:

- hosts.hostinfo, services.serviceinfo, debugrequests.debuginfo/outputinfo
  hold the JSON content instead of a file path (LONGTEXT).
- models.fileloc is replaced by models.contentid; the serialized model is
  stored compressed in modelcontent (shared by identical models).
- New tables kvstore, leases, modelcontent, deltarequests (also created by
  create_all() in dbstart.py; created here too when the upgrade runs alone).

Existing files are inlined when this runs where they are readable (the
all-in-one container with its /opt/siterm volume). Rows whose file is gone
get empty JSON; models without readable content are dropped and rebuilt by
LookUpService on its next cycle.

Revision ID: f7f6fa17898b
Revises: e4230cde706c
Create Date: 2026-11-09

"""

import json
import time
import zlib
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.mysql import LONGTEXT
from SiteRMLibs.DBModels import Base

revision: str = "f7f6fa17898b"
down_revision: Union[str, Sequence[str], None] = "e4230cde706c"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

NEW_TABLES = ["kvstore", "leases", "modelcontent", "deltarequests"]
JSON_COLUMNS = [("hosts", "hostinfo"), ("services", "serviceinfo"), ("debugrequests", "debuginfo"), ("debugrequests", "outputinfo")]
MODEL_FORMATS = ("ntriples", "turtle", "json-ld")


def _columns(bind, table):
    """Return column names of a table."""
    return {col["name"] for col in sa.inspect(bind).get_columns(table)}


def _readFile(path):
    """Return file content or None."""
    if not path or not path.startswith("/"):
        return None
    try:
        with open(path, "r", encoding="utf-8") as fd:
            return fd.read()
    except (OSError, UnicodeDecodeError):
        return None


def _inlineJSON(bind, table, column):
    """Replace file paths in a column with the JSON content of the file ('{}' if unreadable)."""
    rows = bind.execute(sa.text(f"SELECT id, {column} FROM {table}")).fetchall()
    for rowid, value in rows:
        if value and value.lstrip().startswith(("{", "[")):
            continue
        content = _readFile(value)
        try:
            json.loads(content)
        except (TypeError, ValueError):
            content = "{}"
        bind.execute(sa.text(f"UPDATE {table} SET {column} = :val WHERE id = :rowid"), {"val": content, "rowid": rowid})


def _modelFormats(fileloc):
    """Return {fmt: text} for a model saved on disk, generating missing siblings from the master file."""
    master = _readFile(fileloc)
    if master is None:
        return {}
    out = {"ntriples": _readFile(f"{fileloc}.ntriples") or master}
    graph = None
    for fmt in ("turtle", "json-ld"):
        out[fmt] = _readFile(f"{fileloc}.{fmt}")
        if out[fmt] is None:
            if graph is None:
                from rdflib import Graph  # pylint: disable=import-outside-toplevel

                graph = Graph()
                graph.parse(data=master, format="ntriples")
            out[fmt] = graph.serialize(format=fmt)
    return out


def _migrateModels(bind):
    """Move model files into modelcontent and point models.contentid at them."""
    cols = _columns(bind, "models")
    if "contentid" not in cols:
        op.add_column("models", sa.Column("contentid", sa.String(255), nullable=True))
    if "fileloc" in cols:
        now = int(time.time())
        rows = bind.execute(sa.text("SELECT id, uid, fileloc FROM models")).fetchall()
        for rowid, uid, fileloc in rows:
            formats = _modelFormats(fileloc)
            if not formats:
                bind.execute(sa.text("DELETE FROM models WHERE id = :rowid"), {"rowid": rowid})
                continue
            for fmt in MODEL_FORMATS:
                exists = bind.execute(sa.text("SELECT id FROM modelcontent WHERE uid = :uid AND fmt = :fmt"), {"uid": uid, "fmt": fmt}).first()
                if not exists:
                    bind.execute(
                        sa.text("INSERT INTO modelcontent (uid, fmt, content, insertdate) VALUES (:uid, :fmt, :content, :now)"),
                        {"uid": uid, "fmt": fmt, "content": zlib.compress(formats[fmt].encode("utf-8"), 6), "now": now},
                    )
        bind.execute(sa.text("UPDATE models SET contentid = uid WHERE contentid IS NULL"))
        op.drop_column("models", "fileloc")
    bind.execute(sa.text("UPDATE models SET contentid = uid WHERE contentid IS NULL"))
    op.alter_column("models", "contentid", existing_type=sa.String(255), nullable=False)


def upgrade() -> None:
    """Create shared-state tables, inline JSON files, move models into the database."""
    bind = op.get_bind()
    for table in NEW_TABLES:
        Base.metadata.tables[table].create(bind, checkfirst=True)
    for table, column in JSON_COLUMNS:
        op.alter_column(table, column, type_=LONGTEXT(), existing_type=sa.String(4096), existing_nullable=False)
        _inlineJSON(bind, table, column)
    _migrateModels(bind)


def downgrade() -> None:
    """Restore models.fileloc (empty); JSON columns stay LONGTEXT and model content stays in the database."""
    bind = op.get_bind()
    cols = _columns(bind, "models")
    if "fileloc" not in cols:
        op.add_column("models", sa.Column("fileloc", sa.String(4096), nullable=False, server_default=""))
    if "contentid" in cols:
        op.drop_column("models", "contentid")
