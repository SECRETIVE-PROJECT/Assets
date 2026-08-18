local Janitor = {}
Janitor.__index = Janitor

local function GetCleanupMethod(Object)
	local DataType, LuaType = typeof(Object), type(Object)
	if DataType == "RBXScriptConnection" then
		return "Disconnect"
	elseif DataType == "Instance" then
		return "Destroy"
	elseif LuaType == "function" or LuaType == "thread" then
		return true
	elseif LuaType == "table" then
		for _, Method in { "Destroy", "Disconnect", "Cleanup" } do
			if Object[Method] then
				return Method
			end
		end
	end
	error("Janitor could not infer a cleanup method", 3)
end

local function CleanupTask(Task)
	local Object, Method = Task.Object, Task.Method
	local Success, CleanupError = pcall(function()
		if Method == true then
			if type(Object) == "thread" then
				if coroutine.status(Object) ~= "dead" then
					task.cancel(Object)
				end
			else
				Object()
			end
		elseif type(Method) == "function" then
			Method(Object)
		else
			Object[Method](Object)
		end
	end)
	if not Success then
		warn("Janitor cleanup failed: " .. tostring(CleanupError))
	end
end

Janitor["new"] = function()
	return setmetatable({ Tasks = {}, Indexes = {}, Destroyed = false }, Janitor)
end

Janitor["Add"] = function(Self, Object, Method, Index)
	if Object == nil then
		return nil
	end

	local Task = { Object = Object, Method = Method or GetCleanupMethod(Object), Index = Index }
	if Self.Destroyed then
		CleanupTask(Task)
		return Object
	end
	if Index ~= nil then
		Self:Remove(Index)
		Self.Indexes[Index] = Task
	end
	Self.Tasks[Task] = true
	return Object
end

Janitor["Remove"] = function(Self, Index)
	local Task = Self.Indexes[Index]
	if not Task then
		return false
	end
	Self.Indexes[Index], Self.Tasks[Task] = nil, nil
	CleanupTask(Task)
	return true
end

Janitor["Connect"] = function(Self, Event, Callback, Index, Immediate)
	if type(Index) == "boolean" then
		Immediate, Index = Index, nil
	end

	local Connection = Self:Add(Event:Connect(Callback), "Disconnect", Index)
	if Immediate then
		Callback()
	end
	return Connection
end

Janitor["Extend"] = function(Self, Index)
	return Self:Add(Janitor.new(), "Destroy", Index)
end

Janitor["Cleanup"] = function(Self)
	for Task in next, Self.Tasks do
		Self.Tasks[Task] = nil
		if Task.Index ~= nil then
			Self.Indexes[Task.Index] = nil
		end
		CleanupTask(Task)
	end
end

Janitor["Destroy"] = function(Self)
	Self.Destroyed = true
	Self:Cleanup()
end

Janitor["Unload"] = function(Self, Signal)
	Signal:Fire()
	Self:Destroy()
end

return Janitor
