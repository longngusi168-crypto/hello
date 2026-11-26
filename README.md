--==================================================
-- MASTER NPC CONTROLLER V5.3 FIXED
--==================================================

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")

local LP = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local WALK_SPEED = 16
local SPRINT_SPEED = 30
local SEARCH_DISTANCE = 80

local NPC, Hum, Root
local Active = false
local Frozen = false
local SelectMode = false
local MouseLock = false
local RMB = false
local Closed = false

local Distance = 12
local Yaw, Pitch = 0, -0.3
local View = "third"

local SavedFreeze
local SavedCamera
local SavedMouse
local Connections = {}

--==================================================
-- GUI
--==================================================

local Old = game:GetService("CoreGui"):FindFirstChild("NPC_V53")
if Old then Old:Destroy() end

local GUI = Instance.new("ScreenGui")
GUI.Name = "NPC_V53"
GUI.ResetOnSpawn = false
GUI.Parent = game:GetService("CoreGui")

local Frame = Instance.new("Frame")
Frame.Size = UDim2.fromOffset(240, 340)
Frame.Position = UDim2.new(0.5,-120,0.5,-170)
Frame.BackgroundColor3 = Color3.fromRGB(25,28,40)
Frame.Parent = GUI

Instance.new("UICorner",Frame).CornerRadius = UDim.new(0,10)

local Title = Instance.new("TextButton")
Title.Size = UDim2.new(1,0,0,38)
Title.Text = "MASTER NPC CONTROLLER V5.3"
Title.TextColor3 = Color3.new(1,1,1)
Title.BackgroundColor3 = Color3.fromRGB(65,85,170)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 12
Title.Parent = Frame

local function Button(name,text,y)
    local b = Instance.new("TextButton")
    b.Name = name
    b.Size = UDim2.new(1,-20,0,34)
    b.Position = UDim2.fromOffset(10,y)
    b.BackgroundColor3 = Color3.fromRGB(48,57,79)
    b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Text = text
    b.Parent = Frame
    Instance.new("UICorner",b).CornerRadius = UDim.new(0,8)
    return b
end

local SelectBtn = Button("Select","SELECT NEAREST NPC",48)
local ControlBtn = Button("Control","START CONTROL [N]",88)
local FreezeBtn = Button("Freeze","FREEZE AI [F]: OFF",128)
local ReturnBtn = Button("Return","RETURN TO PLAYER",168)
local ViewBtn = Button("View","CAMERA: THIRD [1/3]",208)
local HideBtn = Button("Hide","HIDE MENU [INSERT]",248)
local CloseBtn = Button("Close","EXIT [DELETE]",288)

local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1,-20,0,25)
Status.Position = UDim2.fromOffset(10,313)
Status.BackgroundTransparency = 1
Status.Text = "Status: Ready"
Status.TextColor3 = Color3.fromRGB(180,220,255)
Status.TextSize = 11
Status.Parent = Frame

local function SetStatus(s)
    Status.Text = "Status: "..s
end

--==================================================
-- DRAG
--==================================================

local Dragging = false
local DragStart, StartPos

Title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        Dragging = true
        DragStart = input.Position
        StartPos = Frame.Position
    end
end)

UIS.InputChanged:Connect(function(input)
    if Dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local d = input.Position - DragStart
        Frame.Position = UDim2.new(
            StartPos.X.Scale,StartPos.X.Offset+d.X,
            StartPos.Y.Scale,StartPos.Y.Offset+d.Y
        )
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        Dragging = false
    end
end)

--==================================================
-- CAMERA RESTORE
--==================================================

local function RestoreCamera()
    Camera = workspace.CurrentCamera
    if Camera then
        Camera.CameraType = Enum.CameraType.Custom
        local Character = LP.Character
        local H = Character and Character:FindFirstChildOfClass("Humanoid")
        if H then Camera.CameraSubject = H end
    end

    UIS.MouseBehavior = Enum.MouseBehavior.Default
    UIS.MouseIconEnabled = true
end

--==================================================
-- SELECT NPC
--==================================================

local function ValidNPC(Model)
    if not Model or not Model:IsA("Model") then return false end
    if Players:GetPlayerFromCharacter(Model) then return false end

    local H = Model:FindFirstChildOfClass("Humanoid")
    local R = Model:FindFirstChild("HumanoidRootPart")

    return H and R and H.Health > 0
end

local function SelectNPC(Model)
    if Frozen then
        SetStatus("Unfreeze before selecting another NPC")
        return false
    end

    if not ValidNPC(Model) then return false end

    NPC = Model
    Hum = Model:FindFirstChildOfClass("Humanoid")
    Root = Model:FindFirstChild("HumanoidRootPart")

    SelectBtn.Text = "SELECTED: "..Model.Name
    SetStatus("Selected "..Model.Name)
    return true
end

local function FindNPC()
    local Character = LP.Character
    local MyRoot = Character and Character:FindFirstChild("HumanoidRootPart")
    if not MyRoot then return end

    local Best, BestDist = nil, SEARCH_DISTANCE

    for _,Model in ipairs(workspace:GetDescendants()) do
        if Model:IsA("Model") and ValidNPC(Model) then
            local R = Model:FindFirstChild("HumanoidRootPart")
            local D = (R.Position-MyRoot.Position).Magnitude

            if D < BestDist then
                Best = Model
                BestDist = D
            end
        end
    end

    if Best then SelectNPC(Best) end
end

--==================================================
-- CONTROL
--==================================================

local function StopControl()
    Active = false
    RMB = false
    MouseLock = false
    RestoreCamera()
    ControlBtn.Text = "START CONTROL [N]"
end

local function StartControl()
    if Frozen then
        SetStatus("Unfreeze NPC first")
        return
    end

    if not ValidNPC(NPC) then
        FindNPC()
    end

    if not ValidNPC(NPC) then
        SetStatus("No valid NPC")
        return
    end

    Camera = workspace.CurrentCamera
    if not Camera then return end

    local _,Y = Camera.CFrame:ToEulerAnglesYXZ()
    Yaw = Y
    Pitch = -0.3

    Active = true
    Camera.CameraType = Enum.CameraType.Scriptable
    ControlBtn.Text = "CONTROL ACTIVE"
    SetStatus("Controlling "..NPC.Name)
end

local function ToggleControl()
    if Active then StopControl() else StartControl() end
end

--==================================================
-- FREEZE
--==================================================

local function FreezeNPC()
    if not ValidNPC(NPC) then
        SetStatus("Select NPC first")
        return
    end

    if Active then StopControl() end

    SavedFreeze = {
        Anchored = Root.Anchored,
        WalkSpeed = Hum.WalkSpeed,
        JumpPower = Hum.JumpPower,
        JumpHeight = Hum.JumpHeight,
        AutoRotate = Hum.AutoRotate,
        UseJumpPower = Hum.UseJumpPower
    }

    Frozen = true

    Hum:Move(Vector3.zero,false)
    Hum.WalkSpeed = 0
    Hum.JumpPower = 0
    Hum.JumpHeight = 0
    Hum.AutoRotate = false
    Root.AssemblyLinearVelocity = Vector3.zero
    Root.AssemblyAngularVelocity = Vector3.zero
    Root.Anchored = true

    FreezeBtn.Text = "FREEZE AI [F]: ON"
    SetStatus("NPC frozen locally")
end

local function UnfreezeNPC()
    if not Frozen then return end

    if ValidNPC(NPC) and SavedFreeze then
        Root.Anchored = SavedFreeze.Anchored
        Hum.WalkSpeed = SavedFreeze.WalkSpeed
        Hum.JumpPower = SavedFreeze.JumpPower
        Hum.JumpHeight = SavedFreeze.JumpHeight
        Hum.AutoRotate = SavedFreeze.AutoRotate
        Hum.UseJumpPower = SavedFreeze.UseJumpPower
    end

    Frozen = false
    SavedFreeze = nil
    FreezeBtn.Text = "FREEZE AI [F]: OFF"
    SetStatus("NPC unfrozen")
end

local function ToggleFreeze()
    if Frozen then UnfreezeNPC() else FreezeNPC() end
end

--==================================================
-- MOVEMENT + CAMERA
--==================================================

RS:BindToRenderStep(
    "NPC_V53_CAMERA",
    Enum.RenderPriority.Camera.Value+1,
    function()
        if Closed or not Active then return end

        if not ValidNPC(NPC) then
            StopControl()
            return
        end

        Camera = workspace.CurrentCamera
        if not Camera then return end

        if MouseLock or RMB then
            local Delta = UIS:GetMouseDelta()
            Yaw = Yaw-Delta.X*0.006
            Pitch = math.clamp(Pitch-Delta.Y*0.006,-1.4,1.4)
        end

        local Rotation = CFrame.fromEulerAnglesYXZ(Pitch,Yaw,0)
        local Target = Root.Position+Vector3.new(0,1.65,0)

        if View == "first" then
            Camera.CFrame = CFrame.new(Target)*Rotation
        else
            Camera.CFrame = CFrame.new(
                Target-Rotation.LookVector*Distance,
                Target
            )
        end

        local Forward = Vector3.new(Rotation.LookVector.X,0,Rotation.LookVector.Z)
        local Right = Vector3.new(Rotation.RightVector.X,0,Rotation.RightVector.Z)

        if Forward.Magnitude > 0 then Forward = Forward.Unit end
        if Right.Magnitude > 0 then Right = Right.Unit end

        local Direction = Vector3.zero

        if UIS:IsKeyDown(Enum.KeyCode.W) then Direction += Forward end
        if UIS:IsKeyDown(Enum.KeyCode.S) then Direction -= Forward end
        if UIS:IsKeyDown(Enum.KeyCode.D) then Direction += Right end
        if UIS:IsKeyDown(Enum.KeyCode.A) then Direction -= Right end

        if Direction.Magnitude > 0 then Direction = Direction.Unit end

        Hum.WalkSpeed =
            (UIS:IsKeyDown(Enum.KeyCode.LeftShift)
            or UIS:IsKeyDown(Enum.KeyCode.RightShift))
            and SPRINT_SPEED or WALK_SPEED

        Hum:Move(Direction,false)
    end
)

--==================================================
-- BUTTONS
--==================================================

SelectBtn.MouseButton1Click:Connect(FindNPC)
ControlBtn.MouseButton1Click:Connect(ToggleControl)
FreezeBtn.MouseButton1Click:Connect(ToggleFreeze)
ReturnBtn.MouseButton1Click:Connect(StopControl)

ViewBtn.MouseButton1Click:Connect(function()
    View = View == "first" and "third" or "first"
    ViewBtn.Text = "CAMERA: "..string.upper(View).." [1/3]"
end)

HideBtn.MouseButton1Click:Connect(function()
    Frame.Visible = false
end)

CloseBtn.MouseButton1Click:Connect(function()
    Closed = true
    StopControl()
    UnfreezeNPC()
    RS:UnbindFromRenderStep("NPC_V53_CAMERA")
    GUI:Destroy()
end)

--==================================================
-- INPUT
--==================================================

local function SelectUnderMouse()
    local Mouse = LP:GetMouse()
    local Part = Mouse.Target

    if not Part then return end

    local Model = Part:FindFirstAncestorOfClass("Model")
    while Model and not Model:FindFirstChildOfClass("Humanoid") do
        Model = Model.Parent and Model.Parent:FindFirstAncestorOfClass("Model")
    end

    if SelectNPC(Model) then
        SelectMode = false
        SetStatus("NPC selected")
    end
end

UIS.InputBegan:Connect(function(Input,Processed)
    if Input.KeyCode == Enum.KeyCode.End then
        SelectMode = not SelectMode
        UIS.MouseBehavior = Enum.MouseBehavior.Default
        UIS.MouseIconEnabled = true
        SetStatus(SelectMode and "Click NPC to select" or "Selection cancelled")
        return
    end

    if SelectMode and Input.UserInputType == Enum.UserInputType.MouseButton1 then
        SelectUnderMouse()
        return
    end

    if Input.UserInputType == Enum.UserInputType.MouseButton2 then
        if Active then
            RMB = true
            UIS.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
        end
        return
    end

    if Processed or UIS:GetFocusedTextBox() then return end

    if Input.KeyCode == Enum.KeyCode.N then
        ToggleControl()

    elseif Input.KeyCode == Enum.KeyCode.F then
        ToggleFreeze()

    elseif Input.KeyCode == Enum.KeyCode.L then
        if Active then
            MouseLock = not MouseLock
            UIS.MouseBehavior = MouseLock and Enum.MouseBehavior.LockCenter
                or Enum.MouseBehavior.Default
        end

    elseif Input.KeyCode == Enum.KeyCode.P then
        Distance = math.clamp(Distance-2,4,35)

    elseif Input.KeyCode == Enum.KeyCode.O then
        Distance = math.clamp(Distance+2,4,35)

    elseif Input.KeyCode == Enum.KeyCode.One then
        View = "first"

    elseif Input.KeyCode == Enum.KeyCode.Three then
        View = "third"

    elseif Input.KeyCode == Enum.KeyCode.Insert then
        Frame.Visible = not Frame.Visible

    elseif Input.KeyCode == Enum.KeyCode.Space then
        if Active and not Frozen then Hum.Jump = true end

    elseif Input.KeyCode == Enum.KeyCode.Delete then
        Closed = true
        StopControl()
        UnfreezeNPC()
        RS:UnbindFromRenderStep("NPC_V53_CAMERA")
        GUI:Destroy()
    end
end)

UIS.InputEnded:Connect(function(Input)
    if Input.UserInputType == Enum.UserInputType.MouseButton2 then
        RMB = false
        if Active then
            UIS.MouseBehavior = MouseLock
                and Enum.MouseBehavior.LockCenter
                or Enum.MouseBehavior.Default
        end
    end
end)

UIS.InputChanged:Connect(function(Input)
    if Active and Input.UserInputType == Enum.UserInputType.MouseWheel
        and View == "third" then
        Distance = math.clamp(Distance-Input.Position.Z*2,4,35)
    end
end)

--==================================================
-- RESPAWN CLEANUP
--==================================================

LP.CharacterAdded:Connect(function()
    StopControl()
end)

print("MASTER NPC CONTROLLER V5.3 FIXED LOADED")
print("WASD: Move | SHIFT: Sprint")
print("N: Control | F: Freeze")
print("END: Select NPC | L: Mouse Lock")
print("1: First Person | 3: Third Person")
print("P/O: Zoom | INSERT: Menu")
print("DELETE: Exit")
