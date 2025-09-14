-- libs
local library, flags = loadstring(game:HttpGet("https://raw.githubusercontent.com/skkydoesstuff/RobloxMenu2/refs/heads/main/uilibrary.lua"))()

-- global vars
local rs = game:GetService("RunService")
local uis = game:GetService("UserInputService")
local players = game:GetService("Players")
local localPlayer = players.LocalPlayer
local windowFocused = false

-- exploit vars
local espEnabled = false
local espObjects = {}

--check if window focused
uis.WindowFocusReleased:Connect(function()
    windowFocused = false
    -- Hide all ESP when window loses focus
    if espEnabled then
        for player, esp in pairs(espObjects) do
            if esp.box then esp.box.Visible = false end
            if esp.outline then esp.outline.Visible = false end
        end
    end
    -- Also hide FOV circle
    --fovCircle.Visible = false
end)

uis.WindowFocused:Connect(function()
    windowFocused = true
end)

-- exploit implementations
local function createBoxForPlayer(p)
    if espObjects[p] then return end

    local boxOutline = Drawing.new("Square")
    boxOutline.Visible = false
    boxOutline.Color = Color3.new(255,0,0)
    boxOutline.Thickness = 3
    boxOutline.Transparency = 1
    boxOutline.Filled = false

    local box = Drawing.new("Square")
    box.Visible = false
    box.Color = Color3.fromRGB(255,255,255)
    box.Thickness = 1
    box.Transparency = 1
    box.Filled = false

    espObjects[p] = {box = box, outline = boxOutline}
end

local function removeESP(playerToRemove)
    if playerToRemove then
        local esp = espObjects[playerToRemove]
        if esp then
            if esp.box then esp.box:Remove() end
            if esp.outline then esp.outline:Remove() end
            espObjects[playerToRemove] = nil
        end
    else
        for player, esp in pairs(espObjects) do
            if esp.box then esp.box:Remove() end
            if esp.outline then esp.outline:Remove() end
            espObjects[player] = nil
        end
    end
end

local function removeAllEsp()
    for i,v in pairs(players:GetChildren()) do
        removeESP(v)
    end
end

local function setESPVisibility(objs, visible)
    if objs then
        objs.outline.Visible = visible
        objs.box.Visible = visible
    end
end


local function updateESP()
    if not windowFocused then return end

    local camera = workspace.CurrentCamera
    for _, p in pairs(players:GetPlayers()) do
        if p ~= localPlayer then
            local char = p.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local head = char and char:FindFirstChild("Head")
            local hum  = char and char:FindFirstChildOfClass("Humanoid")

            -- Ensure ESP object exists
            if char and hrp and head and hum and hum.Health > 0 then
                if not espObjects[p] then
                    createBoxForPlayer(p)
                end

                local objs = espObjects[p]
                if objs then
                    local hrpPos, hrpOn   = camera:WorldToViewportPoint(hrp.Position)
                    local headPos, headOn = camera:WorldToViewportPoint(head.Position + Vector3.new(0,0.5,0))
                    local legPos, legOn   = camera:WorldToViewportPoint(hrp.Position - Vector3.new(0,3,0))

                    if hrpOn and headOn and legOn then
                        local height = math.max(1, math.abs(legPos.Y - headPos.Y))
                        local width  = height / 2
                        local pos    = Vector2.new(hrpPos.X - width/2, headPos.Y)

                        objs.outline.Size, objs.box.Size = Vector2.new(width, height), Vector2.new(width, height)
                        objs.outline.Position, objs.box.Position = pos, pos
                        setESPVisibility(objs, espEnabled)
                    else
                        setESPVisibility(objs, false)
                    end
                end
            else
                -- Clean up if no valid character
                removeESP(p)
            end
        else
            removeESP(p)
        end
    end
end

local function removeESP(playerToRemove)
    if playerToRemove then
        local esp = espObjects[playerToRemove]
        if esp then
            if esp.box then esp.box:Remove() end
            if esp.outline then esp.outline:Remove() end
            espObjects[playerToRemove] = nil
        end
    else
        for player, esp in pairs(espObjects) do
            if esp.box then esp.box:Remove() end
            if esp.outline then esp.outline:Remove() end
        end
        espObjects = {}
    end
end

-- anything that needs to be updated frequently gets added here
rs.Heartbeat:Connect(function()
    if espEnabled then
        updateESP()
    end
end)

-- checks and updates
local function check()
    if espEnabled == true then
        updateESP()
    else
        removeAllEsp()
    end
end

-- UI
local mainTab = library:AddTab("Main")

mainTab:AddToggle({
    text = "ESP",
    flag = "esp",
    default = false,
    callback = function(state)
        espEnabled = true
        check()
    end
})

-- cleanup
local function cleanupDrawings()
    for i,v in pairs(players:GetChildren()) do
        removeESP(v)
    end
end

players.PlayerRemoving:Connect(function(p)
    if p == localPlayer then
        library:Unload()
        cleanupDrawings()
    end
end)