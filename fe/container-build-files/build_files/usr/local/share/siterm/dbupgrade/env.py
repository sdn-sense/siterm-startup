"""Alembic environment for SiteRM FE.

This directory is baked into the FE image (see Dockerfile) and reused as-is
across restarts, so it must not depend on anything generated at container
start. DBBackend.upgradedb() supplies the sqlalchemy.url and script_location
at runtime via the passed-in Config object; this file only wires that config
into Alembic's migration context.
"""

from logging.config import fileConfig

from alembic import context
from sqlalchemy import engine_from_config, pool

from SiteRMLibs.DBModels import Base

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    """Run migrations without a live DB connection (SQL script output only)."""
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """Run migrations against the live DB connection."""
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
