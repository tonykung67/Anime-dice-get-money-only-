-- LocalScript สำหรับเกมของคุณเอง / Studio testing

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local P1 = Vector3.new(-22, 6.3, -32)
local P4 = Vector3.new(-22, 6.3, -86)
local P5 = Vector3.new(22, 6.3, -32)

local waitTime = 5
local autoMove = false
local showCoordinate = true
local loopMode = true
local currentIndex = 1
local minimized = false
local running = true

local function getRoot()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getSpawn()
	local plots = workspace:FindFirstChild("Plots")
	local claimed = plots and plots:FindFirstChild("Claimed")

	if not claimed then
		return nil
	end

	local root = getRoot()
	if not root then
		return nil
	end

	local nearestSpawn
	local nearestDistance = math.huge

	for _, plot in ipairs(claimed:GetChildren()) do
		local spawn = plot:FindFirstChild("Spawn")

		if spawn then
			local distance = (spawn:GetPivot().Position - root.Position).Magnitude

			if distance < nearestDistance then
				nearestDistance = distance
				nearestSpawn = spawn
			end
		end
	end

	return nearestSpawn
end

-- สร้างจุดทั้งหมด 8 จุด
local offsets = {}

for row = 0, 1 do
	for _, x in ipairs({0, 18, 36, 52}) do
		table.insert(
			offsets,
			P1 + (P4 - P1) * (x / 52) + (P5 - P1) * row
		)
	end
end

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "AutoFarmGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(280, 330)
main.Position = UDim2.new(0, 20, 0.5, -165)
main.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
main.BorderSizePixel = 0
main.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -45, 0, 40)
title.Position = UDim2.fromOffset(12, 0)
title.BackgroundTransparency = 1
title.Text = "Auto Farm Controller"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextSize = 18
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = main

local minimizeButton = Instance.new("TextButton")
minimizeButton.Size = UDim2.fromOffset(32, 28)
minimizeButton.Position = UDim2.new(1, -38, 0, 6)
minimizeButton.Text = "—"
minimizeButton.TextSize = 20
minimizeButton.TextColor3 = Color3.new(1, 1, 1)
minimizeButton.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
minimizeButton.Parent = main

local content = Instance.new("Frame")
content.Name = "Content"
content.Size = UDim2.new(1, -20, 1, -50)
content.Position = UDim2.fromOffset(10, 45)
content.BackgroundTransparency = 1
content.Parent = main

local function createButton(text, y)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 0, 36)
	button.Position = UDim2.fromOffset(0, y)
	button.Text = text
	button.TextSize = 14
	button.Font = Enum.Font.Gotham
	button.TextColor3 = Color3.new(1, 1, 1)
	button.BackgroundColor3 = Color3.fromRGB(65, 65, 75)
	button.AutoButtonColor = true
	button.Parent = content

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 6)
	buttonCorner.Parent = button

	return button
end

local function createLabel(text, y)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 25)
	label.Position = UDim2.fromOffset(0, y)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextSize = 14
	label.Font = Enum.Font.Gotham
	label.TextColor3 = Color3.fromRGB(220, 220, 220)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = content

	return label
end

local function createTextBox(text, y)
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, 0, 0, 32)
	box.Position = UDim2.fromOffset(0, y)
	box.Text = text
	box.PlaceholderText = "วินาที"
	box.TextSize = 14
	box.Font = Enum.Font.Gotham
	box.TextColor3 = Color3.new(1, 1, 1)
	box.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	box.ClearTextOnFocus = false
	box.Parent = content

	local boxCorner = Instance.new("UICorner")
	boxCorner.CornerRadius = UDim.new(0, 6)
	boxCorner.Parent = box

	return box
end

local statusLabel = createLabel("สถานะ: ปิด", 0)

local autoButton = createButton("เปิด Auto Move", 32)
local coordinateButton = createButton("ปิดพิกัด", 74)
local modeButton = createButton("โหมด: วนทุกจุด", 116)
local nextButton = createButton("ไปจุดถัดไป", 158)
local resetButton = createButton("รีเซ็ตจุดเริ่มต้น", 200)

local waitLabel = createLabel("ระยะเวลาระหว่างจุด (วินาที)", 242)
local waitBox = createTextBox("5", 267)

-- ป้ายพิกัด
local coordinateLabel = Instance.new("TextLabel")
coordinateLabel.Size = UDim2.fromOffset(240, 28)
coordinateLabel.Position = UDim2.new(0, 20, 0.5, 175)
coordinateLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
coordinateLabel.BackgroundTransparency = 0.25
coordinateLabel.TextColor3 = Color3.new(1, 1, 1)
coordinateLabel.TextSize = 14
coordinateLabel.Font = Enum.Font.Code
coordinateLabel.Text = "พิกัด: -"
coordinateLabel.Parent = gui

local function updateStatus()
	if autoMove then
		statusLabel.Text = "สถานะ: เปิด"
		statusLabel.TextColor3 = Color3.fromRGB(100, 255, 130)
		autoButton.Text = "ปิด Auto Move"
		autoButton.BackgroundColor3 = Color3.fromRGB(45, 130, 70)
	else
		statusLabel.Text = "สถานะ: ปิด"
		statusLabel.TextColor3 = Color3.fromRGB(255, 130, 130)
		autoButton.Text = "เปิด Auto Move"
		autoButton.BackgroundColor3 = Color3.fromRGB(65, 65, 75)
	end

	if showCoordinate then
		coordinateButton.Text = "ปิดพิกัด"
		coordinateLabel.Visible = true
	else
		coordinateButton.Text = "เปิดพิกัด"
		coordinateLabel.Visible = false
	end

	if loopMode then
		modeButton.Text = "โหมด: วนทุกจุด"
	else
		modeButton.Text = "โหมด: หยุดเมื่อครบ"
	end
end

local function teleportToIndex(index)
	local spawn = getSpawn()
	local root = getRoot()

	if not spawn or not root then
		statusLabel.Text = "สถานะ: ไม่พบ Spawn หรือ Character"
		statusLabel.TextColor3 = Color3.fromRGB(255, 180, 80)
		return false
	end

	local worldPosition = spawn:GetPivot():PointToWorldSpace(offsets[index])

	-- สำหรับเกมของคุณเอง/การทดสอบใน Studio
	root.CFrame = CFrame.new(worldPosition)

	return true
end

-- Auto Move
autoButton.MouseButton1Click:Connect(function()
	autoMove = not autoMove
	updateStatus()
end)

-- Coordinate toggle
coordinateButton.MouseButton1Click:Connect(function()
	showCoordinate = not showCoordinate
	updateStatus()
end)

-- เปลี่ยนโหมด
modeButton.MouseButton1Click:Connect(function()
	loopMode = not loopMode
	updateStatus()
end)

-- ไปจุดถัดไปทันที
nextButton.MouseButton1Click:Connect(function()
	if teleportToIndex(currentIndex) then
		currentIndex += 1

		if currentIndex > #offsets then
			if loopMode then
				currentIndex = 1
			else
				currentIndex = #offsets
				autoMove = false
				updateStatus()
			end
		end
	end
end)

-- รีเซ็ตจุด
resetButton.MouseButton1Click:Connect(function()
	currentIndex = 1
	statusLabel.Text = "สถานะ: รีเซ็ตจุดแล้ว"
	statusLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
end)

-- เปลี่ยนเวลา
waitBox.FocusLost:Connect(function()
	local value = tonumber(waitBox.Text)

	if value and value >= 0.2 then
		waitTime = value
		waitBox.Text = tostring(waitTime)
	else
		waitTime = 5
		waitBox.Text = "5"
	end
end)

-- อัปเดตพิกัด
RunService.RenderStepped:Connect(function()
	if not running or not showCoordinate then
		return
	end

	local root = getRoot()
	local spawn = getSpawn()

	if root and spawn then
		local localPosition = spawn:GetPivot():PointToObjectSpace(root.Position)

		coordinateLabel.Text = string.format(
			"พิกัด: %.1f, %.1f, %.1f",
			localPosition.X,
			localPosition.Y,
			localPosition.Z
		)
	end
end)

-- Loop การทำงาน
task.spawn(function()
	while running do
		if autoMove then
			if teleportToIndex(currentIndex) then
				currentIndex += 1

				if currentIndex > #offsets then
					if loopMode then
						currentIndex = 1
					else
						currentIndex = #offsets
						autoMove = false
						updateStatus()
					end
				end
			end
		end

		task.wait(waitTime)
	end
end)

-- ปุ่มย่อ/ขยาย
minimizeButton.MouseButton1Click:Connect(function()
	minimized = not minimized
	content.Visible = not minimized

	if minimized then
		main.Size = UDim2.fromOffset(280, 48)
		minimizeButton.Text = "+"
	else
		main.Size = UDim2.fromOffset(280, 330)
		minimizeButton.Text = "—"
	end
end)

-- ลาก GUI ได้
local dragging = false
local dragStart
local startPosition

title.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then

		dragging = true
		dragStart = input.Position
		startPosition = main.Position

		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not dragging then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch then

		local delta = input.Position - dragStart

		main.Position = UDim2.new(
			startPosition.X.Scale,
			startPosition.X.Offset + delta.X,
			startPosition.Y.Scale,
			startPosition.Y.Offset + delta.Y
		)
	end
end)

updateStatus()
