lua-client
==========

[![Build Status](https://travis-ci.org/neovim/lua-client.svg?branch=master)](https://travis-ci.org/neovim/lua-client)

Lua client for Neovim

Build
-----

The `Makefile` pulls and builds various dependencies into `.deps`.

     make

Test
----

Run tests against whatever `nvim` is in `$PATH`:

     make test

Use a specific `nvim`:

     NVIM_PROG=/path/to/nvim make test

Use test tags (`it('#foo', function() ...`):

     NVIM_PROG=/path/to/nvim make test TEST_TAG=foo
