--!strict

-----------------------------------
-- Module definition & state
-----------------------------------

local Signal = {}
Signal.__index = Signal

export type Connection = {
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = typeof(setmetatable(
	{} :: {
		_handlers: { [number]: (T...) -> () },
	},
	Signal
))

-----------------------------------
-- Public functions
-----------------------------------

function Signal.new<T...>(): Signal<T...>
	return (setmetatable({ _handlers = {} }, Signal) :: any) :: Signal<T...>
end

function Signal.Connect<T...>(self: Signal<T...>, fn: (T...) -> ()): Connection
	local id = #self._handlers + 1
	self._handlers[id] = fn

	return {
		Disconnect = function()
			self._handlers[id] = nil
		end,
	} :: Connection
end

function Signal.Fire<T...>(self: Signal<T...>, ...: T...)
	for _, fn in self._handlers do
		task.spawn(fn, ...)
	end
end

return Signal
