--[[
Balloon Up: commercial district inspection (READ-ONLY)

Prints the layout around the Mega Mall so the expansion can be planned on
real coordinates. It creates, moves and deletes nothing.

How to run:
  1. Open the place in Studio (edit mode, not Play).
  2. Optional: select the Mega Mall, or a part inside the expansion area,
     in the Explorer. The scan is centered on the selection.
  3. View > Command Bar. Paste this whole file and press Enter.
  4. In the Output window, copy everything from ==BEGIN== to ==END== and
     paste it to Claude (or save it as a .txt file and attach it).
]]

local SCAN_RADIUS = 600 -- studs around the center
local STEP = 20 -- terrain sample spacing in studs
local MAX_PARTS = 400 -- cap for named road/boundary/delivery parts
local MAX_CHILDREN = 40 -- cap for second-level models per container

local HttpService = game:GetService("HttpService")
local Selection = game:GetService("Selection")
local Lighting = game:GetService("Lighting")
local terrain = workspace.Terrain

local KEYWORDS = {
	"road", "street", "sidewalk", "curb", "crosswalk", "crossing", "parking",
	"boundary", "border", "barrier", "invisible", "retaining", "ramp",
	"bridge", "stair", "spawn", "deliver", "dropoff", "zone", "door",
	"entrance", "gate", "fence", "rail",
}

local function round(n)
	return math.floor(n + 0.5)
end

local function vec(v)
	return { round(v.X), round(v.Y), round(v.Z) }
end

local function emit(t)
	print(HttpService:JSONEncode(t))
end

-- World-aligned bounds of one part.
local function partBounds(p)
	local cf, s = p.CFrame, p.Size / 2
	local x, y, z = cf.XVector, cf.YVector, cf.ZVector
	local ext = Vector3.new(
		math.abs(x.X) * s.X + math.abs(y.X) * s.Y + math.abs(z.X) * s.Z,
		math.abs(x.Y) * s.X + math.abs(y.Y) * s.Y + math.abs(z.Y) * s.Z,
		math.abs(x.Z) * s.X + math.abs(y.Z) * s.Y + math.abs(z.Z) * s.Z
	)
	return cf.Position - ext, cf.Position + ext
end

-- World-aligned bounds and part count of a container (or a single part).
local function bounds(inst)
	local lo, hi, count
	local function add(p)
		local a, b = partBounds(p)
		lo = lo and lo:Min(a) or a
		hi = hi and hi:Max(b) or b
		count = (count or 0) + 1
	end
	if inst:IsA("BasePart") then
		add(inst)
	end
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			add(d)
		end
	end
	return lo, hi, count or 0
end

local function yawOf(inst)
	local ok, pivot = pcall(function()
		return inst:GetPivot()
	end)
	if not ok then
		return nil
	end
	local _, ry = pivot:ToEulerAnglesYXZ()
	return round(math.deg(ry))
end

local function topLevel(inst)
	while inst and inst.Parent ~= workspace do
		inst = inst.Parent
	end
	return inst
end

local function pathOf(inst)
	return inst:GetFullName():gsub("^Workspace%.", "")
end

local function isContainer(inst)
	return inst:IsA("Model") or inst:IsA("Folder") or inst:IsA("BasePart")
end

-- 1. Pick the scan center.
local center
local selected = Selection:Get()
if #selected > 0 then
	local lo, hi = bounds(selected[1])
	if lo then
		center = (lo + hi) / 2
	end
end
if not center then
	for _, c in workspace:GetChildren() do
		if c.Name:lower():find("mall") and isContainer(c) then
			local lo, hi = bounds(c)
			if lo then
				center = (lo + hi) / 2
				break
			end
		end
	end
end
if not center then
	center = workspace.CurrentCamera and workspace.CurrentCamera.Focus.Position or Vector3.zero
end

local function inArea(lo, hi)
	return hi.X >= center.X - SCAN_RADIUS and lo.X <= center.X + SCAN_RADIUS
		and hi.Z >= center.Z - SCAN_RADIUS and lo.Z <= center.Z + SCAN_RADIUS
end

print("==BEGIN==")

local cam = workspace.CurrentCamera
emit({
	t = "meta",
	place = game.Name,
	placeId = game.PlaceId,
	center = vec(center),
	radius = SCAN_RADIUS,
	step = STEP,
	selected = #selected > 0 and pathOf(selected[1]) or nil,
	camera = cam and { pos = vec(cam.CFrame.Position), look = vec(cam.CFrame.LookVector * 100) } or nil,
	lighting = {
		clock = Lighting.ClockTime,
		brightness = Lighting.Brightness,
		technology = tostring(Lighting.Technology),
	},
	gravity = workspace.Gravity,
	streaming = workspace.StreamingEnabled,
})

-- 2. Top-level models/folders, plus one level down. Whole-world entries are
-- always listed; second-level entries only when they touch the scan area.
local worldLo, worldHi
for _, c in workspace:GetChildren() do
	if c ~= terrain and c ~= cam and isContainer(c) then
		local lo, hi, count = bounds(c)
		if lo then
			worldLo = worldLo and worldLo:Min(lo) or lo
			worldHi = worldHi and worldHi:Max(hi) or hi
			emit({ t = "model", depth = 1, path = pathOf(c), class = c.ClassName, min = vec(lo), max = vec(hi), parts = count, yaw = yawOf(c) })
			local listed = 0
			for _, g in c:GetChildren() do
				if listed >= MAX_CHILDREN then
					break
				end
				if (g:IsA("Model") or g:IsA("Folder")) then
					local glo, ghi, gcount = bounds(g)
					if glo and inArea(glo, ghi) then
						listed += 1
						emit({ t = "model", depth = 2, path = pathOf(g), class = g.ClassName, min = vec(glo), max = vec(ghi), parts = gcount, yaw = yawOf(g) })
					end
				end
			end
		end
	end
end
if worldLo then
	emit({ t = "world", min = vec(worldLo), max = vec(worldHi) })
end

-- 3. Named roads, sidewalks, boundaries, delivery zones etc., and invisible
-- collidable walls, inside the scan area.
local parts = 0
for _, d in workspace:GetDescendants() do
	if parts >= MAX_PARTS then
		break
	end
	if d:IsA("BasePart") and d ~= terrain then
		local lname = d.Name:lower()
		local hit = d.Transparency >= 0.95 and d.CanCollide
		if not hit then
			local parentName = d.Parent and d.Parent.Name:lower() or ""
			for _, k in KEYWORDS do
				if lname:find(k, 1, true) or parentName:find(k, 1, true) then
					hit = true
					break
				end
			end
		end
		if hit then
			local lo, hi = partBounds(d)
			if inArea(lo, hi) then
				parts += 1
				local _, ry = d.CFrame:ToEulerAnglesYXZ()
				emit({
					t = "part",
					path = pathOf(d),
					pos = vec(d.Position),
					size = vec(d.Size),
					yaw = round(math.deg(ry)),
					mat = d.Material.Name,
					color = d.Color:ToHex(),
					invisible = d.Transparency >= 0.95 or nil,
					collide = d.CanCollide,
				})
			end
		end
	end
end
emit({ t = "partsDone", count = parts, capped = parts >= MAX_PARTS })

-- 4. Height map. "ground" is the terrain surface; "top" is the highest
-- surface of anything (roofs, trees, roads). "owner" indexes the names list.
local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { terrain }
local everything = RaycastParams.new()
everything.FilterType = Enum.RaycastFilterType.Exclude
everything.FilterDescendantsInstances = {}

local rayTop = center.Y + 1500
local rayDown = Vector3.new(0, -3000, 0)
local materials, materialIndex = {}, {}
local owners, ownerIndex = {}, {}

local function indexOf(list, map, key)
	if not map[key] then
		table.insert(list, key)
		map[key] = #list
	end
	return map[key]
end

local x0 = round(center.X - SCAN_RADIUS)
local z0 = round(center.Z - SCAN_RADIUS)
local n = math.floor(2 * SCAN_RADIUS / STEP) + 1
for row = 0, n - 1 do
	local z = z0 + row * STEP
	local ground, mat, top, owner = {}, {}, {}, {}
	for col = 0, n - 1 do
		local origin = Vector3.new(x0 + col * STEP, rayTop, z)
		local g = workspace:Raycast(origin, rayDown, terrainOnly)
		ground[col + 1] = g and round(g.Position.Y) or -9999
		mat[col + 1] = g and indexOf(materials, materialIndex, g.Material.Name) or 0
		local h = workspace:Raycast(origin, rayDown, everything)
		top[col + 1] = h and round(h.Position.Y) or -9999
		local o = h and h.Instance ~= terrain and topLevel(h.Instance)
		owner[col + 1] = o and indexOf(owners, ownerIndex, o.Name) or 0
	end
	emit({ t = "row", z = z, x0 = x0, step = STEP, ground = ground, mat = mat, top = top, owner = owner })
end
emit({ t = "legend", materials = materials, owners = owners })

print("==END==")
