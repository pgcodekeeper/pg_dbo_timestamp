MODULES = pg_dbo_timestamp
EXTENSION = pg_dbo_timestamp
DATA = scripts/pg_dbo_timestamp--0.0.1.sql

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
