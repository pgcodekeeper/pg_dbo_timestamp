EXTENSION = pg_dbo_timestamp
DATA = scripts/*.sql

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
