# LuaCoro
Lua library made to do Async / Await using coroutines.

## Functions

## Coro

### run

This will run the coro loop that will do all the async work.

Modes:
- **nil**: Defaulted to the "default" mode
- **default**: Block until there is no more async promises to be resolved
- **nowait**: Do one run of the async loop and return true if there is still more work to do

Return:
- **true**: if there is still some work to do
- **false**: if every promise has been resolved

**Signature**

```lua
run(mode: <string> or <nil>): <boolean>
```

**example**

```lua
local coro = require('coro')

local asyncAdd = coro.async(function(A, B)
  return A + B
end)

local main = coro.async(function()
  print(coro.await(asyncAdd(2, 2)))
end)

main()
coro.run()
```

### async

Transform a function into an async function that returns a promise when called

**signature**

```lua
async(<function>): <async function>
```

**example**

```lua
local asyncAdd = coro.async(function(A, B)
  return A + B
end)
```

### await

Await the result of a promise and returns what the promised was resolved to

**signature**

```lua
await(<promise> or <any>)
```

### range

Allows you to make ranged for loop that will not block the coro execution loop

**signature**

```lua
range(start: <number>, stop: <number>, [step: <number>])
```

**example**

```lua
  for i in coro.range(1, 10) do
    print(i)
  end
```

### onUnhandledRejection

Register a callback that is going to be called when an exception occurs in a promise without being catched

**signature**

```lua
onUnhandledRejection(function(error: string, promise: <promise>))
```

**example**

```lua
local coro = require('coro')

coro.onUnhandledRejection(function(err, promise)
  print(err, promise)
end)
```

### promise.new

Coro allows you to create promises that can be resolved later

```lua
local coro = require('coro')
local Promise = coro.promise

local myPromise = Promise.new(function(resolve, reject)
  --work
  resolve(42)
end)

coro.run()
```

#### chain

Chains a function that will be executed once the previous promise is resolved.
the function will be given the result of what the promise has been resolved to.

**signature**

```lua
<promise>:chain(<function>)
```

#### catch

Chain a catch promise that will be executed if an error occurs in the promise

**signature**

```lua
<promise>:catch(<function>)
```

#### await

Await a pending promise and returns what the promise was resolved to

**signature**

```lua
<promise>:await(): <any>
```

#### resolve

Resolves the promise with then given value

**signature**

```lua
<promise>:resolve(...)
```

#### error

Resolves the promise with an error

**signature**

```lua
<promise>:error(err)
```

#### status

Returns the status of the promise, either "pending", "resolved" or "errored"

**signature**

```lua
<promise>:status(): 'pending' | 'resolved' | 'errored'
```

#### promise.isErrored

Returns true if the promise is errored

**signature**

```lua
promise:isErrored(): <bool>
```

```lua
promise.isErrored(<promise>): <bool>
```
#### promise.isResolved

Returns true if the promise is resolved

**signature**

```lua
<promise>:isResolved(): <bool>
```
```lua
promise.isResolved(<promise>): <bool>
```

#### promise.isPending

Returns true if the promise is pending to be resolved or errored

**signature**

```lua
<promise>:isPending(): <bool>
```

```lua
promise.isPending(<promise>): <bool>
```

### promise.all

Takes a sequential table of promises and returns a new promise that will
be resolved when all the promises are resolved.

The promise will be resolved with a table containing the result of all the resolved promises.

**signature**

```lua
all(<promise[]>): <any[]>
```

### promise.waitForAll

Same as [all](#all) but await directly

**signature**

```lua
promise.waitForAll(<promise[]>): <any[]>
```

### promise.any

Takes a sequential table of promises and returns a new promise that will
be resolved when one of the promises is resolved.

The promise will be resolved with the result of the first resolved promise.

**signature**

```lua
promise.any(<promise[]>): <any>
```

### promise.waitForAny

Same as [any](#any) but await directly

**signature**

```lua
promise.waitForAny(<promise[]>): <any>
```
