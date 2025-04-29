local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local gui = Instance.new("ScreenGui")
gui.Name = "TesseractGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true

if Players.LocalPlayer then
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
else
	gui.Parent = game:GetService("StarterGui")
end

local vf = Instance.new("ViewportFrame")
vf.Name = "TesseractView"
vf.Size = UDim2.new(1, 0, 1, 0)
vf.BackgroundColor3 = Color3.new(0, 0, 0)
vf.BackgroundTransparency = 0
vf.BorderSizePixel = 0
vf.Parent = gui

local cc = Instance.new("ColorCorrectionEffect")
cc.Brightness = -0.1
cc.Contrast = 0.2
cc.Saturation = -0.1
cc.TintColor = Color3.new(0.9, 0.9, 1)
cc.Parent = vf

local model = Instance.new("Model")
model.Name = "Tesseract"
model.Parent = vf

local baseVerts, verts, points, edges = {}, {}, {}, {}

local function v4(x, y, z, w)
	return {x = x, y = y, z = z, w = w}
end

for i = 0, 15 do
	local x = (bit32.band(i, 1) == 0) and -1 or 1
	local y = (bit32.band(i, 2) == 0) and -1 or 1
	local z = (bit32.band(i, 4) == 0) and -1 or 1
	local w = (bit32.band(i, 8) == 0) and -1 or 1
	local p = v4(x, y, z, w)
	table.insert(baseVerts, p)
	table.insert(verts, p)
end

for i = 1, #verts do
	local p = Instance.new("Part")
	p.Size = Vector3.new(0.3, 0.3, 0.3)
	p.Anchored = true
	p.CanCollide = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = Color3.new(0.5, 0.5, 0.5)
	p.Parent = model
	points[i] = p
end

local function proj(v)
	local d = 3
	local f = d / (d - v.w)
	return Vector3.new(v.x * f, v.y * f, v.z * f)
end

local function isEdge(a, b)
	local d = 0
	if a.x ~= b.x then d += 1 end
	if a.y ~= b.y then d += 1 end
	if a.z ~= b.z then d += 1 end
	if a.w ~= b.w then d += 1 end
	return d == 1
end

for i = 1, #verts do
	for j = i + 1, #verts do
		if isEdge(baseVerts[i], baseVerts[j]) then
			local p = Instance.new("Part")
			p.Anchored = true
			p.CanCollide = false
			p.Material = Enum.Material.SmoothPlastic
			p.Color = Color3.new(0.5, 0.5, 0.5)
			p.Size = Vector3.new(0.2, 0.2, 1)
			p.Parent = model
			table.insert(edges, {part = p, i1 = i, i2 = j})
		end
	end
end

local axw, ayw, azw = 0, 0, 0
local sxw, syw, szw = 0.5, 0.7, 0.9
local scale = 5
local t = 0

local cam = Instance.new("Camera")
cam.CFrame = CFrame.new(Vector3.new(0, 0, 15), Vector3.new(0, 0, 0))
vf.CurrentCamera = cam

local function light(pos, target, col, bright, ang)
	local l = Instance.new("SpotLight")
	l.Brightness = bright
	l.Color = col
	l.Range = 60
	l.Shadows = true
	l.Angle = ang
	l.Face = Enum.NormalId.Front

	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.Position = pos
	p.Parent = model
	l.Parent = p
	p.CFrame = CFrame.lookAt(pos, target)
	return l
end

local l1 = light(Vector3.new(10, 15, 20), Vector3.new(0, 0, 0), Color3.new(0.7, 0.8, 1), 2.5, 45)
local l2 = light(Vector3.new(-15, 5, 10), Vector3.new(0, 0, 0), Color3.new(0.5, 0.3, 0.8), 1.5, 60)
local l3 = light(Vector3.new(0, -10, -15), Vector3.new(0, 0, 0), Color3.new(0.2, 0.9, 0.7), 1.8, 30)

local atm = Instance.new("Atmosphere")
atm.Density = 0.3
atm.Color = Color3.new(0, 0, 0.1)
atm.Decay = Color3.new(0.1, 0.1, 0.3)
atm.Glare = 0.2
atm.Haze = 1
atm.Parent = vf

local function rot(v, axw, ayw, azw)
	local x, y, z, w = v.x, v.y, v.z, v.w

	local nx = x * math.cos(axw) - w * math.sin(axw)
	local nw = x * math.sin(axw) + w * math.cos(axw)
	x, w = nx, nw

	local ny = y * math.cos(ayw) - w * math.sin(ayw)
	nw = y * math.sin(ayw) + w * math.cos(ayw)
	y, w = ny, nw

	local nz = z * math.cos(azw) - w * math.sin(azw)
	nw = z * math.sin(azw) + w * math.cos(azw)
	z, w = nz, nw

	return {x = x, y = y, z = z, w = w}
end

RunService.RenderStepped:Connect(function(dt)
	t += dt
	axw += sxw * dt
	ayw += syw * dt
	azw += szw * dt

	cc.Brightness = -0.1 + math.sin(t * 5) * 0.05

	for i, base in ipairs(baseVerts) do
		local r = rot(base, axw, ayw, azw)
		verts[i] = r

		local p3 = proj(r) * scale
		local twist = CFrame.Angles(math.sin(t * 0.5) * 0.5, math.cos(t * 0.5) * 0.5, math.sin(t * 0.3) * 0.5)
		p3 = (twist * CFrame.new(p3)).p
		points[i].Position = p3
	end

	for _, e in ipairs(edges) do
		local p1 = proj(verts[e.i1]) * scale
		local p2 = proj(verts[e.i2]) * scale
		local twist = CFrame.Angles(math.sin(t * 0.5) * 0.5, math.cos(t * 0.5) * 0.5, math.sin(t * 0.3) * 0.5)
		p1 = (twist * CFrame.new(p1)).p
		p2 = (twist * CFrame.new(p2)).p
		local mid = (p1 + p2) / 2
		local dir = p2 - p1
		e.part.Size = Vector3.new(0.25, 0.25, dir.Magnitude)
		e.part.CFrame = CFrame.new(mid, p2)
	end

	local angle = t * 0.1
	local rad = 18
	local h = math.sin(t * 0.07) * 5
	local camPos = Vector3.new(math.cos(angle) * rad, h, math.sin(angle) * rad)
	cam.CFrame = CFrame.lookAt(camPos, Vector3.new(0, 0, 0))

	local o = t * 0.2
	l1.Color = Color3.new(0.7 + math.sin(o) * 0.3, 0.8 + math.sin(o + 2) * 0.2, 1)
	l2.Color = Color3.new(0.5 + math.sin(o + 1) * 0.2, 0.3 + math.cos(o) * 0.2, 0.8 + math.sin(o + 3) * 0.2)
end) 
