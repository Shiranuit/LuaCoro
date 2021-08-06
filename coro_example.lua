coro = require('coro')

local showValue = coro.async(function(start, stop, showPairOnly)
    local sum = 0
    for i in coro.range(start, stop) do
        if showPairOnly and i%2 == 0 then
            print(i)
            sum = sum + i
        elseif not showPairOnly and i%2 == 1 then
            print(i)
            sum = sum + i
        end
    end
    return sum
end)

coro.run(function()
    -- for i in coro.range(0, 10) do
    --     print(i)
    -- end

    local task1 = showValue(0, 1000, false)
    -- print('impairSum', coro.await(task1))
    local task2 = showValue(0, 500, true)
    -- print('pairSum', coro.await(task2))
    local results = coro.waitForAny({task1, task2})
    print(results)
end)
