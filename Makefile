# This Makefile's only purpose is to simplify creating/maintaining a
# development environment. It will setup a project-private prefix(.deps/usr)
# with all dependencies required for building/testing
#
# local.mk is ignored by git and can be used for developer-specific
# customizations, which can be:
# - override default target
# - define custom targets
# - override ovariables defined here(all variables are defined with ?=)
-include local.mk

# Dependencies prefix
DEPS_DIR ?= $(shell pwd)/.deps
DEPS_PREFIX ?= $(DEPS_DIR)/usr
DEPS_BIN ?= $(DEPS_PREFIX)/bin

# Lua-related configuration
LUA_URL ?= http://www.lua.org/ftp/lua-5.1.5.tar.gz
LUAROCKS_URL ?= https://github.com/keplerproject/luarocks/archive/v2.2.0.tar.gz
LUA_TARGET ?= linux
LUA ?= $(DEPS_BIN)/lua
LUAROCKS ?= $(DEPS_BIN)/luarocks
BUSTED ?= $(DEPS_BIN)/busted
LUV ?= $(DEPS_PREFIX)/lib/luarocks/rocks/luv
MSGPACK ?= $(DEPS_PREFIX)/lib/luarocks/rocks/lua-messagepack
COXPCALL ?= $(DEPS_PREFIX)/lib/luarocks/rocks/coxpcall

# Libuv configuration
LIBUV_URL ?= https://github.com/libuv/libuv/archive/v1.7.3.tar.gz
LIBUV ?= $(DEPS_PREFIX)/lib/libuv.a
LIBUV_LINK_FLAGS = $(shell PKG_CONFIG_PATH='$(DEPS_PREFIX)/lib/pkgconfig' pkg-config libuv --libs)

# Compilation
CC ?= gcc
CFLAGS ?= -g -fPIC -Wall -Wextra -Werror -Wconversion -Wextra \
	-Wstrict-prototypes -pedantic
LDFLAGS ?= -shared -fPIC
DEPS_INCLUDE_FLAGS ?= -I$(DEPS_PREFIX)/include

# Misc
# Options used by the 'valgrind' target, which runs the tests under valgrind
VALGRIND_OPTS ?= --log-file=valgrind.log --leak-check=yes --track-origins=yes
# Command that will download a file and pipe it's contents to stdout
FETCH ?= curl -L -o -
# Command that will gunzip/untar a file from stdin to the current directory,
# stripping one directory component
UNTGZ ?= tar xfz - --strip-components=1


all: deps

deps: | $(LIBUV) $(MSGPACK) $(COXPCALL) $(BUSTED) $(LUV)

test: all
	$(BUSTED) -v '--lpath=./nvim/?.lua;' '--cpath=./nvim/?.so;' -o gtest test

valgrind: all
	eval $$($(LUAROCKS) path); \
	valgrind $(VALGRIND_OPTS) $(LUA) \
		$(DEPS_PREFIX)/lib/luarocks/rocks/busted/2.0.rc11-0/bin/busted \
		'--lpath=./nvim/?.lua;' '--cpath=./nvim/?.so;' test
	cat valgrind.log

clean:
	rm -f nvim/*.o nvim/*.so

distclean: clean
	rm -rf $(DEPS_DIR)

$(BUSTED): | $(LUAROCKS)
	$(LUAROCKS) install busted
	$(LUAROCKS) install inspect  # helpful for debugging

$(LUV): $(LUAROCKS)
	$(LUAROCKS) install luv

$(MSGPACK): $(LUAROCKS)
	$(LUAROCKS) install lua-messagepack

$(COXPCALL): $(LUAROCKS)
	$(LUAROCKS) install coxpcall

$(LUAROCKS): $(LUA)
	dir="$(DEPS_DIR)/src/luarocks"; \
	mkdir -p $$dir && cd $$dir && \
	$(FETCH) $(LUAROCKS_URL) | $(UNTGZ) && \
	./configure --prefix=$(DEPS_PREFIX) --force-config \
		--with-lua=$(DEPS_PREFIX) && make bootstrap

$(LUA):
	dir="$(DEPS_DIR)/src/lua"; \
	mkdir -p $$dir && cd $$dir && \
	$(FETCH) $(LUA_URL) | $(UNTGZ) && \
	sed -i -e '/^CFLAGS/s/-O2/-g/' src/Makefile && \
	make $(LUA_TARGET) install INSTALL_TOP=$(DEPS_PREFIX)

$(LIBUV):
	dir="$(DEPS_DIR)/src/libuv"; \
	mkdir -p $$dir && cd $$dir && \
	$(FETCH) $(LIBUV_URL) | $(UNTGZ) && \
	./autogen.sh && ./configure --with-pic --disable-shared \
		--prefix=$(DEPS_PREFIX) && make install

$(DEPS_DIR)/src/libuv:
	mkdir -p $@ && cd $@ && \
	$(FETCH) $(LIBUV_URL) | $(UNTGZ) || rm -rf $@
 
.PHONY: all deps test valgrind clean distclean
