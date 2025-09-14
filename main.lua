-- libs
local library, flags = loadstring(game:HttpGet("https://raw.githubusercontent.com/skkydoesstuff/RobloxMenu2/refs/heads/main/uilibrary.lua"))()

-- global vars
local cas = game:GetService("ContextActionService")
local rs = game:GetService("RunService")
local uis = game:GetService("UserInputService")
local players = game:GetService("Players")
local localPlayer = players.LocalPlayer
local windowFocused = false

local humanoid = localPlayer.Character:FindFirstChild("Humanoid")

-- test
cas:BindActionAtPriority("DisableArrowKeys", function()
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right)

-- exploit vars
local espEnabled = false
local espObjects = {}

local partFolder = Instance.new("Folder")
partFolder.Parent = workspace
partFolder.Name = "Part Folder"

local partFlyEnabled = false
local partFlySpeed = 10
local moveDirection = Vector3.new(0, 0, 0)
local safetyPart = nil

local defaultJumpHeight = humanoid.JumpHeight
local speedEnabled = false
local defaultMultiplier = 0.5
local walkSpeedMultiplier = defaultMultiplier

local ZERO_VECTOR = Vector3.zero
local UP_VECTOR = Vector3.yAxis
local DOWN_VECTOR = -Vector3.yAxis

local MOVE_KEYS = {
    W = function(look, right) return Vector3.new(look.X, 0, look.Z) end,
    S = function(look, right) return -Vector3.new(look.X, 0, look.Z) end,
    A = function(look, right) return -right end,
    D = function(look, right) return right end,
}

local AimbotEnabled = false
local AimbotFOV = 100 -- radius in pixels
local AimbotKey = Enum.KeyCode.E
local AimPart = "Head" -- part to aim at
local lockedTarget = nil

local fovCircle = Drawing.new("Circle")
fovCircle.Color = Color3.fromRGB(225, 58, 81)
fovCircle.Thickness = 1
fovCircle.Radius = AimbotFOV
fovCircle.Transparency = 0.6
fovCircle.Filled = false
fovCircle.Visible = true

local Mouse = localPlayer:GetMouse()

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

local function updateESP()
    -- Don't update ESP if window isn't focused
    if not windowFocused then return end
    
    local camera = workspace.CurrentCamera
    for _, p in pairs(players:GetPlayers()) do
        if p ~= localPlayer and p.Character and p.Character.Parent and p.Character:FindFirstChild("HumanoidRootPart") and p.Character:FindFirstChild("Head") then
            if not espObjects[p] then
                createBoxForPlayer(p)
            end

            local objs = espObjects[p]
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            local head = p.Character:FindFirstChild("Head")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")

            if hrp and head and hum and hum.Health > 0 then
                local hrpPos, hrpOn = camera:WorldToViewportPoint(hrp.Position)
                local headPos, headOn = camera:WorldToViewportPoint(head.Position + Vector3.new(0,0.5,0))
                local legPos, legOn = camera:WorldToViewportPoint(hrp.Position - Vector3.new(0,3,0))

                if hrpOn and headOn and headPos and legPos then
                    local height = math.abs(legPos.Y - headPos.Y)
                    if height < 1 then height = 1 end
                    local width = height / 2

                    objs.outline.Size = Vector2.new(width, height)
                    objs.outline.Position = Vector2.new(hrpPos.X - width/2, headPos.Y)
                    objs.outline.Visible = espEnabled -- Only show if ESP is enabled

                    objs.box.Size = Vector2.new(width, height)
                    objs.box.Position = Vector2.new(hrpPos.X - width/2, headPos.Y)
                    objs.box.Visible = espEnabled -- Only show if ESP is enabled
                else
                    objs.outline.Visible = false
                    objs.box.Visible = false
                end
            else
                if objs then
                    objs.outline.Visible = false
                    objs.box.Visible = false
                end
            end
        else
            if espObjects[p] then
                if espObjects[p].box then espObjects[p].box:Remove() end
                if espObjects[p].outline then espObjects[p].outline:Remove() end
                espObjects[p] = nil
            end
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
            espObjects[player] = nil
        end
    end
end

local function removeAllEsp()
    for i,v in pairs(players:GetChildren()) do
        removeESP(v)
    end
end

local function isTyping()
    return uis:GetFocusedTextBox() ~= nil
end

local function updateFlyMovement(dt)
    local char = localPlayer.Character
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")

    if not partFlyEnabled or not safetyPart then return end
    if not workspace.CurrentCamera then return end

    local moveDir = ZERO_VECTOR
    local camera = workspace.CurrentCamera

    -- Vertical movement always works
    if uis:IsKeyDown(Enum.KeyCode.Space) then
        moveDir += UP_VECTOR
    elseif uis:IsKeyDown(Enum.KeyCode.LeftControl) or uis:IsKeyDown(Enum.KeyCode.RightControl) then
        moveDir += DOWN_VECTOR
    end

    -- Horizontal movement only if not typing
    if not isTyping() then
        local lookVector = camera.CFrame.LookVector
        local rightVector = camera.CFrame.RightVector
        for key, getVector in pairs(MOVE_KEYS) do
            if uis:IsKeyDown(Enum.KeyCode[key]) then
                moveDir += getVector(lookVector, rightVector)
            end
        end
    end

    -- Normalize and apply speed
    if moveDir.Magnitude > 0 then
        moveDir = moveDir.Unit * partFlySpeed
    end

    -- Smooth position update
    local targetPos = safetyPart.Position + (moveDir * dt)
    safetyPart.Position = safetyPart.Position:Lerp(targetPos, 0.5)

    -- Smooth character update
    local targetCFrame = CFrame.new(safetyPart.Position + Vector3.new(0, 3, 0))
    hrp.CFrame = hrp.CFrame:Lerp(targetCFrame, 0.5)

    -- Prevent velocity flinging
    hrp.Velocity = ZERO_VECTOR
    hrp.RotVelocity = ZERO_VECTOR
end

local function startPartFly()
    local char = localPlayer.Character
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")

    if safetyPart then return end
    
    safetyPart = Instance.new("Part")
    safetyPart.Size = Vector3.new(2, 0.5, 2)
    safetyPart.Anchored = true
    safetyPart.CanCollide = false
    safetyPart.Transparency = 0.5
    safetyPart.BrickColor = BrickColor.new("Bright blue")
    safetyPart.Name = "SafetyPart"
    safetyPart.Parent = partFolder

    partFlyEnabled = true
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    humanoid.JumpHeight = 0
    
    safetyPart.Position = hrp.Position - Vector3.new(0, 3.25, 0)
    
    -- Reduce flinging risk
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CustomPhysicalProperties = PhysicalProperties.new(0.1, 0, 0, 0, 0)
        end
    end
end

local function stopPartFly()
    local char = localPlayer.Character
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")

    if safetyPart then
        safetyPart:Destroy()
        safetyPart = nil
    end
    partFolder:ClearAllChildren()
    partFlyEnabled = false
    
    humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
    task.wait(0.1)
    humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
    humanoid.JumpHeight = defaultJumpHeight
    
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5)
        end
    end
end

local function GetClosestPlayer()
    -- If we already locked a target, validate and keep it if still valid
    if lockedTarget then
        local p = lockedTarget
        if p and p.Character and p.Character.Parent and p.Character:FindFirstChild(AimPart) then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                return p
            end
        end
        -- target invalid -> clear lock
        lockedTarget = nil
    end

    -- Not locked yet: search for closest within FOV and lock the first suitable player
    local closestPlayer = nil
    local shortestDistance = AimbotFOV

    for _, player in pairs(players:GetPlayers()) do
        if player ~= localPlayer and player.Character and player.Character:FindFirstChild(AimPart) then
            local part = player.Character[AimPart]
            local screenPos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(part.Position)

            if onScreen and screenPos then
                local mousePos = Vector2.new(Mouse.X, Mouse.Y)
                local targetPos = Vector2.new(screenPos.X, screenPos.Y)
                local distance = (mousePos - targetPos).Magnitude

                if distance < shortestDistance then
                    shortestDistance = distance
                    closestPlayer = player
                end
            end
        end
    end

    -- If we found someone, lock onto them and return
    if closestPlayer then
        lockedTarget = closestPlayer
        return closestPlayer
    end

    return nil
end

-- for aimlock
-- Detect when right-click is pressed or released
uis.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then -- Right click
        isRightClicking = true
    end
end)

uis.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then -- Right click
        isRightClicking = false
        if lockedTarget ~= nil then lockedTarget = nil end
    end
end)

-- anything that needs to be updated frequently gets added here
rs.Heartbeat:Connect(function(dt)
    if espEnabled then
        updateESP()
    end
    if partFlyEnabled then
        updateFlyMovement(dt)
    end
    if speedEnabled then
        local moveDirection = humanoid.MoveDirection
        local hrp = localPlayer.Character:FindFirstChild("HumanoidRootPart")
        if moveDirection.Magnitude > 0 then
            hrp.CFrame = hrp.CFrame + (moveDirection * walkSpeedMultiplier * dt)
        end
    end

        -- Only show FOV circle if window is focused
    fovCircle.Position = Vector2.new(Mouse.X, Mouse.Y + (AimbotFOV/2))
    fovCircle.Radius = AimbotFOV
    fovCircle.Visible = AimbotEnabled and windowFocused

    if AimbotEnabled and isRightClicking and windowFocused then
        local target = GetClosestPlayer()
        if target and target.Character and target.Character:FindFirstChild(AimPart) then
            workspace.CurrentCamera.CFrame = CFrame.new(
                workspace.CurrentCamera.CFrame.Position,
                target.Character[AimPart].Position
            )
        end
    end
end)

-- UI
local mainTab = library:AddTab("Main")

mainTab:AddToggle({
    text = "ESP",
    flag = "esp",
    default = false,
    callback = function(state)
        espEnabled = state
        if not state then
            removeAllEsp()
        end
    end
})

local drow

mainTab:AddKeybind({
    text = "Toggle PartFly",
    default = "X",
    callback = function()
        if partFlyEnabled then
            stopPartFly()
        else
            startPartFly()
        end
        print("PartFly toggled:", partFlyEnabled)
    end
})

mainTab:AddSlider({
    text = "flightSpeed",   -- The text label that shows up
    min = 10,             -- Minimum value
    max = 1000,            -- Maximum value
    default = 10,         -- Starting value
    suffix = "",          -- Optional text to append (e.g., "ms" or "%")
    flag = "flightSpeed",   -- (Optional) a unique key to track the slider value
    callback = function(val)
        partFlySpeed = val
    end
})

mainTab:AddKeybind({
    text = "Toggle Speed",
    default = "Z",
    callback = function()
        speedEnabled = not speedEnabled
    end
})

mainTab:AddSlider({
    text = "Speed",   -- The text label that shows up
    min = .5,             -- Minimum value
    max = 1000,            -- Maximum value
    default = .5,         -- Starting value
    suffix = "",          -- Optional text to append (e.g., "ms" or "%")
    flag = "walkspeed",   -- (Optional) a unique key to track the slider value
    callback = function(val)
        walkSpeedMultiplier = val
    end
})

mainTab:AddKeybind({
    text = "Toggle Aim Lock",
    default = "c",
    callback = function()
        AimbotEnabled = not AimbotEnabled
    end
})

mainTab:AddSlider({
    text = "Aim Lock Fov",   -- The text label that shows up
    min = 100,             -- Minimum value
    max = 1000,            -- Maximum value
    default = AimbotFOV,         -- Starting value
    suffix = "",          -- Optional text to append (e.g., "ms" or "%")
    flag = "aimbotfov",   -- (Optional) a unique key to track the slider value
    callback = function(val)
        AimbotFOV = val
    end
})

--cleanup
players.PlayerRemoving:Connect(function(p)
    if lockedTarget == p then
        lockedTarget = nil
    end
    removeESP(p)
    mainTab:Unload()
end)
