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

Release
-------

1. [Bump](https://github.com/neovim/lua-client/commit/018a562992f1e1a54e111a5603fc6f603be51cca)
   the rockspec version and filename.
2. Create and push a new tag.
   ```
   TAG=$(echo *.rockspec | grep -o '[0-9].[0-9].[0-9].[0-9]')
   git tag -a "$TAG" -m "nvim-client $TAG"
   git push --follow-tags --dry-run
   git push --follow-tags
   ```
3. [Generate](https://luarocks.org/settings/api-keys) LuaRocks API key
4. Upload the new rockspec.
   ```
   ./.deps/usr/bin/luarocks upload --api-key=xxx nvim-client-*.rockspec
   ```
   - Note: `luarocks upload` requires a JSON library.
      ```
      ./.deps/usr/bin/luarocks install dkjson
      ```
