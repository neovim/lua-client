local Loop = require('nvim.loop')


describe('loop functions', function()
  local loop

  before_each(function()
    if loop then
      loop:exit()
    end
    loop = Loop.new()
  end)

  describe('spawn', function()
    describe('with first argument that is not Loop instance', function()
      it('raises an error', function()
        assert.has.error(function() loop.spawn(1) end)
      end)
    end) 

    describe('with second argument that is not a string array', function()
      it('raises an error', function()
        assert.has.error(function() loop:spawn({}) end)
        assert.has.error(function() loop:spawn(1) end)
        assert.has.error(function() loop:spawn({1}) end)
      end)
    end)
  end)

  describe('run', function()
    it('cannot start after the process has exited', function()
      loop:spawn({'true'})
      loop:run(function() end)
      assert.has.error(function() loop:run(function() end) end)
      assert.has.error(function() loop:run(function() end) end)
      assert.has.error(function() loop:run(function() end) end)
      assert.has.error(function() loop:run(function() end) end)
    end)

    it('accepts a timeout argument', function()
      loop:spawn({'sh', '-c', 'sleep 5000'})
      loop:run(function() end, 50)
      loop:exit(0)
    end)
  end)
  
  describe('reading/writing', function()
    it('only returns when all data is read', function()
      loop:spawn({'sh', '-c',
        'echo 1; echo 12; echo 123; echo 1234; echo 12345'})

      local received = ''
      loop:run(function(data)
        received = received .. data
      end)

      assert.are.same('1\n12\n123\n1234\n12345\n', received)
    end)

    it('binary data(zeros in the middle)', function()
      loop:spawn({'cat', '-'})

      local received = ''
      loop:send('\000\001\002\000\003')
      loop:run(function(data)
        received = received .. data
        loop:stop()
      end)

      assert.are.same('\000\001\002\000\003', received)
    end)

    it('stopping/resuming the loop', function()
      loop:spawn({'cat', '-'})

      local received = ''

      loop:send('1')
      loop:run(function(data)
        received = received .. data
        loop:stop()
      end)
      assert.are.same('1', received)

      loop:send('\0002')
      loop:run(function(data)
        received = received .. data
        loop:stop()
      end)

      assert.are.same('1\0002', received)

      loop:send('\0003')
      loop:run(function(data)
        received = received .. data
        loop:stop()
      end)

      assert.are.same('1\0002\0003', received)

      loop:send('\0004')
      loop:run(function(data)
        received = received .. data
        loop:send('\00056')
        loop:stop()
      end)

      loop:run(function(data)
        received = received .. data
        assert.are.same('1\0002\0003\0004\00056', received)
        loop:stop()
      end)
    end)
  end)
end)
