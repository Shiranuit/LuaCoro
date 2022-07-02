local coroutines = {}

local function range(start, stop, step)
    local step = step or 1
    for i=start, stop, step do
        coroutine.yield(i)
    end
end

local function _forward(func)
    return function(...)
        local args = {...}
        local co = coroutine.create(func)
        return function()
            if coroutine.status(co) ~= 'dead' then
                local result = {coroutine.resume(co, table.unpack(args))}
                coroutine.yield()
                return select(2, table.unpack(result))
            end
        end
    end
end

local function run(func, ...)
    local mainCoro = coroutine.create(func)
    local task = {
        type='task',
        co=mainCoro,
        args={...},
    }

    coroutines[#coroutines+1] = task

    local out = {coroutine.resume(task.co, table.unpack(task.args))}
    if coroutine.status(task.co) == 'dead' then
        if out[1] then
            task.result = {select(2, table.unpack(out))}
        else
            task.error = out[2]
        end
    end
    
    local i = 1
    while #coroutines > 0 do
        local task = coroutines[i]
        if coroutine.status(task.co) == 'dead' then
            table.remove(coroutines, i)
        else
            local out = {coroutine.resume(task.co)}
            if coroutine.status(task.co) == 'dead' then
                if out[1] then
                    task.result = {select(2, table.unpack(out))}
                else
                    task.error = out[2]
                end
                table.remove(coroutines, i)
            else
                i = i + 1
            end
        end
        if i > #coroutines then
            i = 1
        end
    end
end

local function async(func)
    return function(...)
        local co = coroutine.create(func)
        local task = {
            type='task',
            co=co,
            args={...},
        }
        coroutines[#coroutines + 1] = task
        local out = {coroutine.resume(task.co, table.unpack(task.args))}
        if coroutine.status(task.co) == 'dead' then
            if out[1] then
                task.result = {select(2, table.unpack(out))}
            else
                task.error = out[2]
            end
        end
        return task
    end
end

local function await(obj, ...)
    if type(obj) == 'table' and obj.type == 'task' then
        while coroutine.status(obj.co) ~= 'dead' do
            coroutine.yield()
        end
        if obj.error then
            error(obj.error)
        end
        return table.unpack(obj.result)
    elseif type(obj) == 'function' then
        local task = coro.async(obj)()
        while coroutine.status(task.co) ~= 'dead' do
            coroutine.yield()
        end
        if task.error then
            error(task.error)
        end
        return table.unpack(task.result)
    else
        return coroutine.yield(obj)
    end
end

local function waitForAll(tasks)
    local results = {}
    for i=1, #tasks do
        results[i] = await(tasks[i])
    end
    return results
end

local function waitForAny(tasks)
    local running = false

    for i=1, #tasks do
        local task = tasks[i]
        if type(task) == 'table' and task.type == 'task' then
            running = true
            break
        end
    end

    local finalTask = {}

    local i = 1
    while running do
        local task = tasks[i]
        if type(task) == 'table' and task.type == 'task' then
            if coroutine.status(task.co) ~= 'dead' then
                coroutine.yield()
            else
                finalTask = task
                running = false
            end
        end
        i = i + 1
        if i > #tasks then
            i = 1
        end
    end

    if task.error then
        error(task.error)
    end
    return table.unpack(task.result)
end

return {
    range=_forward(range),
    run=run,
    async=async,
    await=await,
    waitForAll=waitForAll,
    waitForAny=waitForAny,
}
