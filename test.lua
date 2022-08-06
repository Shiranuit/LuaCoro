local args = { ... }

local function listDir(path)
  local files = {}
  local handle = io.popen('ls "'..path..'"')
  assert(handle, 'Failed to list directory')
  for file in handle:lines() do
    table.insert(files, path..'/'..file)
  end
  handle:close()
  return files
end

local tests = {}

if #args > 0 then
  tests = args
else
  tests = listDir('tests')
end

local function padRight(str, len)
  return str .. string.rep(' ', len - #str)
end

for i=1, #tests do
  local handle = io.open(tests[i], 'r')
  local code = handle:read('*a')
  handle:close()

  local step = {}
  local onlyStep = {}

  local env = setmetatable({
    test = function(name, func)
      table.insert(step, {
        name = name,
        func = func
      })
    end,
    only = function(name, func)
      onlyStep = {{
        name = name,
        func = func
      }}
    end,
  }, {__index = _G})

  local run = assert(load(code, tests[i], 't', env), 'Cannot load test "'..tests[i]..'"')
  local success, err = pcall(run)
  if not success then
    print('Error in test "'..tests[i]..'":'..err)
  else
    if #onlyStep > 0 then
      step = onlyStep
    end
    print('\x1b[0;33m--- '..tests[i])
    for i=1, #step do
      if env.beforeEach and type(env.beforeEach) == 'function' then
        env.beforeEach()
      end
      local success, err = pcall(step[i].func)
      if success then
        print('\x1b[0;0m[\x1b[0;32mV\x1b[0;0m] '..step[i].name)
      else
        local errMessage = err and ': '..err or ''
        print('\x1b[0;0m[\x1b[0;31mX\x1b[0;0m] '..step[i].name..errMessage)
      end
    end
    print()
  end
end