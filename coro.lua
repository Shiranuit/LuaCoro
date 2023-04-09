local promises = {}
local promises_next = {}
local promiseId = 1
local promise = {}
local onUnhandledRejection
local runningPromise

if _VERSION == 'Lua 5.1' then
  table.unpack = unpack
end

function promise.isPromise(obj)
  return obj and type(obj) == 'table' and obj.__type == 'promise'
end

function promise.status(prom)
  return prom.__status
end

function promise.resolve(prom, ...)
  prom.__status = 'resolved'
  prom.__value = { ... }
end

function promise.error(prom, err)
  prom.__status = 'errored'
  prom.__value = { err }
end

function promise.await(prom)
  prom.__awaited = true

  while prom.__status == 'pending' do
    coroutine.yield()
  end

  if prom.__status == 'resolved' then
    if promise.isPromise(prom.__value[1]) then
      return promise.await(prom.__value[1])
    end
    return table.unpack(prom.__value)
  else
    error(prom.__value[1], 2)
  end
end

function promise.chain(prom, func)
  assert(type(func) == 'function', 'function expected')

  local newPromise = promise.new(func, false, false)
  table.insert(prom.__dependentPromises, newPromise)
  newPromise.__dependencyCount = newPromise.__dependencyCount + 1
  newPromise.__trigger = prom

  prom.__chained = true
  newPromise.__asyncMethod = true
  return newPromise
end

function promise.catch(prom, func)
  assert(type(func) == 'function', 'function expected')

  local newPromise = promise.new(func, false, false)
  table.insert(prom.__dependentPromises, newPromise)
  newPromise.__dependencyCount = newPromise.__dependencyCount + 1
  newPromise.__trigger = prom

  prom.__catched = true
  newPromise.__asyncMethod = true
  newPromise.__catch = true
  return newPromise
end

function promise.isErrored(prom)
  return prom.__status == 'errored'
end

function promise.isResolved(prom)
  return prom.__status == 'resolved'
end

function promise.isPending(prom)
  return prom.__status == 'pending'
end

function promise.new(func, run, insert)
  assert(type(func) == 'function', 'Exepected a function')

  local co = coroutine.create(func)

  local newPromise = {
    __coroutine = co,
    __type = 'promise',
    __status = 'pending',
    __catch = false,
    __asyncMethod = false,
    __id = promiseId,
    __awaited = false,
    __chained = false,
    __catched = false,
    __dependentPromises = {},
    __dependencyCount = 0,
    __triggerCount = 0,
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

  if insert then
    table.insert(promises_next, newPromise)
  end

  if run then
    local prevRunningPromise = runningPromise
    runningPromise = newPromise

    local resolve = function(...)
      promise.resolve(newPromise, ...)
    end
    local error = function(err)
      promise.error(newPromise, err)
    end

    local out = { coroutine.resume(co, resolve, error) }

    runningPromise = prevRunningPromise

    local success = out[1]

    if success == false then
      promise.error(newPromise, out[2])
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

local function runStep()
  promises = promises_next
  promises_next = {}

  local promCount = #promises

  for i=1, promCount do
    local prom = promises[i]
    runningPromise = prom
    if coroutine.status(prom.__coroutine) ~= "dead" then
      local skip = false
      if prom.__trigger then
        if prom.__catch and promise.isResolved(prom.__trigger) then
          prom.__status = 'resolved'
          prom.__value = prom.__trigger.__value
          skip = true
        elseif prom.__catch == false and promise.isErrored(prom.__trigger) then
          prom.__status = 'errored'
          prom.__value = prom.__trigger.__value
          skip = true
        end
      end

      if not skip then
        local out = { coroutine.resume(prom.__coroutine, table.unpack(prom.__trigger and prom.__trigger.__value or {})) }

        if out[1] == false
          or (prom.__asyncMethod and coroutine.status(prom.__coroutine) == 'dead')
        then
          prom.__value = { select(2, table.unpack(out)) }
          prom.__status = out[1] and 'resolved' or 'errored'
        end
      end
    end
  end

  for i=1, promCount do
    local prom = promises[i]
    if prom.__status ~= 'pending' or coroutine.status(prom.__coroutine) == 'dead' then

      local skip = false

      if not prom.__catched
        and not prom.__awaited
        and not prom.__chained
      then
        if onUnhandledRejection
          and prom.__status == 'errored'
        then
          onUnhandledRejection(prom.__value[1], prom)
        end
      end

      if prom.__status == 'resolved' then
        if promise.isPromise(prom.__value[1]) and not prom.__value[1].__trigger then
          table.insert(promises_next, prom.__value[1])
        end
      elseif not prom.__asyncMethod and prom.__status == 'pending' then
        table.insert(promises_next, prom)
        skip = true
      end

      if not skip then
        for i=1, #prom.__dependentPromises do
          local dependentPromise = prom.__dependentPromises[i]
          dependentPromise.__triggerCount = dependentPromise.__triggerCount + 1
          if dependentPromise.__dependencyCount == dependentPromise.__triggerCount then
            table.insert(promises_next, dependentPromise)
          end
        end
      end
    elseif prom.__dependencyCount == prom.__triggerCount then
      table.insert(promises_next, prom)
    end
  end

  runningPromise = nil

  return #promises_next > 0
end

local function run(mode)
  if not mode then
    mode = 'default'
  end

  if mode == 'nowait'then
    return runStep()
  end

  while runStep() do
  end
  return false
end

local function async(func)
  return function(...)
    local newPromise = promise.new(func, false, true)
    newPromise.__asyncMethod = true
    local prevRunningPromise = runningPromise
    runningPromise = newPromise

    local out = { coroutine.resume(newPromise.__coroutine, ...) }

    runningPromise = prevRunningPromise

    local success = out[1]
    table.remove(out, 1)

    if coroutine.status(newPromise.__coroutine) == 'dead' then
      newPromise.__value = out
      newPromise.__status = success and 'resolved' or 'errored'
    end

    return newPromise
  end
end

local function await(obj)
  if not runningPromise then
    error('Cannot await outside of an async function / promise', 2)
  end
  if promise.isPromise(obj) then
    table.insert(obj.__dependentPromises, runningPromise)
    runningPromise.__dependencyCount = runningPromise.__dependencyCount + 1
    return promise.await(obj)
  end
  coroutine.yield()
  return obj
end

local function all(promises)
  local filteredPromises = {}

  for i = 1, #promises do
    local obj = promises[i]
    if promise.isPromise(obj) then
      table.insert(filteredPromises, obj)
    end
  end

  return promise.new(function(res, rej)
    for i=1, #filteredPromises do
      local prom = filteredPromises[i]
  
      table.insert(prom.__dependentPromises, runningPromise)
      runningPromise.__dependencyCount = runningPromise.__dependencyCount + 1
      prom.__awaited = true
    end

    local promisesResults = {}
    for i = 1, #filteredPromises do
      promisesResults[i] = promise.await(filteredPromises[i])
    end
    res(promisesResults)
  end, true, false)
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
        table.insert(filteredPromises, obj)
      end
    end

    local finishedProm

    while not finishedProm do
      for i=1, #filteredPromises do
        local prom = filteredPromises[i]
        if not promise.isPending(prom) then
          finishedProm = prom
          break
        end
      end
      coroutine.yield()
    end
    
    if finishedProm.__status == 'resolved' then
      res(table.unpack(finishedProm.__value))
    else
      err(finishedProm.__value[1])
    end

  end, true, true)
end

local function waitForAny(promises)
  return await(any(promises))
end

local function cleanup()
  promises = {}
  promises_next = {}
  promiseId = 0
  runningPromise = nil
end

return {
  range = _forward(range),
  run = run,
  cleanup = cleanup,
  loopMode = { default = 'default', nowait = 'nowait' },
  async = async,
  await = await,
  onUnhandledRejection = function(func)
    if type(func) ~= "function" then
      error("onUnhandledRejection must be a function", 1)
    end
    onUnhandledRejection = func
  end,
  promise = {
    new = function(func)
      return promise.new(func, true, true)
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
