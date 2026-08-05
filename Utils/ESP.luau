local RunService = game:GetService("RunService")

local heartbeat_connection
local descendant_removing_connection

local module = {
    interval = 1 / 60
}

local Group = {}
Group.__index = Group

local groups = {}
local instanceToGroups = {}

local function onDescendantRemoving(descendant)
    local trackingGroups = instanceToGroups[descendant]
    if not trackingGroups then return end

    for group in trackingGroups do
        group:Remove(descendant)
    end
end

function module.new(definition)
    if not definition or type(definition) ~= "table" then return end
    if not (definition.Create and definition.Render and definition.Update) then return end

    local self = setmetatable({
        config = definition.Config or {},
        create = definition.Create,
        update = definition.Update,
        render = definition.Render,
        tracked = {},
    }, Group)

    table.insert(groups, self)
    return self
end

function Group:Add(instance)
    if self.tracked[instance] then return end

    local entry = {
        instance = instance,
        drawings = {},
    }

    self.create(self, entry)
    self.update(self, entry)

    self.tracked[instance] = entry

    instanceToGroups[instance] = instanceToGroups[instance] or {}
    instanceToGroups[instance][self] = true

    return entry
end

function Group:Remove(instance)
    local entry = self.tracked[instance]
    if not entry then return end

    self.tracked[instance] = nil

    if instanceToGroups[instance] then
        instanceToGroups[instance][self] = nil
        if not next(instanceToGroups[instance]) then
            instanceToGroups[instance] = nil
        end
    end

    for _, drawing in entry.drawings do
        drawing:Remove()
    end
end

function Group:SetSetting(setting, property)
    if not setting or property == nil then return end

    self.config[setting] = property
    self:_update()
end

function Group:GetSetting(setting)
    if not setting then return end

    return self.config and self.config[setting]
end

function Group:_update()
    for _, entry in self.tracked do
        self.update(self, entry)
    end
end

function Group:_render()
    for _, entry in self.tracked do
        self.render(self, entry)
    end
end

function Group:Destroy()
    for instance in self.tracked do
        self:Remove(instance)
    end

    table.clear(self.tracked)

    table.remove(table.find(groups, self))
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

    descendant_removing_connection = workspace.DescendantRemoving:Connect(onDescendantRemoving)
end

function module.CreateDrawing(type, properties)
    local drawing = Drawing.new(type)

    for i,v in properties do
        drawing[i] = v
    end

    return drawing
end

function module.HideDrawings(drawings)
    for _, drawing in drawings do
        if isrenderobj(drawing) then
            drawing.Visible = false
        else
            for _, obj in drawing do
                obj.Visible = false
            end
        end
    end
end

function module.Destroy()
    if heartbeat_connection then
        heartbeat_connection:Disconnect()
        heartbeat_connection = nil
    end

    if descendant_removing_connection then
        descendant_removing_connection:Disconnect()
        descendant_removing_connection = nil
    end

    for _, group in groups do
        group:Destroy()
    end
    table.clear(groups)

    table.clear(instanceToGroups)
end

return module
