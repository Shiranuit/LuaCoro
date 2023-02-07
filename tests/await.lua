local coro = require('coro')
local Promise = coro.promise

function beforeEach()
  coro.cleanup()
end

test('it should resolve result from previously awaited async function', function ()
  local finalResult = ''
  local thirddef = coro.async(function() local result = coro.await('value') return result end)
  local seconddef = coro.async(function() local result = coro.await(thirddef()) return result end)
  local firstdef = coro.async(function() local result = coro.await(seconddef()) return result end)
  local maindef = coro.async(function() finalResult = coro.await(firstdef()) end)

  maindef()
  coro.run()
  assert(finalResult == 'value', 'Expected finalResult to be "value" since it should have been propagated through the promise chain')
end)

test('it should fail if called outside of an async function', function()
  local success, err = pcall(coro.await, Promise.new(function(resolve, reject)
    resolve(42)
  end))

  assert(success == false)
end)

test('it should fail if the promise is errored', function()
  local success, err

  local main = coro.async(function()
    success, err = pcall(coro.await, Promise.new(function(resolve, reject)
      reject('err')
    end))
  end)
  main()
  coro.run()
  assert(success == false)
  assert(err == 'err', 'Promise should fail with the error given to the reject function')
end)

test('it should resolve with the value returned by the async function', function()
  local success, value

  local func = coro.async(function()
    return 42
  end)

  local main = coro.async(function()
    success, value = pcall(coro.await, func())
  end)
  main()
  coro.run()
  assert(success == true)
  assert(value == 42, 'Expected promise to be resolved with 42')
end)

test('it should switch between awaited promises', function()
  local stack = {}

  local func1 = coro.async(function()
    for i=1,4 do
      table.insert(stack, i)
      coro.await()
    end
  end)

  local func2 = coro.async(function()
    for i=5,8 do
      table.insert(stack, i)
      coro.await()
    end
  end)

  local main = coro.async(function()
    coro.waitForAll(func1(), func2())
  end)

  main()
  coro.run()

  assert(#stack == 8, 'Expected stack to have 8 elements')
  assert(stack[1] == 1, 'Expected stack to have 1 at index 1')
  assert(stack[2] == 5, 'Expected stack to have 2 at index 2')
  assert(stack[3] == 2, 'Expected stack to have 3 at index 3')
  assert(stack[4] == 6, 'Expected stack to have 4 at index 4')
  assert(stack[5] == 3, 'Expected stack to have 5 at index 5')
  assert(stack[6] == 7, 'Expected stack to have 6 at index 6')
  assert(stack[7] == 4, 'Expected stack to have 7 at index 7')
  assert(stack[8] == 8, 'Expected stack to have 8 at index 8')
end)