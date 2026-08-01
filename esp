local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local heartbeat_connection

local module = {
    interval = 1 / 60
}

local Group = {}
Group.__index = Group

local groups = {}

function module.group(functions, config)
    if not functions or type(functions) ~= "table" then return end
    if not (functions.Create and functions.Render and functions.Update) then return end

    local self = setmetatable({
        config = config or {},
        functions = functions,
        tracked = {},
    }, Group)

    table.insert(groups, self)
    return self
end

function Group:add(instance)
    local entry = {
        instance = instance,
        drawings = {},
    }

    self.functions.Create(entry)
    self.functions.Update(entry)

    self.tracked[instance] = entry

    return entry
end

function Group:remove(instance)
    local entry = self.tracked[instance]

    if not entry then
        return
    end

    self.tracked[instance] = nil

    for _, drawing in entry.drawings do
        drawing:Remove()
    end
end

function Group:setSetting(setting, property)
    if not setting or not property then return end

    self.config[setting] = property
    Group:_update()
end

function Group:getSetting(setting)
    if not setting then return end

    return self.config and self.config[setting]
end

function Group:_update()
    for _, entry in self.tracked do
        self.functions.Update(entry)
    end
end

function Group:_render()
    for _, entry in self.tracked do
        self.config.Render(entry)
    end
end

function Group:destroy()
    for instance in self.tracked do
        self:remove(instance)
    end

    table.clear(self.tracked)
end


function module.init()
    local accumulator = 0
    
    heartbeat_connection = RunService.Heartbeat:Connect(function(dt)
        accumulator += dt
    
        if accumulator < module.interval then
            return
        end
        accumulator -= module.interval

        for _, group in groups do 
            group:_render()
        end
    end)
end

function module.Destroy()
    if heartbeat_connection then
        heartbeat_connection:Disconnect()
        heartbeat_connection = nil
    end

    for _, group in groups do
        group:destroy()
    end
    table.clear(groups)
end

return module
