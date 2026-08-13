local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Player = cloneref(Players.LocalPlayer);
local Camera = cloneref(workspace.CurrentCamera);

local playerInstances = {}
local connections = {}

local Group = {}
Group.__index = Group

local groups = {}
local instanceToGroups = {}

local renderAccumulator, groupAccumulator = 0, 0

local HEALTH_BAR_OFFSET = Vector2.new(6, 0);
local HEALTH_TEXT_OFFSET = Vector2.new(7, 0);
local HEALTH_BAR_OUTLINE_OFFSET = Vector2.new(0, 1);
local NAME_OFFSET = Vector2.new(0, 6);
local DISTANCE_OFFSET = Vector2.new(0, 6);
local VERTICES = {
	Vector3.new(-1, -1, -1),
	Vector3.new(-1, 1, -1),
	Vector3.new(-1, 1, 1),
	Vector3.new(-1, -1, 1),
	Vector3.new(1, -1, -1),
	Vector3.new(1, 1, -1),
	Vector3.new(1, 1, 1),
	Vector3.new(1, -1, 1)
};

local module = {
    interval = 1 / 60
}

module.config = {
    espType = "box",

    box = {
        Enabled = false,
        Color = Color3.fromRGB(253, 158, 247),
    },
    boxOutline = {
        Enabled = false,
        Color = Color3.fromRGB(0, 0, 0),
    },
    boxFill = {
        Enabled = false,
        Color = Color3.fromRGB(253, 158, 247),
        Transparency = 0.85,
    },
    
    name = {
        Enabled = false,
        Color = Color3.fromRGB(255,255,255),
        Transparency = 0,
        Outline = true,
        OutlineColor = Color3.fromRGB(0, 0, 0),
        Size = 12,
        Font = 3,
    },
    group = {
        Enabled = false,
        Color = Color3.fromRGB(255,255,255),
        Transparency = 0,
        Outline = true,
        OutlineColor = Color3.fromRGB(0, 0, 0),
        Size = 9,
        Font = 3,
    },
    distance = {
        Enabled = false,
        Color = Color3.fromRGB(255,255,255),
        Transparency = 0,
        Outline = true,
        OutlineColor = Color3.fromRGB(0, 0, 0),
        Size = 9,
        Font = 3,
    },

    healthText = {
        Enabled = false,
        Color = Color3.fromRGB(255,255,255),
        Transparency = 0,
        Outline = true,
        OutlineColor = Color3.fromRGB(0, 0, 0),
        Size = 9,
        Font = 3,
    },
    healthBarOutline = {
        Enabled = false,
        Color = Color3.fromRGB(0, 0, 0),
        Transparency = 0,
    },
    healthBar = {
        Enabled = false,
        HealthyColor = Color3.new(0,1,0),
        DyingColor = Color3.new(1,0,0),
    },

    corners = {
        Enabled = false, 
        Color = Color3.fromRGB(253, 158, 247),
    },
    cornersOutline = {
        Enabled = false, 
        Color = Color3.fromRGB(0, 0, 0),
    },
}

local settingMap = {}
for k,_ in module.config do
    settingMap[k:lower()] = k
end

local playerObject: { { player: Player } } = {}
playerObject.__index = playerObject

local function createDrawing(type, properties)
    local drawing = Drawing.new(type)

    for i,v in properties do
        drawing[i] = v
    end

    return drawing
end

local function onDescendantRemoving(descendant)
    local trackingGroups = instanceToGroups[descendant]
    if not trackingGroups then return end

    for group in trackingGroups do
        group:Remove(descendant)
    end
end

local function getBoundingBox(instance)
    local min, max
    for _, part in {instance, table.unpack(instance:GetChildren())} do
        if not part:IsA("BasePart") then
            continue
        end

        local cframe, size = part.CFrame, part.Size

        min = Vector3.zero.Min(min or cframe.Position, (cframe - size * 0.5).Position)
        max = Vector3.zero.Max(max or cframe.Position, (cframe + size * 0.5).Position)
    end

    if not min then
        return CFrame.identity, Vector3.zero
    end

    local center = (min + max) * 0.5
    return CFrame.new(center), max - min
end

local function worldToScreen(world)
	local screen, onScreen = Camera:WorldToViewportPoint(world);
	return Vector2.new(screen.X, screen.Y), onScreen, screen.Z;
end

local function calculateCorners(cframe, size)
	local corners = table.create(#VERTICES);
	for i = 1, #VERTICES do
		corners[i] = worldToScreen((cframe + size * 0.5 * VERTICES[i]).Position);
	end

	local min = Vector2.zero.Min(Camera.ViewportSize, unpack(corners));
	local max = Vector2.zero.Max(Vector2.zero, unpack(corners));

	return {
        topLeft = Vector2.new(min.X, min.Y):Floor(),
        topRight = Vector2.new(max.X, min.Y):Floor(),
        bottomLeft = Vector2.new(min.X, max.Y):Floor(),
        bottomRight = Vector2.new(max.X, max.Y):Floor(),
	};
end

function playerObject.new(player: Player)
    local self = setmetatable({
        player = player,
        drawings = {
            boxFill = createDrawing("Square", { Filled = true, Visible = false }),
            boxOutline = createDrawing("Square", { Thickness = 2, Visible = false }),
            box = createDrawing("Square", { Thickness = 1, Visible = false, ZIndex = 2, }),
            healthBarOutline = createDrawing("Line", { Thickness = 3, Visible = false }),
			healthBar = createDrawing("Line", { Thickness = 1, Visible = false }),
			healthText = createDrawing("Text", { Center = true, Visible = false }),
			name = createDrawing("Text", { Text = player.DisplayName, Center = true, Visible = false }),
            group = createDrawing("Text", { Center = true, Visible = false }),
			distance = createDrawing("Text", { Center = true, Visible = false }),

            corners = {},
            cornersOutline = {},
        },
        connections = {},
        character = nil,
    }, playerObject)
   
    for _, v in {"topLeft", "topRight", "bottomLeft", "bottomRight"} do
        self.drawings.cornersOutline[v.."_vertical"], self.drawings.cornersOutline[v.."_horizontal"] = createDrawing("Line", { Thickness = 2, Visible = false }), createDrawing("Line", { Thickness = 2, Visible = false, ZIndex = 1, })
        self.drawings.corners[v.."_vertical"], self.drawings.corners[v.."_horizontal"] = createDrawing("Line", { Thickness = 1, Visible = false }), createDrawing("Line", { Thickness = 1, Visible = false, ZIndex = 2, })
    end 

    local function characterAdded(character: Model)
        local humanoid = character and character:WaitForChild("Humanoid", 10)
        if not player:IsDescendantOf(Players) or not humanoid or humanoid.Health <= 0 then
            return
        end

        self.character = character
        self:Update()

        self.connections["died"] = humanoid.Died:Once(function()
            self.character = nil

            self:HideDrawings()
        end)
    end

    if player.Character then
        characterAdded(player.Character)
    end
    self.connections["characteradded"] =  player.CharacterAdded:Connect(characterAdded)

    playerInstances[player.UserId] = self
    return self
end

function playerObject:HideDrawings()
    for _, drawing in self.drawings do
        if not isrenderobj(drawing) then
            for _,v in drawing do
                v.Visible = false 
            end
        else
            drawing.Visible = false
        end
    end
end

function playerObject:Update()
    local humanoid = self.character and self.character:FindFirstChild("Humanoid")
    local head = humanoid and self.character:FindFirstChild("Head")

    if not humanoid or not head then
        return
    end

    for i, v in { self.drawings.cornersOutline, self.drawings.corners } do
        for _, obj in v do
            obj.Color = if i == 2 then module.config.corners.Color else module.config.cornersOutline.Color
        end 
    end
    
    for name, drawing in self.drawings do
        local config = module.config[name]
        if not config or name == "cornersOutline" or name == "corners" then
            continue
        end

        for property, value in config do
            if property == "Enabled" then continue end
            
            if property == "Transparency" then 
                drawing[property] = 1 - value 
                continue 
            end

            drawing[property] = value
        end
    end 
end

function playerObject:Render()
    local humanoid = self.character and self.character:FindFirstChild("Humanoid")
    local head = humanoid and self.character:FindFirstChild("Head")

    if not humanoid or not head then
        return self:HideDrawings()
    end

    local _, onScreen, depth = worldToScreen(head.Position);

    if not onScreen then
        return self:HideDrawings()
    end

    local corners = calculateCorners(getBoundingBox(self.character));

    for i, v in { self.drawings.cornersOutline, self.drawings.corners } do
        local visible = (if i == 2 then module.config.corners.Enabled else module.config.cornersOutline.Enabled) and module.config.espType == "corners"

        for corner, obj in v do
            obj.Visible = visible 
            if not visible then
                continue 
            end

            local corner, direction = table.unpack(string.split(corner, "_"))
            local boxSize = corners.bottomRight - corners.topLeft
            
            local vertMul  = string.find(corner:lower(), "top") and 1 or -1
            local horizMul = string.find(corner:lower(), "left") and 1 or -1

            local offset = direction == "vertical" and Vector2.new(0, boxSize.Y * 0.2 * vertMul) or Vector2.new(boxSize.X * 0.2 * horizMul, 0)
        
            obj.To = corners[corner] + offset
            obj.From = corners[corner]
        end 
    end

    local box = self.drawings.box
    box.Visible = module.config.box.Enabled and module.config.espType == "box"
    if box.Visible then
        box.Position = corners.topLeft
        box.Size = corners.bottomRight - corners.topLeft
    end

    local boxOutline = self.drawings.boxOutline
    boxOutline.Visible = module.config.boxOutline.Enabled and module.config.espType == "box"
    if boxOutline.Visible then
        boxOutline.Position = corners.topLeft
        boxOutline.Size = corners.bottomRight - corners.topLeft
    end

    local boxFill = self.drawings.boxFill
    boxFill.Visible = module.config.boxFill.Enabled
    if boxFill.Visible then
        boxFill.Position = corners.topLeft
        boxFill.Size = corners.bottomRight - corners.topLeft
    end

    local groupInfo = self.group 
    local group = self.drawings.group
    group.Visible = module.config.group.Enabled and groupInfo ~= nil
    if group.Visible then
        group.Position = (corners.topLeft + corners.topRight) * 0.5 - Vector2.yAxis * group.TextBounds.Y - NAME_OFFSET;
    end

    local name = self.drawings.name
    name.Visible = module.config.name.Enabled
    if name.Visible then
        local position = (corners.topLeft + corners.topRight) * 0.5 - Vector2.yAxis * name.TextBounds.Y - NAME_OFFSET
        
        if group.Visible then 
            position -= Vector2.new(0, group.Size)
        end 

        name.Position = position
    end

    local distance = self.drawings.distance
    distance.Visible = module.config.distance.Enabled
    if distance.Visible then
        distance.Text = `{math.round(depth)} studs`
        distance.Position = (corners.bottomLeft + corners.bottomRight) * 0.5 + DISTANCE_OFFSET;
    end

    local barFrom = corners.topLeft - HEALTH_BAR_OFFSET
    local barTo = corners.bottomLeft - HEALTH_BAR_OFFSET;

    local healthText = self.drawings.healthText
    healthText.Visible = module.config.healthText.Enabled
    if healthText.Visible then
        healthText.Text = `{math.round(humanoid.Health)} hp`
		healthText.Position = Vector2.zero.Lerp(barTo, barFrom, humanoid.Health/humanoid.MaxHealth) - healthText.TextBounds*0.5 - HEALTH_TEXT_OFFSET;
    end

    local healthBar = self.drawings.healthBar
    healthBar.Visible = module.config.healthBar.Enabled 
    if healthBar.Visible then
        healthBar.To = barTo;
		healthBar.From = Vector2.zero.Lerp(barTo, barFrom, humanoid.Health/humanoid.MaxHealth);
		healthBar.Color = Color3.new().Lerp(module.config.healthBar.HealthyColor, module.config.healthBar.DyingColor, humanoid.Health/humanoid.MaxHealth);
    end

    local healthBarOutline = self.drawings.healthBarOutline
    healthBarOutline.Visible = module.config.healthBarOutline.Enabled 
    if healthBarOutline.Visible then
        healthBarOutline.To = barTo + HEALTH_BAR_OUTLINE_OFFSET;
		healthBarOutline.From = barFrom - HEALTH_BAR_OUTLINE_OFFSET;
    end
end

function playerObject:Destroy()
    for _, drawing in self.drawings do
        if not isrenderobj(drawing) then -- it isn"t a drawing / is a table
            for _,v in drawing do
                v:Remove()
            end
        else
            drawing:Remove()
        end
    end

    for _, connection: RBXScriptConnection in self.connections do
        if connection.Connected then
            connection:Disconnect()
        end
    end
    table.clear(self.connections)
    
    playerInstances[self.player.UserId] = nil
end

function module.init(config)
    if config then 
        for setting, properties in module.config do
            if not config[setting] then
                continue 
            end

            for property in properties do
                local lower = property:lower()

                if config[setting][lower] then
                    module.config[setting][property] = config[setting][lower]
                end
            end
        end
    end

    for _, player: Player in Players:GetPlayers() do
        if compareinstances(player, Player) then
            continue
        end

        playerObject.new(player)
    end

    connections["playeradded"] = Players.PlayerAdded:Connect(playerObject.new)
    connections["playerremoving"] = Players.PlayerRemoving:Connect(function(player)
        if not playerInstances[player.UserId] then 
            return 
        end

        playerInstances[player.UserId]:Destroy()
    end)

    connections["heartbeat_connection"] = RunService.PreRender:Connect(function(dt)
        renderAccumulator += dt

        

        if renderAccumulator >= module.interval then
            renderAccumulator -= module.interval
            
            for _, v in playerInstances do
                if not v.character then
                    continue
                end
        
                v:Render()
            end

            for _, group in groups do 
                group:Render()
            end
        end

        if not module.GetGroup then return end
        groupAccumulator += dt

        if groupAccumulator >= 1 then
            groupAccumulator -= 1 
            
            for _, v in playerInstances do
                local groupInfo = module.GetGroup(v.player)
                v.group = groupInfo
    
                if groupInfo then
                    v.drawings.group.Text = groupInfo.Text
                    v.drawings.group.Color = groupInfo.Color
                end
            end
        end
    end)

    connections["descendant_removing"] = workspace.DescendantRemoving:Connect(onDescendantRemoving)
end

function module:SetSetting(setting, properties)
    local realSetting = settingMap[setting:lower()]
    if not realSetting then return end

    if type(module.config[realSetting]) == "table" then
        for prop, val in properties do
            for pk,_ in module.config[realSetting] do
                if pk:lower() == prop:lower() then
                    module.config[realSetting][pk] = val
                    break
                end
            end
        end
    else
        module.config[realSetting] = properties
    end

    for _, v in playerInstances do
        v:Update()
    end
end

function module:GetSetting(setting, property)
    local realSetting = settingMap[setting:lower()]
    if not realSetting then return end

    local value = module.config[realSetting]

    if type(value) ~= "table" then
        return value
    end

    for pk,_ in value do
        if pk:lower() == property:lower() then
            return value[pk]
        end
    end
end

function module.Destroy()
    for _, connection: RBXScriptConnection in connections do
        if connection.Connected then
            connection:Disconnect()
        end
    end
    table.clear(connections)

    for _, v in playerInstances do
        v:Destroy()
    end
    table.clear(playerInstances) -- already does this in the :Destroy() but why not

    module.config = nil
end

function module.new(config)
    if not config or type(config) ~= "table" then return end

    local self = setmetatable({
        config = config or {},
        tracked = {},
    }, Group)
    
    table.insert(groups, self)
    return self
end

function Group:Add(instance)
    if self.tracked[instance] then return end

    local entry = {
        instance = instance,
        drawings = {
            boxFill = createDrawing("Square", { Filled = true, Visible = false }),
            boxOutline = createDrawing("Square", { Thickness = 2, Visible = false }),
            box = createDrawing("Square", { Thickness = 1, Visible = false, ZIndex = 2, }),
            name = createDrawing("Text", { Text = instance.Name, Center = true, Visible = false }),
        },
    }
    
    self.tracked[instance] = entry
    self:Update(entry)

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


function Group:SetSetting(setting, properties)
    local realSetting = settingMap[setting:lower()]
    if not realSetting then return end

    if type(self.config[realSetting]) == "table" then
        for prop, val in properties do
            for pk,_ in self.config[realSetting] do
                if pk:lower() == prop:lower() then
                    self.config[realSetting][pk] = val
                    break
                end
            end
        end
    else
        self.config[realSetting] = properties
    end

    self:Update()
end

function Group:GetSetting(setting, property)
    local realSetting = settingMap[setting:lower()]
    if not realSetting then return end

    local value = self.config[realSetting]

    if type(value) ~= "table" then
        return value
    end

    for pk,_ in value do
        if pk:lower() == property:lower() then
            return value[pk]
        end
    end
end

function Group:Update(entry)
    for _, entry in entry and {entry} or self.tracked do
        for name, drawing in entry.drawings do
            local config = self.config[name]
            if not config then continue end
    
            for property, value in config do
                if property == "Enabled" then continue end
                
                if property == "Transparency" then 
                    drawing[property] = 1 - value 
                    continue 
                end
    
                drawing[property] = value
            end
        end 
    end
end

function Group:Render()
    for _, entry in self.tracked do
        local config = self.config
        local instance, drawings = entry.instance, entry.drawings 

        local _, onScreen, depth = worldToScreen(instance:GetPivot().Position);

        if not onScreen then
            for _, drawing in entry.drawings do
                drawing.Visible = false
            end
            continue
        end

        local corners = calculateCorners(getBoundingBox(instance));

        local box = drawings.box
        box.Visible = config.box.Enabled
        if box.Visible then
            box.Position = corners.topLeft
            box.Size = corners.bottomRight - corners.topLeft
        end
    
        local boxOutline = drawings.boxOutline
        boxOutline.Visible = config.boxOutline.Enabled
        if boxOutline.Visible then
            boxOutline.Position = corners.topLeft
            boxOutline.Size = corners.bottomRight - corners.topLeft
        end
    
        local boxFill = drawings.boxFill
        boxFill.Visible = config.boxFill.Enabled
        if boxFill.Visible then
            boxFill.Position = corners.topLeft
            boxFill.Size = corners.bottomRight - corners.topLeft
        end

        local name = drawings.name
        name.Visible = config.name.Enabled
        if name.Visible then
            local center = (corners.topLeft + corners.bottomRight) * 0.5

            name.Position = center - Vector2.new(0, name.TextBounds.Y / 2)
        end
    end
end

function Group:Destroy()
    for instance in self.tracked do
        self:Remove(instance)
    end

    table.clear(self.tracked)

    local index = table.find(groups,self)
    if index then
        table.remove(groups,index)
    end
end

return module
