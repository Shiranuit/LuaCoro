local coro = require('coro')
local Promise = coro.promise

function beforeEach()
  coro.cleanup()
end

test('it should run promise even if coro.run has not been called', function()
  local run = false

  Promise.new(function(resolve, reject)
    run = true
    resolve(1)
  end)

  assert(run, 'Promise should be run even if coro.run is not called')
end)

test('it should return the result given to the resolve function', function()
  local value

  local main = coro.async(function()
    value = coro.await(Promise.new(function(resolve, reject)
      resolve(42)
    end))
  end)
  
  main()
  coro.run()
  assert(value == 42, 'Expected value to be 42')
end)

test('resolved promise should have it\'s value set to the one resolved', function()
  local prom = Promise.new(function(resolve, reject)
    resolve(42)
  end)

  assert(prom.__value[1] == 42, 'Expected promise value to be 42')
end)

test('rejected promise should have it\'s value set to the one resolved', function()
  local prom = Promise.new(function(resolve, reject)
    reject('err')
  end)

  assert(prom.__value[1] == 'err', 'Expected promise value to be "err"')
end)

test('it should chain promise', function()
  local result = 0

  local prom = Promise.new(function(resolve, reject)
    resolve(41)
  end):chain(function(value)
    return value + 1
  end):chain(function(value)
    result = value
  end)

  assert(result == 0, 'Expected result to be 0')
  coro.run('nowait')
  assert(result == 0, 'Expected result to be 0')
  coro.run('nowait')
  assert(result == 0, 'Expected result to be 0')
  coro.run('nowait')
  assert(result == 42, 'Expected result to be 42')
end)

test('it should not execute chained promise until parent is resolved', function()
  local result = 0

  local resolve
  local prom = Promise.new(function(res, rej)
    resolve = res
  end):chain(function(value)
    result = value + 1
  end)

  assert(result == 0, 'Expected result to be 0')
  coro.run('nowait')
  resolve(41)
  assert(result == 0, 'Expected result to be 0')
  coro.run('nowait')
  assert(result == 0, 'Expected result to be 0')
  coro.run('nowait')
  assert(result == 42, 'Expected result to be 42')
end)

test('it should skip chained promises if parent is rejected', function()
  local result = 0
  local prom = Promise.new(function(res, rej)
    rej('err')
  end):chain(function(value)
    result = 41
  end):chain(function(value)
    result = 42
  end)

  coro.run()
  assert(result == 0, 'Expected chained promise to not be executed')
end)

test('it should skip chained promises if parent is rejected and execute catch promise', function()
  local result = 0
  local prom = Promise.new(function(res, rej)
    rej('err')
  end):chain(function(value)
    result = 42
  end):catch(function(err)
    result = err
  end)

  coro.run()
  assert(result == 'err', 'Expected catch promise to be executed')
end)

test('it should pass the result of the catch promise to the next chained promise', function()
  local result = 0
  local prom = Promise.new(function(res, rej)
    rej('err')
  end):chain(function(value)
    result = 42
  end):catch(function(err)
    return 43
  end):chain(function(value)
    result = value
  end)

  coro.run()
  assert(result == 43, 'Expected result of catched promise to be passed to next chained promise')
end)

test('Promise.all should create a promise waiting for all promises to be resolved', function()
  local res = {}

  local prom1 = Promise.new(function(resolve, reject)
    res[1] = resolve
  end)

  local prom2 = Promise.new(function(resolve, reject)
    res[2] = resolve
  end)

  local prom3 = Promise.new(function(resolve, reject)
    res[3] = resolve
  end)

  local allProm = Promise.all({prom1, prom2, prom3})

  coro.run('nowait')
  assert(Promise.isPending(allProm), 'Expected promise to be pending until all are resolved')
  res[1]('res')
  coro.run('nowait')
  assert(Promise.isPending(allProm), 'Expected promise to be pending until all are resolved')
  res[2]('res')
  coro.run('nowait')
  assert(Promise.isPending(allProm), 'Expected promise to be pending until all are resolved')
  res[3]('res')
  coro.run()
  assert(Promise.isResolved(allProm), 'Expected promise to be resolved')
end)

test('Promise.all should be rejected if one of the promises is rejected', function()
  local prom1 = Promise.new(function(resolve, reject)
    reject('err', true)
  end)

  local prom2 = Promise.new(function(resolve, reject)
    resolve(1)
  end)

  local prom3 = Promise.new(function(resolve, reject)
    resolve(2)
  end)

  local allProm = Promise.all({prom1, prom2, prom3})

  coro.run()
  assert(Promise.isErrored(allProm), 'Expected promise to be rejected')
  assert(allProm.__value[1] == 'err')
end)

test('Promise.any should create a promise that wait until of the promises is resolved or rejected', function()
  local wait = true
  local prom1 = Promise.new(function(resolve, reject)
    while wait do
      coro.await()
    end
    resolve()
  end)

  local prom2 = Promise.new(function(resolve, reject)
    while wait do
      coro.await()
    end
    resolve()
  end)

  local prom3 = Promise.new(function(resolve, reject)
    resolve(42)
  end)

  local allProm =
    Promise.any({prom1, prom2, prom3})
    :chain(function(...)
      wait = false
      return ...
    end)

  coro.run()
  assert(Promise.isResolved(allProm), 'Expected promise to be rejected')
  assert(allProm.__value[1] == 42)
end)

test('Promise.any rejected if the first promise to not be pending is errored', function()
  local wait = true
  local prom1 = Promise.new(function(resolve, reject)
    while wait do
      coro.await()
    end
    resolve()
  end)

  local prom2 = Promise.new(function(resolve, reject)
    while wait do
      coro.await()
    end
    resolve()
  end)

  local prom3 = Promise.new(function(resolve, reject)
    reject('err')
  end)

  local allProm =
    Promise.any({prom1, prom2, prom3})
    :catch(function(err)
      wait = false
      return err
    end)

  coro.run()
  assert(Promise.isResolved(allProm), 'Expected promise to be rejected')
  assert(allProm.__value[1] == 'err')
end)
