--// FluentX (One-File Redesign)
--// Drop-in style: FluentX:CreateWindow({Title="", SubTitle="", Size=UDim2.fromOffset(700,460), Theme={...}})
--// Window:AddTab({Title="", Icon=nil}) -> Tab:AddSection("Title") -> Section:AddButton/Toggle/Slider/Input/Dropdown/Paragraph
--// Modern layout + animations + cards. Single file.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer

local FluentX = {}
FluentX.__index = FluentX

--========================
-- Helpers
--========================
local function Create(className, props, children)
	local inst = Instance.new(className)
	props = props or {}
	for k, v in pairs(props) do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	if children then
		for _, c in ipairs(children) do
			c.Parent = inst
		end
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function Tween(obj, ti, goal)
	local t = TweenService:Create(obj, ti, goal)
	t:Play()
	return t
end

local function Round(n, decimals)
	decimals = decimals or 0
	local p = 10 ^ decimals
	return math.floor(n * p + 0.5) / p
end

local function Clamp(v, a, b)
	return math.max(a, math.min(b, v))
end

local function AddShadow(parent, radius, transparency)
	-- Fake shadow using image slice
	local shadow = Create("ImageLabel", {
		Name = "Shadow",
		BackgroundTransparency = 1,
		Image = "rbxassetid://1316045217", -- soft shadow (common)
		ImageTransparency = transparency or 0.65,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(10, 10, 118, 118),
		Size = UDim2.new(1, 24, 1, 24),
		Position = UDim2.fromOffset(-12, -12),
		ZIndex = (parent.ZIndex or 1) - 1,
		Parent = parent,
	})
	return shadow
end

local function MakeCorner(parent, px)
	return Create("UICorner", { CornerRadius = UDim.new(0, px), Parent = parent })
end

local function MakeStroke(parent, thickness, transparency)
	return Create("UIStroke", {
		Thickness = thickness or 1,
		Transparency = transparency or 0.6,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function MakePadding(parent, l, t, r, b)
	return Create("UIPadding", {
		PaddingLeft = UDim.new(0, l or 0),
		PaddingTop = UDim.new(0, t or 0),
		PaddingRight = UDim.new(0, r or 0),
		PaddingBottom = UDim.new(0, b or 0),
		Parent = parent,
	})
end

local function MakeList(parent, padding, dir)
	return Create("UIListLayout", {
		Padding = UDim.new(0, padding or 8),
		FillDirection = dir or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

local function AutoSizeY(frame, padding)
	padding = padding or 0
	local list = frame:FindFirstChildOfClass("UIListLayout")
	if not list then return end
	local function upd()
		frame.Size = UDim2.new(frame.Size.X.Scale, frame.Size.X.Offset, 0, list.AbsoluteContentSize.Y + padding)
	end
	upd()
	list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(upd)
end

--========================
-- Theme (not "just a theme": used as design tokens)
--========================
local DefaultTheme = {
	Font = Font.new("rbxasset://fonts/families/GothamSSm.json"),
	FontBold = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),

	Bg = Color3.fromRGB(14, 16, 20),
	Panel = Color3.fromRGB(18, 21, 27),
	Card = Color3.fromRGB(22, 26, 34),
	Card2 = Color3.fromRGB(26, 31, 40),

	Stroke = Color3.fromRGB(40, 45, 58),
	StrokeSoft = Color3.fromRGB(30, 34, 44),

	Text = Color3.fromRGB(240, 242, 246),
	SubText = Color3.fromRGB(160, 168, 182),

	Accent = Color3.fromRGB(96, 205, 255),
	Accent2 = Color3.fromRGB(140, 100, 255),

	ShadowTransparency = 0.68,
	Corner = 12,
	CornerSmall = 10,
	CardPadding = 12,
}

--========================
-- Acrylic/Blur (optional)
--========================
local BlurController = {}
BlurController.__index = BlurController

function BlurController.new()
	local self = setmetatable({}, BlurController)
	self.DOF = Create("DepthOfFieldEffect", {
		Enabled = false,
		FarIntensity = 0,
		InFocusRadius = 0.12,
		NearIntensity = 1,
	})
	self.Original = {}
	return self
end

function BlurController:Enable()
	if self.DOF.Parent == Lighting then return end
	for _, eff in ipairs(Lighting:GetChildren()) do
		if eff:IsA("DepthOfFieldEffect") then
			self.Original[eff] = eff.Enabled
			eff.Enabled = false
		end
	end
	self.DOF.Enabled = true
	self.DOF.Parent = Lighting
end

function BlurController:Disable()
	for eff, st in pairs(self.Original) do
		if eff and eff.Parent then
			eff.Enabled = st
		end
	end
	self.Original = {}
	self.DOF.Parent = nil
end

--========================
-- FluentX core
--========================
function FluentX:CreateWindow(opts)
	opts = opts or {}
	local theme = opts.Theme or DefaultTheme
	local size = opts.Size or UDim2.fromOffset(720, 460)

	local guiParent = (syn and syn.protect_gui and game:GetService("CoreGui")) or game:GetService("CoreGui")
	local sg = Create("ScreenGui", {
		Name = "FluentX",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = guiParent,
	})
	if syn and syn.protect_gui then
		pcall(function() syn.protect_gui(sg) end)
	end

	local blur = BlurController.new()

	local root = Create("Frame", {
		Name = "Root",
		BackgroundColor3 = theme.Bg,
		Size = size,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Parent = sg,
	})
	MakeCorner(root, theme.Corner)
	MakeStroke(root, 1, 0.55).Color = theme.StrokeSoft
	AddShadow(root, theme.Corner, theme.ShadowTransparency)

	local bgGrad = Create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, theme.Bg),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 12, 16))
		}),
		Parent = root
	})

	-- Topbar
	local top = Create("Frame", {
		Name = "Topbar",
		BackgroundColor3 = theme.Panel,
		Size = UDim2.new(1, 0, 0, 56),
		Parent = root
	})
	MakeCorner(top, theme.Corner)
	MakeStroke(top, 1, 0.65).Color = theme.StrokeSoft

	local title = Create("TextLabel", {
		BackgroundTransparency = 1,
		Text = opts.Title or "Window",
		FontFace = theme.FontBold,
		TextSize = 16,
		TextColor3 = theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -180, 0, 18),
		Position = UDim2.fromOffset(18, 12),
		Parent = top,
	})

	local subtitle = Create("TextLabel", {
		BackgroundTransparency = 1,
		Text = opts.SubTitle or "",
		FontFace = theme.Font,
		TextSize = 12,
		TextColor3 = theme.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -180, 0, 16),
		Position = UDim2.fromOffset(18, 30),
		Parent = top,
	})

	-- Controls
	local controls = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 160, 1, 0),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 0),
		Parent = top,
	})
	local cList = MakeList(controls, 8, Enum.FillDirection.Horizontal)
	cList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	cList.VerticalAlignment = Enum.VerticalAlignment.Center

	local function IconButton(text)
		local b = Create("TextButton", {
			BackgroundColor3 = theme.Card,
			Size = UDim2.fromOffset(40, 34),
			Text = text,
			FontFace = theme.FontBold,
			TextSize = 14,
			TextColor3 = theme.Text,
			AutoButtonColor = false,
			Parent = controls,
		})
		MakeCorner(b, 10)
		local st = MakeStroke(b, 1, 0.65); st.Color = theme.StrokeSoft

		b.MouseEnter:Connect(function()
			Tween(b, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = theme.Card2})
		end)
		b.MouseLeave:Connect(function()
			Tween(b, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = theme.Card})
		end)
		return b
	end

	local btnBlur = IconButton("B")
	local btnMin = IconButton("—")
	local btnClose = IconButton("×")

	-- Body layout
	local body = Create("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -56),
		Position = UDim2.fromOffset(0, 56),
		Parent = root,
	})

	-- Sidebar
	local sidebar = Create("Frame", {
		Name = "Sidebar",
		BackgroundColor3 = theme.Panel,
		Size = UDim2.new(0, 210, 1, -18),
		Position = UDim2.fromOffset(12, 10),
		Parent = body,
	})
	MakeCorner(sidebar, theme.Corner)
	MakeStroke(sidebar, 1, 0.7).Color = theme.StrokeSoft

	local sbHeader = Create("TextLabel", {
		BackgroundTransparency = 1,
		Text = "Меню",
		FontFace = theme.FontBold,
		TextSize = 12,
		TextColor3 = theme.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -24, 0, 16),
		Position = UDim2.fromOffset(12, 10),
		Parent = sidebar,
	})

	local tabList = Create("Frame", {
		Name = "TabList",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -16, 1, -44),
		Position = UDim2.fromOffset(8, 32),
		Parent = sidebar,
	})
	local tabLayout = MakeList(tabList, 8)
	tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	-- Content panel
	local content = Create("Frame", {
		Name = "Content",
		BackgroundColor3 = theme.Panel,
		Size = UDim2.new(1, -246, 1, -18),
		Position = UDim2.fromOffset(234, 10),
		Parent = body,
	})
	MakeCorner(content, theme.Corner)
	MakeStroke(content, 1, 0.7).Color = theme.StrokeSoft

	local contentHeader = Create("TextLabel", {
		BackgroundTransparency = 1,
		Text = "Tab",
		FontFace = theme.FontBold,
		TextSize = 18,
		TextColor3 = theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -24, 0, 22),
		Position = UDim2.fromOffset(14, 12),
		Parent = content,
	})

	local contentSub = Create("TextLabel", {
		BackgroundTransparency = 1,
		Text = "",
		FontFace = theme.Font,
		TextSize = 12,
		TextColor3 = theme.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -24, 0, 16),
		Position = UDim2.fromOffset(14, 34),
		Parent = content,
	})

	local contentHolder = Create("Frame", {
		Name = "Holder",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -20, 1, -64),
		Position = UDim2.fromOffset(10, 54),
		Parent = content,
	})

	local pages = Create("Folder", { Name = "Pages", Parent = contentHolder })

	-- Drag window
	do
		local dragging = false
		local dragStart, startPos

		top.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = true
				dragStart = input.Position
				startPos = root.Position
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						dragging = false
					end
				end)
			end
		end)

		top.InputChanged:Connect(function(input)
			if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
				local delta = input.Position - dragStart
				root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
			end
		end)
	end

	-- Minimize
	local minimized = false
	btnMin.MouseButton1Click:Connect(function()
		minimized = not minimized
		root.Visible = not minimized
	end)

	-- Blur toggle
	local blurOn = false
	btnBlur.MouseButton1Click:Connect(function()
		blurOn = not blurOn
		if blurOn then blur:Enable() else blur:Disable() end
	end)

	-- Close
	btnClose.MouseButton1Click:Connect(function()
		blur:Disable()
		sg:Destroy()
	end)

	-- Object
	local win = {
		_GUI = sg,
		Root = root,
		Theme = theme,
		TabButtons = {},
		Tabs = {},
		Selected = nil,
		PagesFolder = pages,
		ContentHeader = contentHeader,
		ContentSub = contentSub,
		TabList = tabList,
	}
	setmetatable(win, { __index = FluentX })

	-- Tab methods
	function win:AddTab(tabOpts)
		tabOpts = tabOpts or {}
		local tTitle = tabOpts.Title or "Tab"
		local tSub = tabOpts.SubTitle or ""

		local btn = Create("TextButton", {
			BackgroundColor3 = theme.Card,
			AutoButtonColor = false,
			Size = UDim2.new(1, 0, 0, 42),
			Text = "",
			Parent = tabList,
		})
		MakeCorner(btn, theme.CornerSmall)
		local btnStroke = MakeStroke(btn, 1, 0.75); btnStroke.Color = theme.StrokeSoft

		local indicator = Create("Frame", {
			BackgroundColor3 = theme.Accent,
			Size = UDim2.new(0, 4, 1, -16),
			Position = UDim2.fromOffset(10, 8),
			BackgroundTransparency = 1,
			Parent = btn,
		})
		MakeCorner(indicator, 4)

		local lbl = Create("TextLabel", {
			BackgroundTransparency = 1,
			Text = tTitle,
			FontFace = theme.FontBold,
			TextSize = 13,
			TextColor3 = theme.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(22, 9),
			Size = UDim2.new(1, -28, 0, 16),
			Parent = btn,
		})

		local sub = Create("TextLabel", {
			BackgroundTransparency = 1,
			Text = tSub,
			FontFace = theme.Font,
			TextSize = 11,
			TextColor3 = theme.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(22, 24),
			Size = UDim2.new(1, -28, 0, 14),
			Parent = btn,
		})

		local page = Create("ScrollingFrame", {
			Name = "Page_" .. tTitle,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			ScrollBarImageTransparency = 0.8,
			Size = UDim2.fromScale(1, 1),
			CanvasSize = UDim2.fromScale(0, 0),
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Visible = false,
			Parent = pages,
		})
		local layout = MakeList(page, 12)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		MakePadding(page, 4, 4, 10, 10)

		layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			page.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 12)
		end)

		local tabObj = {
			Title = tTitle,
			SubTitle = tSub,
			Button = btn,
			Indicator = indicator,
			Page = page,
			Theme = theme,
		}

		function tabObj:Select()
			if win.Selected and win.Selected ~= tabObj then
				win.Selected.Page.Visible = false
				Tween(win.Selected.Button, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = theme.Card})
				win.Selected.Indicator.BackgroundTransparency = 1
			end

			win.Selected = tabObj
			win.ContentHeader.Text = tTitle
			win.ContentSub.Text = tSub
			tabObj.Page.Visible = true

			Tween(tabObj.Button, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = theme.Card2})
			tabObj.Indicator.BackgroundTransparency = 0
		end

		btn.MouseEnter:Connect(function()
			if win.Selected ~= tabObj then
				Tween(btn, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = theme.Card2})
			end
		end)
		btn.MouseLeave:Connect(function()
			if win.Selected ~= tabObj then
				Tween(btn, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = theme.Card})
			end
		end)
		btn.MouseButton1Click:Connect(function()
			tabObj:Select()
		end)

		-- Section API
		function tabObj:AddSection(secTitle)
			local card = Create("Frame", {
				BackgroundColor3 = theme.Card,
				Size = UDim2.new(1, 0, 0, 0),
				Parent = page,
			})
			MakeCorner(card, theme.Corner)
			local st = MakeStroke(card, 1, 0.75); st.Color = theme.StrokeSoft
			AddShadow(card, theme.Corner, theme.ShadowTransparency)

			MakePadding(card, theme.CardPadding, theme.CardPadding, theme.CardPadding, theme.CardPadding)

			local header = Create("TextLabel", {
				BackgroundTransparency = 1,
				Text = secTitle or "Section",
				FontFace = theme.FontBold,
				TextSize = 13,
				TextColor3 = theme.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, 0, 0, 16),
				Parent = card,
			})

			local list = Create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
				Position = UDim2.fromOffset(0, 22),
				Parent = card,
			})
			local lyt = MakeList(list, 10)
			lyt.HorizontalAlignment = Enum.HorizontalAlignment.Center

			AutoSizeY(list, 0)
			AutoSizeY(card, 22)

			local section = { Container = list, Theme = theme }

			local function ItemShell(height)
				local holder = Create("Frame", {
					BackgroundColor3 = theme.Card2,
					Size = UDim2.new(1, 0, 0, height),
					Parent = list,
				})
				MakeCorner(holder, theme.CornerSmall)
				local sst = MakeStroke(holder, 1, 0.8); sst.Color = theme.StrokeSoft
				MakePadding(holder, 12, 10, 12, 10)
				return holder
			end

			function section:AddParagraph(titleText, bodyText)
				local h = ItemShell(0)
				h.AutomaticSize = Enum.AutomaticSize.Y

				local t = Create("TextLabel", {
					BackgroundTransparency = 1,
					Text = titleText or "",
					FontFace = theme.FontBold,
					TextSize = 12,
					TextColor3 = theme.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
					Size = UDim2.new(1, 0, 0, 14),
					Parent = h
				})
				local b = Create("TextLabel", {
					BackgroundTransparency = 1,
					Text = bodyText or "",
					FontFace = theme.Font,
					TextSize = 12,
					TextColor3 = theme.SubText,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					AutomaticSize = Enum.AutomaticSize.Y,
					Size = UDim2.new(1, 0, 0, 14),
					Position = UDim2.fromOffset(0, 16),
					Parent = h
				})

				return {
					SetTitle = function(_, v) t.Text = v end,
					SetDesc = function(_, v) b.Text = v end,
					Destroy = function() h:Destroy() end
				}
			end

			function section:AddButton(opts)
				opts = opts or {}
				local h = ItemShell(44)
				local btn = Create("TextButton", {
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					Text = "",
					Parent = h,
					AutoButtonColor = false,
				})

				local title = Create("TextLabel", {
					BackgroundTransparency = 1,
					Text = opts.Title or "Button",
					FontFace = theme.FontBold,
					TextSize = 12,
					TextColor3 = theme.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
					Size = UDim2.new(1, -80, 0, 14),
					Parent = h,
				})
				local desc = Create("TextLabel", {
					BackgroundTransparency = 1,
					Text = opts.Description or "",
					FontFace = theme.Font,
					TextSize = 11,
					TextColor3 = theme.SubText,
					TextXAlignment = Enum.TextXAlignment.Left,
					Size = UDim2.new(1, -80, 0, 14),
					Position = UDim2.fromOffset(0, 16),
					Parent = h,
				})

				local pill = Create("Frame", {
					BackgroundColor3 = theme.Accent,
					Size = UDim2.fromOffset(64, 26),
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, 0, 0.5, 0),
					Parent = h,
				})
				MakeCorner(pill, 999)
				local pillText = Create("TextLabel", {
					BackgroundTransparency = 1,
					Text = "RUN",
					FontFace = theme.FontBold,
					TextSize = 12,
					TextColor3 = Color3.fromRGB(8, 12, 16),
					Size = UDim2.fromScale(1, 1),
					Parent = pill,
				})

				local function setHover(on)
					if on then
						Tween(h, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = theme.Panel})
					else
						Tween(h, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = theme.Card2})
					end
				end

				btn.MouseEnter:Connect(function() setHover(true) end)
				btn.MouseLeave:Connect(function() setHover(false) end)
				btn.MouseButton1Click:Connect(function()
					if typeof(opts.Callback) == "function" then
						task.spawn(opts.Callback)
					end
				end)

				return {
					SetTitle = function(_, v) title.Text = v end,
					SetDesc = function(_, v) desc.Text = v end,
					Destroy = function() h:Destroy() end
				}
			end

			function section:AddToggle(opts)
				opts = opts or {}
				local value = not not opts.Default

				local h = ItemShell(44)
				local btn = Create("TextButton", {
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					Text = "",
					Parent = h,
					AutoButtonColor = false,
				})

				local title = Create("TextLabel", {
					BackgroundTransparency = 1,
					Text = opts.Title or "Toggle",
					FontFace = theme.FontBold,
					TextSize = 12,
					TextColor3 = theme.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
					Size = UDim2.new(1, -120, 0, 14),
					Parent = h,
				})
				local desc = Create("TextLabel", {
					BackgroundTransparency = 1,
					Text = opts.Description or "",
					FontFace = theme.Font,
					TextSize = 11,
					TextColor3 = theme.SubText,
					TextXAlignment = Enum.TextXAlignment.Left,
					Size = UDim2.new(1, -120, 0, 14),
					Position = UDim2.fromOffset(0, 16),
					Parent = h,
				})

				local track = Create("Frame", {
					BackgroundColor3 = theme.Stroke,
					Size = UDim2.fromOffset(56, 26),
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, 0, 0.5, 0),
					Parent = h,
				})
				MakeCorner(track, 999)

				local knob = Create("Frame", {
					BackgroundColor3 = theme.Text,
					Size = UDim2.fromOffset(20, 20),
					Position = UDim2.fromOffset(3, 3),
					Parent = track,
				})
				MakeCorner(knob, 999)

				local function render(animated)
					local on = value
					local ti = TweenInfo.new(animated and 0.18 or 0, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
					Tween(track, ti, {BackgroundColor3 = on and theme.Accent or theme.Stroke})
					Tween(knob, ti, {Position = on and UDim2.fromOffset(33, 3) or UDim2.fromOffset(3, 3)})
				end

				local function set(v, fromUser)
					value = not not v
					render(true)
					if fromUser and typeof(opts.Callback) == "function" then
						task.spawn(opts.Callback, value)
					end
					if typeof(opts.Changed) == "function" then
						task.spawn(opts.Changed, value)
					end
				end

				btn.MouseButton1Click:Connect(function()
					set(not value, true)
				end)

				render(false)

				return {
					SetValue = function(_, v) set(v, false) end,
					OnChanged = function(_, fn) opts.Changed = fn end,
					Destroy = function() h:Destroy() end,
				}
			end

			function section:AddSlider(opts)
				opts = opts or {}
				local min = tonumber(opts.Min) or 0
				local max = tonumber(opts.Max) or 100
				local rounding = tonumber(opts.Rounding) or 0
				local value = tonumber(opts.Default) or min
				value = Clamp(value, min, max)

				local h = ItemShell(56)

				local title = Create("TextLabel", {
					BackgroundTransparency = 1,
					Text = opts.Title or "Slider",
					FontFace = theme.FontBold,
					TextSize = 12,
					TextColor3 = theme.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
					Size = UDim2.new(1, -120, 0, 14),
					Parent = h,
				})
				local valLabel = Create("TextLabel", {
					BackgroundTransparency = 1,
					Text = tostring(value),
					FontFace = theme.FontBold,
					TextSize = 12,
					TextColor3 = theme.SubText,
					TextXAlignment = Enum.TextXAlignment.Right,
					Size = UDim2.new(0, 80, 0, 14),
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, 0, 0, 0),
					Parent = h,
				})

				local rail = Create("Frame", {
					BackgroundColor3 = theme.Stroke,
					Size = UDim2.new(1, 0, 0, 8),
					Position = UDim2.fromOffset(0, 30),
					Parent = h,
				})
				MakeCorner(rail, 999)

				local fill = Create("Frame", {
					BackgroundColor3 = theme.Accent,
					Size = UDim2.new(0, 0, 1, 0),
					Parent = rail,
				})
				MakeCorner(fill, 999)

				local knob = Create("Frame", {
					BackgroundColor3 = theme.Text,
					Size = UDim2.fromOffset(14, 14),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0, 0, 0.5, 0),
					Parent = rail,
				})
				MakeCorner(knob, 999)

				local dragging = false

				local function set(v, fromUser)
					v = Clamp(v, min, max)
					v = Round(v, rounding)
					value = v
					valLabel.Text = tostring(value)

					local pct = (value - min) / (max - min)
					fill.Size = UDim2.new(pct, 0, 1, 0)
					knob.Position = UDim2.new(pct, 0, 0.5, 0)

					if fromUser and typeof(opts.Callback) == "function" then
						task.spawn(opts.Callback, value)
					end
					if typeof(opts.Changed) == "function" then
						task.spawn(opts.Changed, value)
					end
				end

				local function inputToValue(x)
					local absPos = rail.AbsolutePosition.X
					local absSize = rail.AbsoluteSize.X
					local pct = Clamp((x - absPos) / absSize, 0, 1)
					return min + (max - min) * pct
				end

				rail.InputBegan:Connect(function(inp)
					if inp.UserInputType == Enum.UserInputType.MouseButton1 then
						dragging = true
						set(inputToValue(UserInputService:GetMouseLocation().X), true)
					end
				end)
				rail.InputEnded:Connect(function(inp)
					if inp.UserInputType == Enum.UserInputType.MouseButton1 then
						dragging = false
					end
				end)

				UserInputService.InputChanged:Connect(function(inp)
					if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
						set(inputToValue(UserInputService:GetMouseLocation().X), true)
					end
				end)

				set(value, false)

				return {
					SetValue = function(_, v) set(v, false) end,
					OnChanged = function(_, fn) opts.Changed = fn end,
					Destroy = function() h:Destroy() end,
				}
			end

			function section:AddInput(opts)
				opts = opts or {}
				local value = tostring(opts.Default or "")

				local h = ItemShell(52)

				local title = Create("TextLabel", {
					BackgroundTransparency = 1,
					Text = opts.Title or "Input",
					FontFace = theme.FontBold,
					TextSize = 12,
					TextColor3 = theme.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
					Size = UDim2.new(1, -120, 0, 14),
					Parent = h,
				})

				local box = Create("TextBox", {
					BackgroundColor3 = theme.Panel,
					Size = UDim2.fromOffset(200, 28),
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, 0, 0, 18),
					Text = value,
					PlaceholderText = opts.Placeholder or "",
					FontFace = theme.Font,
					TextSize = 12,
					TextColor3 = theme.Text,
					ClearTextOnFocus = false,
					Parent = h,
				})
				MakeCorner(box, 10)
				local st = MakeStroke(box, 1, 0.7); st.Color = theme.StrokeSoft
				MakePadding(box, 10, 0, 10, 0)

				local function commit(fromUser)
					local text = box.Text
					if opts.MaxLength and #text > opts.MaxLength then
						text = text:sub(1, opts.MaxLength)
						box.Text = text
					end
					if opts.Numeric then
						if #text > 0 and tonumber(text) == nil then
							box.Text = value
							text = value
						end
					end
					value = text
					if fromUser and typeof(opts.Callback) == "function" then
						task.spawn(opts.Callback, value)
					end
					if typeof(opts.Changed) == "function" then
						task.spawn(opts.Changed, value)
					end
				end

				if opts.Finished then
					box.FocusLost:Connect(function(enterPressed)
						if enterPressed then
							commit(true)
						end
					end)
				else
					box:GetPropertyChangedSignal("Text"):Connect(function()
						commit(true)
					end)
				end

				box.Focused:Connect(function()
					Tween(st, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 0.25})
					st.Color = theme.Accent
				end)
				box.FocusLost:Connect(function()
					Tween(st, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 0.7})
					st.Color = theme.StrokeSoft
				end)

				return {
					SetValue = function(_, v)
						value = tostring(v or "")
						box.Text = value
						commit(false)
					end,
					OnChanged = function(_, fn) opts.Changed = fn end,
					Destroy = function() h:Destroy() end,
				}
			end

			function section:AddDropdown(opts)
				opts = opts or {}
				local values = opts.Values or {}
				local multi = not not opts.Multi
				local current = opts.Default

				local h = ItemShell(52)

				local title = Create("TextLabel", {
					BackgroundTransparency = 1,
					Text = opts.Title or "Dropdown",
					FontFace = theme.FontBold,
					TextSize = 12,
					TextColor3 = theme.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
					Size = UDim2.new(1, -120, 0, 14),
					Parent = h,
				})

				local btn = Create("TextButton", {
					BackgroundColor3 = theme.Panel,
					Size = UDim2.fromOffset(200, 28),
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, 0, 0, 18),
					Text = "",
					AutoButtonColor = false,
					Parent = h,
				})
				MakeCorner(btn, 10)
				local st = MakeStroke(btn, 1, 0.7); st.Color = theme.StrokeSoft

				local label = Create("TextLabel", {
					BackgroundTransparency = 1,
					Text = "--",
					FontFace = theme.Font,
					TextSize = 12,
					TextColor3 = theme.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
					Size = UDim2.new(1, -32, 1, 0),
					Position = UDim2.fromOffset(10, 0),
					Parent = btn,
				})
				local arrow = Create("TextLabel", {
					BackgroundTransparency = 1,
					Text = "▾",
					FontFace = theme.FontBold,
					TextSize = 14,
					TextColor3 = theme.SubText,
					Size = UDim2.fromOffset(24, 24),
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -6, 0.5, 0),
					Parent = btn,
				})

				local popup = Create("Frame", {
					BackgroundColor3 = theme.Panel,
					Visible = false,
					Size = UDim2.fromOffset(220, 220),
					Parent = win._GUI,
				})
				MakeCorner(popup, theme.Corner)
				local pst = MakeStroke(popup, 1, 0.65); pst.Color = theme.StrokeSoft
				AddShadow(popup, theme.Corner, theme.ShadowTransparency)

				local scroll = Create("ScrollingFrame", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ScrollBarThickness = 3,
					ScrollBarImageTransparency = 0.8,
					Size = UDim2.new(1, -10, 1, -10),
					Position = UDim2.fromOffset(5, 5),
					CanvasSize = UDim2.fromScale(0, 0),
					Parent = popup,
				})
				local sLayout = MakeList(scroll, 6)
				sLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
				sLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
					scroll.CanvasSize = UDim2.new(0, 0, 0, sLayout.AbsoluteContentSize.Y + 10)
				end)

				local function display()
					if multi and typeof(current) == "table" then
						local parts = {}
						for k, v in pairs(current) do
							if v then table.insert(parts, k) end
						end
						table.sort(parts)
						label.Text = (#parts > 0) and table.concat(parts, ", ") or "--"
					else
						label.Text = current or "--"
					end
				end

				local function close()
					popup.Visible = false
					Tween(pst, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 0.65})
				end

				local function open()
					-- position near button
					local pos = btn.AbsolutePosition
					local sz = btn.AbsoluteSize
					popup.Position = UDim2.fromOffset(pos.X, pos.Y + sz.Y + 6)
					popup.Visible = true
					Tween(pst, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 0.35})
				end

				local function rebuild()
					for _, ch in ipairs(scroll:GetChildren()) do
						if not ch:IsA("UIListLayout") then ch:Destroy() end
					end

					for _, item in ipairs(values) do
						local opt = Create("TextButton", {
							BackgroundColor3 = theme.Card,
							AutoButtonColor = false,
							Size = UDim2.new(1, 0, 0, 34),
							Text = "",
							Parent = scroll,
						})
						MakeCorner(opt, 10)
						local ost = MakeStroke(opt, 1, 0.8); ost.Color = theme.StrokeSoft

						local dot = Create("Frame", {
							BackgroundColor3 = theme.Accent,
							Size = UDim2.fromOffset(6, 6),
							AnchorPoint = Vector2.new(0, 0.5),
							Position = UDim2.fromOffset(12, 17),
							BackgroundTransparency = 1,
							Parent = opt,
						})
						MakeCorner(dot, 999)

						local tl = Create("TextLabel", {
							BackgroundTransparency = 1,
							Text = tostring(item),
							FontFace = theme.Font,
							TextSize = 12,
							TextColor3 = theme.Text,
							TextXAlignment = Enum.TextXAlignment.Left,
							Size = UDim2.new(1, -20, 1, 0),
							Position = UDim2.fromOffset(22, 0),
							Parent = opt,
						})

						local function isSelected()
							if multi then
								return typeof(current) == "table" and current[item] == true
							end
							return current == item
						end

						local function renderSel()
							local sel = isSelected()
							dot.BackgroundTransparency = sel and 0 or 1
							opt.BackgroundColor3 = sel and theme.Card2 or theme.Card
						end

						renderSel()

						opt.MouseButton1Click:Connect(function()
							if multi then
								if typeof(current) ~= "table" then current = {} end
								current[item] = not current[item]
							else
								current = item
								close()
							end
							renderSel()
							display()
							if typeof(opts.Callback) == "function" then task.spawn(opts.Callback, current) end
							if typeof(opts.Changed) == "function" then task.spawn(opts.Changed, current) end
						end)

						opt.MouseEnter:Connect(function()
							if not isSelected() then
								Tween(opt, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = theme.Card2})
							end
						end)
						opt.MouseLeave:Connect(function()
							renderSel()
						end)
					end
				end

				btn.MouseButton1Click:Connect(function()
					if popup.Visible then close() else open() end
				end)

				UserInputService.InputBegan:Connect(function(inp)
					if popup.Visible and inp.UserInputType == Enum.UserInputType.MouseButton1 then
						local m = UserInputService:GetMouseLocation()
						local p = popup.AbsolutePosition
						local s = popup.AbsoluteSize
						local inside = m.X >= p.X and m.X <= p.X + s.X and m.Y >= p.Y and m.Y <= p.Y + s.Y
						local p2 = btn.AbsolutePosition
						local s2 = btn.AbsoluteSize
						local insideBtn = m.X >= p2.X and m.X <= p2.X + s2.X and m.Y >= p2.Y and m.Y <= p2.Y + s2.Y
						if not inside and not insideBtn then
							close()
						end
					end
				end)

				if multi and typeof(current) ~= "table" then
					local t = {}
					if typeof(opts.Default) == "table" then
						for _, v in ipairs(opts.Default) do t[v] = true end
					end
					current = t
				end

				rebuild()
				display()

				return {
					SetValues = function(_, v)
						values = v or {}
						rebuild()
						display()
					end,
					SetValue = function(_, v)
						current = v
						display()
					end,
					OnChanged = function(_, fn) opts.Changed = fn end,
					Destroy = function()
						popup:Destroy()
						h:Destroy()
					end
				}
			end

			return section
		end

		table.insert(win.Tabs, tabObj)
		table.insert(win.TabButtons, btn)

		if not win.Selected then
			tabObj:Select()
		end

		return tabObj
	end

	return win
end

return setmetatable({}, FluentX)
