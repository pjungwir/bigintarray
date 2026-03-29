EXTENSION = bigintarray
EXTVERSION = 1.0

MODULE_big = _bigint
OBJS = \
	_bigint_bool.o \
	_bigint_gin.o \
	_bigint_gist.o \
	_bigint_op.o \
	_bigint_selfuncs.o \
	_bigint_tool.o \
	_bigintbig_gist.o

DATA = bigintarray--1.0.sql
PGFILEDESC = "bigintarray - functions and operators for arrays of bigints"

REGRESS = _bigint

PG_CPPFLAGS += -Werror

PG_CONFIG ?= pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
REGRESS_OPTS = --dbname=$(EXTENSION)_regression # This must come *after* the include since we override the built-in --dbname.

test:
	$(MAKE) installcheck

release:
	git tag v$(EXTVERSION)
	git archive --format zip --prefix=$(EXTENSION)-$(EXTVERSION)/ --output $(EXTENSION)-$(EXTVERSION).zip master

.PHONY: test release
