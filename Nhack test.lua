-- GBP nhack UI template

if getgenv().GBP_NHACK_TEMPLATE then
    pcall(function()
        getgenv().GBP_NHACK_TEMPLATE.unload()
    end)
end

-- This is the raw UI.lua file in the Gist. The unpinned URL receives future updates.
local LibraryUrl = "https://gist.githubusercontent.com/sypeels/f48ef33fbe436771c3ad402599d2d063/raw/UI.lua"
local LibrarySource = game:HttpGet(LibraryUrl)

local LoadLibrary = loadstring(LibrarySource)
assert(LoadLibrary, "Unable to compile the nhack UI library")
local Library = LoadLibrary()
if Library.ESPPreviewVersion ~= 2 then
    error("The loaded library is outdated. Upload the edited UI.lua or place it beside this script.")
end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")

local EspEnabled = true
local EspBoxes = {}
local EspConnections = {}

local function RemoveEspBox(Player)
    local Lines = EspBoxes[Player]
    if Lines then
        for _, Line in ipairs(Lines) do
            Line:Remove()
        end
        EspBoxes[Player] = nil
    end
end

local function CreateLine()
    local Line = Drawing.new("Line")
    Line.Color = Color3.fromRGB(255, 80, 80)
    Line.Thickness = 1
    Line.Transparency = 1
    Line.Visible = false
    return Line
end

local function AddEspBox(Player, Character)
    RemoveEspBox(Player)

    if Player == LocalPlayer or not Character then
        return
    end

    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
    if not Character:FindFirstChild("HumanoidRootPart") or not Humanoid then
        return
    end

    EspBoxes[Player] = {
        CreateLine(), CreateLine(), CreateLine(), CreateLine(),
        CreateLine(), CreateLine(), CreateLine(), CreateLine()
    }
end

local function WatchPlayer(Player)
    if Player == LocalPlayer then
        return
    end

    EspConnections[Player] = Player.CharacterAdded:Connect(function(Character)
        task.wait()
        AddEspBox(Player, Character)
    end)

    if Player.Character then
        AddEspBox(Player, Player.Character)
    end
end

for _, Player in ipairs(Players:GetPlayers()) do
    WatchPlayer(Player)
end

local PlayerAddedConnection = Players.PlayerAdded:Connect(WatchPlayer)
local PlayerRemovingConnection = Players.PlayerRemoving:Connect(function(Player)
    RemoveEspBox(Player)
    if EspConnections[Player] then
        EspConnections[Player]:Disconnect()
        EspConnections[Player] = nil
    end
end)

local EspRenderConnection = RunService.RenderStepped:Connect(function()
    Camera = workspace.CurrentCamera
    if not Camera then
        return
    end

    for Player, Lines in pairs(EspBoxes) do
        local Character = Player.Character
        local Root = Character and Character:FindFirstChild("HumanoidRootPart")
        local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
        local Visible = EspEnabled and Root and Humanoid and Humanoid.Health > 0
        local MinX, MinY = math.huge, math.huge
        local MaxX, MaxY = -math.huge, -math.huge

        if Visible then
            for _, Part in ipairs(Character:GetChildren()) do
                if Part:IsA("BasePart") then
                    local HalfSize = Part.Size / 2
                    for X = -1, 1, 2 do
                        for Y = -1, 1, 2 do
                            for Z = -1, 1, 2 do
                                local Point, OnScreen = Camera:WorldToViewportPoint(
                                    Part.CFrame:PointToWorldSpace(Vector3.new(
                                        HalfSize.X * X,
                                        HalfSize.Y * Y,
                                        HalfSize.Z * Z
                                    ))
                                )

                                if OnScreen and Point.Z > 0 then
                                    MinX = math.min(MinX, Point.X)
                                    MinY = math.min(MinY, Point.Y)
                                    MaxX = math.max(MaxX, Point.X)
                                    MaxY = math.max(MaxY, Point.Y)
                                end
                            end
                        end
                    end
                end
            end

            Visible = MinX ~= math.huge and MaxX ~= -math.huge
        end

        if Visible then
            local Width, Height = MaxX - MinX, MaxY - MinY
            local CornerWidth, CornerHeight = Width * 0.25, Height * 0.2
            local Points = {
                Vector2.new(MinX, MinY), Vector2.new(MinX + CornerWidth, MinY),
                Vector2.new(MinX, MinY + CornerHeight), Vector2.new(MinX, MinY + Height - CornerHeight),
                Vector2.new(MinX, MaxY), Vector2.new(MinX + CornerWidth, MaxY),
                Vector2.new(MaxX - CornerWidth, MinY), Vector2.new(MaxX, MinY),
                Vector2.new(MaxX, MinY + CornerHeight), Vector2.new(MaxX, MinY + Height - CornerHeight),
                Vector2.new(MaxX, MaxY), Vector2.new(MaxX - CornerWidth, MaxY)
            }

            local Segments = {
                { 1, 2 }, { 1, 3 }, { 4, 5 }, { 5, 6 },
                { 7, 8 }, { 8, 9 }, { 10, 11 }, { 11, 12 }
            }

            for Index, Segment in ipairs(Segments) do
                Lines[Index].From = Points[Segment[1]]
                Lines[Index].To = Points[Segment[2]]
                Lines[Index].Visible = true
            end
        else
            for _, Line in ipairs(Lines) do
                Line.Visible = false
            end
        end
    end
end)

local Window = Library:Window({
    Title = "GBP Template",
    Width = 580,
    Height = 440,
})

local ESPPreview = Library:ESPPreview({
    Name = "ESP Preview",
})

Library:RegisterSettingsWidget({
    Name = "ESP Preview",
    Default = true,
    Callback = function(value)
        ESPPreview:SetVisibility(value)
    end,
})

local MainPage = Window:Page({ Name = "Main" })
local MainSubPage = MainPage:SubPage({ Name = "ESP" })
local EspSection = MainSubPage:Section({
    Name = "ESP",
    Side = 1
})

EspSection:Toggle({
    Name = "2D Corner ESP",
    Flag = "2DCornerESP",
    Default = true,
    Callback = function(Value)
        EspEnabled = Value
    end,
})

Window:CreateSettingsPage()
Window:SetOpen(true)

local unloaded = false
local originalExit = Library.Exit

local function teardown()
    if unloaded then
        return
    end

    unloaded = true
    PlayerAddedConnection:Disconnect()
    PlayerRemovingConnection:Disconnect()
    EspRenderConnection:Disconnect()

    for Player, Connection in pairs(EspConnections) do
        Connection:Disconnect()
        RemoveEspBox(Player)
    end

    getgenv().GBP_NHACK_TEMPLATE = nil
end

Library.Exit = function(...)
    teardown()
    return originalExit(...)
end

local function unload()
    teardown()
    pcall(function()
        Library:Exit()
    end)
end

getgenv().GBP_NHACK_TEMPLATE = {
    unload = unload,
    Window = Window,
    Library = Library,
}

Library:Notification(
    "GBP nhack template loaded — press Right Shift to toggle",
    5,
    Library.Theme["Accent"]
)
