local coro = require('coro')
local Promise = coro.promise

function beforeEach()
  coro.cleanup()
end

test('it should prevent function from being executed after calling await if coro.run is not called', function()
  local run = false
  local main = coro.async(function()
    coro.await()
    run = true
  end)
  main()
  assert(run == false, 'Expected function to not be run')
end)

test('it should resolve with the value from the promise', function()
  local success, value

  local main = coro.async(function()
    success, value = pcall(coro.await, Promise.new(function(resolve, reject)
      resolve(42)
    end))
  end)
  main()
  coro.run()
  assert(success == true)
  assert(value == 42, 'Expected promise to be resolved with 42')
end)

test('it should only step once if called with "nowait"', function()
  local step = 0
  local main = coro.async(function()
    step = 1
    coro.await()
    step = 2
    coro.await()
    step = 3
  end)

  main()
  assert(step == 1, 'Expected step to be 1')
  coro.run('nowait')
  assert(step == 2, 'Expected step to be 2')
  coro.run('nowait')
  assert(step == 3, 'Expected step to be 3')
end)

test('it should run until every promise is resolved when called with nil', function()
  local step = 0
  local main = coro.async(function()
    step = 1
    coro.await()
    step = 2
    coro.await()
    step = 3
  end)

  main()
  coro.run()
  assert(step == 3, 'Expected step to be 3')
end)

test('it should run until every promise is resolved when called with "default"', function()
  local step = 0
  local main = coro.async(function()
    step = 1
    coro.await()
    step = 2
    coro.await()
    step = 3
  end)

  main()
  coro.run('default')
  assert(step == 3, 'Expected step to be 3')
end)

test('it should run true if there is still pending promises or false otherwise', function()
  local step = 0
  local main = coro.async(function()
    step = 1
    coro.await()
    step = 2
    coro.await()
    step = 3
  end)

  main()
  assert(step == 1, 'Expected step to be 1')
  local pending = coro.run('nowait')
  assert(pending == true, 'Expected pending to be true')
  assert(step == 2, 'Expected step to be 2')
  pending = coro.run('nowait')
  assert(pending == false, 'Expected pending to be false')
end)

test('it should wait for promises until resolve or reject is called', function()
  local resolve
  Promise.new(function(res, rej)
    resolve = res
    -- do nothing
  end)

  assert(coro.run('nowait'), 'Expected coro.run to return true because promise is still pending')
  assert(coro.run('nowait'), 'Expected coro.run to return true because promise is still pending')
  resolve()
  assert(coro.run('nowait') == false, 'Expected coro.run to return false because promise has been resolved')
end)

test('should call onUnhandledRejection callback if any when promise is rejected without being awaited or catched', function()
  local _err
  coro.onUnhandledRejection(function(err)
    _err = err
  end)

  local main = coro.async(function()
    error('err')
  end)
  main()
  coro.run()
  assert(_err, 'Expected error to be "err"')
end)