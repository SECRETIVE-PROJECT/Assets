local Signal = {}
Signal.__index = Signal

local function Disconnect(Self)
	Self.Connected = false
	Self.Signal.Connections[Self] = nil
end

Signal["new"] = function()
	return setmetatable({ Connections = {}, Waiting = {} }, Signal)
end

Signal["Connect"] = function(Self, Callback)
	local Connection = { Connected = true, Signal = Self, Disconnect = Disconnect, Destroy = Disconnect }
	Self.Connections[Connection] = Callback
	return Connection
end

Signal["Once"] = function(Self, Callback)
	local Connection = Self:Connect(Callback)
	Connection.Once = true
	return Connection
end

Signal["Fire"] = function(Self, ...)
	local Arguments, Pending = table.pack(...), {}
	for Connection, Callback in next, Self.Connections do
		if Connection.Connected then
			Pending[#Pending + 1] = { Connection, Callback }
		end
	end
	for _, Item in next, Pending do
		local Connection, Callback = Item[1], Item[2]
		if Connection.Once then
			Connection:Disconnect()
		end
		task.spawn(Callback, table.unpack(Arguments, 1, Arguments.n))
	end

	for Thread in next, Self.Waiting do
		Self.Waiting[Thread] = nil
		task.spawn(Thread, table.unpack(Arguments, 1, Arguments.n))
	end
end

Signal["Invoke"] = function(Self, ...)
	for Connection, Callback in Self.Connections do
		if Connection.Connected then
			if Connection.Once then Connection:Disconnect() end
			return Callback(...)
		end
	end
end

Signal["Wait"] = function(Self)
	local Thread = coroutine.running()
	Self.Waiting[Thread] = true
	return coroutine.yield()
end

Signal["Destroy"] = function(Self)
	for Connection in next, Self.Connections do
		Connection.Connected = false
	end
	for Thread in next, Self.Waiting do
		task.spawn(Thread)
	end
	table.clear(Self.Connections)
	table.clear(Self.Waiting)
end

return Signal
