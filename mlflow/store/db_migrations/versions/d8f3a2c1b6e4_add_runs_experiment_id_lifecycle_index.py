"""add composite index on runs(experiment_id, lifecycle_stage)

``search_runs`` filters the ``runs`` table by ``experiment_id`` and
``lifecycle_stage`` on every experiment page load. PostgreSQL does not
automatically index foreign-key columns, so without this index the query
performs a sequential scan of the entire ``runs`` table. On large,
multi-tenant deployments that scan takes tens of seconds and dominates the
runs-search latency even though the returned payload is small.

Add the composite index that matches the filter. On PostgreSQL the index is
built ``CONCURRENTLY`` (outside a transaction) so it does not lock writes on a
large ``runs`` table; other dialects fall back to a regular index build.

Create Date: 2026-07-07 12:00:00.000000

"""

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision = "d8f3a2c1b6e4"
down_revision = "7d34483879f0"
branch_labels = None
depends_on = None

INDEX_NAME = "index_runs_experiment_id_lifecycle_stage"
TABLE_NAME = "runs"
COLUMNS = ["experiment_id", "lifecycle_stage"]


def _index_exists(bind) -> bool:
    return any(ix["name"] == INDEX_NAME for ix in sa.inspect(bind).get_indexes(TABLE_NAME))


def upgrade():
    bind = op.get_bind()
    # Idempotent: the index may already have been created manually (e.g. with
    # CREATE INDEX CONCURRENTLY ahead of the migration on a busy production DB).
    if _index_exists(bind):
        return
    if bind.dialect.name == "postgresql":
        # CREATE INDEX CONCURRENTLY cannot run inside a transaction block.
        with op.get_context().autocommit_block():
            op.create_index(INDEX_NAME, TABLE_NAME, COLUMNS, postgresql_concurrently=True)
    else:
        op.create_index(INDEX_NAME, TABLE_NAME, COLUMNS)


def downgrade():
    bind = op.get_bind()
    if not _index_exists(bind):
        return
    if bind.dialect.name == "postgresql":
        with op.get_context().autocommit_block():
            op.drop_index(INDEX_NAME, table_name=TABLE_NAME, postgresql_concurrently=True)
    else:
        op.drop_index(INDEX_NAME, table_name=TABLE_NAME)
