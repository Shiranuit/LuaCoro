local promises = {}
local promiseId = 1
local promise = {}

if _VERSION == 'Lua 5.1' then
  table.unpack = unpack
end

function promise.isPromise(obj)
  return obj and type(obj) == 'table' and obj.__type == 'promise'
end

function promise.status(obj)
  return obj.__status
end

function promise.resolve(obj, ...)
  obj.__status = 'resolved'
  obj.__value = { ... }
end

function promise.error(obj, err)
  obj.__status = 'errored'
  obj.__value = err
end

function promise.await(obj)
  while obj.__status == 'pending' do
    coroutine.yield()
  end

  if obj.__status == 'resolved' then
    if promise.isPromise(obj.__value[1]) then
      return promise.await(obj.__value[1])
    end
    return table.unpack(obj.__value)
  else
    error(obj.__value)
  end
end

function promise.chain(obj, func)
  assert(type(func) == 'function', 'function expected')

  local newPromise = promise.new(func, false)
  newPromise.__trigger = obj
  newPromise.__asyncMethod = true
  return newPromise
end

function promise.catch(obj, func)
  assert(type(func) == 'function', 'function expected')

  local newPromise = promise.new(func, false)
  newPromise.__trigger = obj
  newPromise.__asyncMethod = true
  newPromise.__catch = true
  return newPromise
end

function promise.isErrored(obj)
  return obj.__status == 'errored'
end

function promise.isResolved(obj)
  return obj.__status == 'resolved'
end

function promise.isPending(obj)
  return obj.__status == 'pending'
end

function promise.new(func, run)
  assert(type(func) == 'function', 'Exepected a function')

  local co = coroutine.create(func)

  local newPromise = {
    __coroutine = co,
    __type = 'promise',
    __status = 'pending',
    __catch = false,
    __asyncMethod = false,
    __id = promiseId,
    status = promise.status,
    resolve = promise.resolve,
    error = promise.error,
    await = promise.await,
    chain = promise.chain,
    catch = promise.catch,
    isErrored = promise.isErrored,
    isResolved = promise.isResolved,
    isPending = promise.isPending,
  }

  promiseId = promiseId + 1

  promises[#promises + 1] = newPromise

  if run then
    local resolve = function(...)
      promise.resolve(newPromise, ...)
    end
    local error = function(...)
      promise.error(newPromise, ...)
    end

    local out = { coroutine.resume(co, resolve, error) }

    local success = out[1]

    if coroutine.status(newPromise.__coroutine) == 'dead' and success == false then
      promise.error(newPromise, out[1])
    end
  end

  return newPromise
end

local function range(start, stop, step)
    local step = step or 1
    for i = start, stop, step do
      coroutine.yield(i)
    end
end

local function _forward(func)
  return function(...)
    local args = { ... }
    local co = coroutine.create(func)
    return function()
      if coroutine.status(co) ~= 'dead' then
        local result = { coroutine.resume(co, table.unpack(args)) }
        coroutine.yield()
        return select(2, table.unpack(result))
      end
    end
  end
end

local function run(mode)
  if not mode then
    mode = 'default'
  end

  local i = 1
  while #promises > 0 do
    local prom = promises[i]
    if coroutine.status(prom.__coroutine) == 'dead' or not promise.isPending(prom) then
      table.remove(promises, i)
    elseif not prom.__trigger or not promise.isPending(prom.__trigger) then

      local skip = false
      if prom.__trigger and prom.__catch and promise.isResolved(prom.__trigger) then
        prom.__status = 'resolved'
        prom.__value = prom.__trigger.__value
        skip = true
        table.remove(promises, i)
      elseif prom.__trigger and prom.__catch == false and promise.isErrored(prom.__trigger) then
        prom.__status = 'errored'
        prom.__value = { prom.__trigger.__value }
        skip = true
        table.remove(promises, i)
      end

      if not skip then
        local out = { coroutine.resume(prom.__coroutine, table.unpack(prom.__trigger and prom.__trigger.__value or {})) }

        if coroutine.status(prom.__coroutine) == 'dead' then
          if prom.__asyncMethod or out[1] == false then
            prom.__value = out[1] and { select(2, table.unpack(out)) } or out[2]
            prom.__status = out[1] and 'resolved' or 'errored'
          end
          table.remove(promises, i)
        else
          i = i + 1
        end
      end
    else
      i = i + 1
    end
    if i > #promises then
      if mode == 'nowait' then
        return true
      end
      i = 1
    end
  end
  return false
end

local function async(func)
  return function(...)
    local newPromise = promise.new(func, false)
    newPromise.__asyncMethod = true

    local out = { coroutine.resume(newPromise.__coroutine, ...) }

    local success = out[1]
    table.remove(out, 1)

    if coroutine.status(newPromise.__coroutine) == 'dead' then
      newPromise.__value = success and out or out[1]
      newPromise.__status = success and 'resolved' or 'errored'
    end

    return newPromise
  end
end

local function await(obj)
  if promise.isPromise(obj) then
    return promise.await(obj)
  end
  return coroutine.yield(obj)
end

local function all(promises)
  return promise.new(function(res, rej)
    local promisesResults = {}
    for i = 1, #promises do
      promisesResults[i] = await(promises[i])
    end
    res(promisesResults)
  end, true)
end

local function waitForAll(promises)
  return await(all(promises))
end

local function any(promises)
  return promise.new(function(res, err)
    local filteredPromises = {}

    for i = 1, #promises do
      local obj = promises[i]
      if promise.isPromise(obj) then
        filteredPromises[#filteredPromises + 1] = obj
      end
    end

    local finishedProm = {}

    local i = 1
    while true do
      local prom = filteredPromises[i]
      if promise.isPending(prom) then
        coroutine.yield()
      else
        finishedProm = prom
        break
      end
      i = i + 1
      if i > #filteredPromises then
        i = 1
      end
    end
    
    if finishedProm.__status == 'resolved' then
      res(table.unpack(finishedProm.__value))
    else
      err(finishedProm.__value)
    end

  end, true)
end

local function waitForAny(promises)
  return await(any(promises))
end

return {
  range = _forward(range),
  run = run,
  loopMode = { default = 'default', nowait = 'nowait' },
  async = async,
  await = await,
  promise = {
    new = function(func)
      return promise.new(func, true)
    end,
    isErrored = promise.isErrored,
    isResolved = promise.isResolved,
    isPending = promise.isPending,
    isPromise = promise.isPromise,
    waitForAll = waitForAll,
    waitForAny = waitForAny,
    all = all,
    any = any,
  }
}
