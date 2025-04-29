--Note this code is a 1 year old 
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local CHUNKsize = 1
local RenderDistance = 100
local waterLVL = 45
local chunkGenerationDelay = 0.0000000000000000001
local chunk_unload_Delay = 0.00000000000000000001
local updateinterval = 0.0000000000000000000000001
local beachthreshold = 3
local blocksize = 3
local chunkPixelSize = CHUNKsize * blocksize
local waterTransparency = 0.5
local maxCachedchunks = RenderDistance * RenderDistance * 4

local STONE_DEPTH = 0
local DIRT_DEPTH = 0

local seed = {
	terain = math.random(100, 999),
	HEIGHT = math.random(1, 99),
	BIOME = math.random(1, 99),
	Tree = math.random(1, 99)
}

local chunkCache = {}
local loadedChunks = {}
local blockPool = {}
local poolSize = 0
local maxpoolSize = 10000

local chunkOperationQueue = {
	load = {},
	unload = {}
}

local renderDistanceSQ = RenderDistance * RenderDistance
local waterY = waterLVL * blocksize

local biome = {
	PLAINS = {
		heightmod = 0.9,
		heightbase = 60,
		color = "Bright green",
		trees = 0.2,
	},
	FLATlands = {
		heightmod = 0.9,
		heightbase = 60,
		color = "Olive",
		trees = 0.01,
		grass = 0.2,
	},
	TAIGA = {
		heightmod = 0.9,
		heightbase = 60,
		color = "Dark green",
		trees = 0.08,
	},
	desert = {
		heightmod = 0.9,
		heightbase = 60,
		color = "Brick yellow",
		cacti = 0.03,
		dunes = true,
	},
	WASTEland = {
		heightmod = 0.9,
		heightbase = 60,
		color = "Brown",
		deadTrees = 0.02,
		rocks = 0.05,
	}
}

local blockPROPS = {
	Dirt = {color = "Brown", mat = "Ground"},
	Grass = {color = "Bright green", mat = "Grass"},
	Wood = {color = "Medium brown", mat = "Wood"},
	Leaves = {color = "Forest green", mat = "Grass"},
	Stone = {color = "Medium stone grey", mat = "Slate"},
	Sand = {color = "Brick yellow", mat = "Sand"},
	Water = {color = "Bright blue", mat = "Glass"},
	DeadWood = {color = "Dark grey", mat = "Wood"},
	Cactus = {color = "Forest green", mat = "Grass"},
	Flower = {color = "Yellow", mat = "Neon"},
	TallGrass = {color = "Bright green", mat = "Grass"},
	Rock = {color = "Dark stone grey", mat = "Slate"}
}

local treeTemplates = {
	normal = {
		trunk = {{0,1,0}, {0,2,0}, {0,3,0}},
		leaves = {
			{1,4,0}, {2,4,0}, {0,4,1}, {0,4,2}, {0,4,-1}, {0,4,-2},
			{-1,4,0}, {-2,4,0}, {1,5,0}, {-1,5,0}, {0,5,1}, {0,5,-1},
			{1,6,0}, {-1,6,0}, {0,6,1}, {0,6,-1}
		}
	},
	taiga = {
		trunk = {{0,1,0}, {0,2,0}, {0,3,0}, {0,4,0}, {0,5,0}},
		leaves = {
			{1,3,0}, {-1,3,0}, {0,3,1}, {0,3,-1},
			{1,4,0}, {-1,4,0}, {0,4,1}, {0,4,-1},
			{0,6,0}
		}
	},
	dead = {
		trunk = {{0,1,0}, {0,2,0}, {0,3,0}},
		branches = {{1,3,0}, {-1,3,0}}
	}
}

local function getblock()
	if #blockPool > 0 then
		return table.remove(blockPool)
	end

	local block = Instance.new("Part")
	block.Anchored = true
	block.TopSurface = Enum.SurfaceType.Smooth
	block.BottomSurface = Enum.SurfaceType.Smooth
	block.Size = Vector3.new(blocksize, blocksize, blocksize)
	return block
end

local function recycleblock(block)
	if poolSize < maxpoolSize then
		block.Parent = nil
		block.Transparency = 0
		block.CanCollide = true
		block.CastShadow = true
		table.insert(blockPool, block)
		poolSize = poolSize + 1
	else
		block:Destroy()
	end
end

local function createBLOCK(pos, type, parent)
	local block = getblock()
	local props = blockPROPS[type]

	block.CFrame = CFrame.new(pos)
	block.Material = Enum.Material[props.mat]
	block.BrickColor = BrickColor.new(props.color)

	if type == "Water" then
		block.Transparency = waterTransparency
		block.CanCollide = false
		block.CastShadow = false
	elseif type == "Cactus" or type == "TallGrass" or type == "Flower" then
		block.Transparency = 0.3
	else
		block.Transparency = 0
		block.CanCollide = true
		block.CastShadow = true
	end

	block.Parent = parent
	return block
end

local noiseCache = {}
local noiseCacheLimit = 5000

local function fastnoise(x, z, seed)
	local key = x * 10000 + z + seed * 1000000
	local cached = noiseCache[key]
	if cached then return cached end

	local noise = math.noise(x + seed, z)

	if #noiseCache > noiseCacheLimit then
		table.remove(noiseCache, 1)
	end
	noiseCache[key] = noise
	return noise
end

local function getBIOME(x, z)
	local noise = fastnoise(x/150, z/150, seed.BIOME)

	if noise < -0.4 then return biome.desert
	elseif noise < -0.2 then return biome.WASTEland
	elseif noise < 0.1 then return biome.PLAINS
	elseif noise < 0.3 then return biome.FLATlands
	else return biome.TAIGA end
end

local function getHEIGHT(x, z)
	local key = x * 10000 + z
	local cached = chunkCache[key]
	if cached then return cached end

	local currentBiome = getBIOME(x, z)
	local baseNoise = fastnoise(x/100, z/100, seed.HEIGHT)

	local height = math.floor(baseNoise * 35 * currentBiome.heightmod + currentBiome.heightbase)

	if currentBiome.dunes then
		height = height + fastnoise(x/15, z/15, seed.terain) * 3
	end

	chunkCache[key] = height
	return height
end

local function isNearWater(x, z)
	local count = 0
	for dx = -1, 1, 2 do
		for dz = -1, 1, 2 do
			if getHEIGHT(x + dx, z + dz) < waterLVL then
				count = count + 1
				if count >= 2 then return true end
			end
		end
	end
	return false
end

local function createTREE(pos, biome, blocks, parent)
	local template
	if biome == biome.TAIGA then
		template = treeTemplates.taiga
	elseif biome == biome.WASTEland then
		template = treeTemplates.dead
	else
		template = treeTemplates.normal
	end

	for _, v in ipairs(template.trunk) do
		local blockPos = Vector3.new(
			pos.X + v[1] * blocksize,
			pos.Y + v[2] * blocksize,
			pos.Z + v[3] * blocksize
		)
		table.insert(blocks, createBLOCK(blockPos, biome == biome.WASTEland and "DeadWood" or "Wood", parent))
	end

	if biome ~= biome.WASTEland and template.leaves then
		for _, v in ipairs(template.leaves) do
			local blockPos = Vector3.new(
				pos.X + v[1] * blocksize,
				pos.Y + v[2] * blocksize,
				pos.Z + v[3] * blocksize
			)
			table.insert(blocks, createBLOCK(blockPos, "Leaves", parent))
		end
	elseif template.branches then
		for _, v in ipairs(template.branches) do
			local blockPos = Vector3.new(
				pos.X + v[1] * blocksize,
				pos.Y + v[2] * blocksize,
				pos.Z + v[3] * blocksize
			)
			table.insert(blocks, createBLOCK(blockPos, "DeadWood", parent))
		end
	end
end

local function createCHUNK(chunkX, chunkZ, parent)
	local blocks = table.create(CHUNKsize * CHUNKsize * 10)
	local worldX, worldZ = chunkX * CHUNKsize, chunkZ * CHUNKsize

	for dx = 0, CHUNKsize - 1 do
		local x = worldX + dx
		for dz = 0, CHUNKsize - 1 do
			local z = worldZ + dz

			local currentBiome = getBIOME(x, z)
			local height = getHEIGHT(x, z)
			local isBeach = isNearWater(x, z)

			local blockPos = Vector3.new(x * blocksize, height * blocksize, z * blocksize)

			for y = height - STONE_DEPTH, height - DIRT_DEPTH - 1 do
				table.insert(blocks, createBLOCK(
					Vector3.new(x * blocksize, y * blocksize, z * blocksize),
					"Stone",
					parent
					))
			end

			for y = height - DIRT_DEPTH, height - 1 do
				table.insert(blocks, createBLOCK(
					Vector3.new(x * blocksize, y * blocksize, z * blocksize),
					"Dirt",
					parent
					))
			end

			if isBeach and height <= waterLVL + beachthreshold or currentBiome == biome.desert then
				table.insert(blocks, createBLOCK(blockPos, "Sand", parent))
			else
				local block = createBLOCK(blockPos, "Grass", parent)
				block.BrickColor = BrickColor.new(currentBiome.color)
				table.insert(blocks, block)
			end

			if height < waterLVL then
				for y = height + 1, waterLVL do
					table.insert(blocks, createBLOCK(
						Vector3.new(x * blocksize, y * blocksize, z * blocksize),
						"Water",
						parent
						))
				end
			end

			if height > waterLVL + 2 and not isBeach then
				if currentBiome == biome.desert and math.random() < currentBiome.cacti then
					for y = 1, math.random(2, 4) do
						table.insert(blocks, createBLOCK(
							Vector3.new(x * blocksize, (height + y) * blocksize, z * blocksize),
							"Cactus",
							parent
							))
					end
				elseif math.random() < (currentBiome.trees or currentBiome.deadTrees or 0) then
					createTREE(blockPos, currentBiome, blocks, parent)
				elseif currentBiome.rocks and math.random() < currentBiome.rocks then
					table.insert(blocks, createBLOCK(
						blockPos + Vector3.new(0, blocksize, 0),
						"Rock",
						parent
						))
				end
			end
		end
	end

	return blocks
end

local lastUpdate = 0
local lastChunkX, lastChunkZ = 0, 0

local function updateCHUNKS()
	local now = tick()
	if now - lastUpdate < updateinterval then return end
	lastUpdate = now

	local player = Players.LocalPlayer
	if not player or not player.Character or not player.Character.PrimaryPart then return end

	local pos = player.Character.PrimaryPart.Position
	local chunkX = math.floor(pos.X / chunkPixelSize)
	local chunkZ = math.floor(pos.Z / chunkPixelSize)

	if chunkX == lastChunkX and chunkZ == lastChunkZ then return end
	lastChunkX, lastChunkZ = chunkX, chunkZ

	table.clear(chunkOperationQueue.load)
	table.clear(chunkOperationQueue.unload)

	task.spawn(function()
		for dx = -RenderDistance, RenderDistance do
			local x = chunkX + dx
			loadedChunks[x] = loadedChunks[x] or {}

			for dz = -RenderDistance, RenderDistance do
				local z = chunkZ + dz
				local distSq = dx * dx + dz * dz

				if distSq <= renderDistanceSQ and not loadedChunks[x][z] then
					table.insert(chunkOperationQueue.load, {x = x, z = z})
				end
			end
		end
	end)

	task.spawn(function()
		for x, zChunks in pairs(loadedChunks) do
			local dx = x - chunkX
			if math.abs(dx) > RenderDistance then
				for z, blocks in pairs(zChunks) do
					table.insert(chunkOperationQueue.unload, {x = x, z = z, blocks = blocks})
				end
			else
				for z, blocks in pairs(zChunks) do
					local dz = z - chunkZ
					if math.abs(dz) > RenderDistance then
						table.insert(chunkOperationQueue.unload, {x = x, z = z, blocks = blocks})
					end
				end
			end
		end
	end)
end

local function processChunkOPERATIONS()
	task.spawn(function()
		while #chunkOperationQueue.load > 0 do
			local chunk = table.remove(chunkOperationQueue.load, 1)
			loadedChunks[chunk.x][chunk.z] = createCHUNK(chunk.x, chunk.z, workspace.Map)
			task.wait(chunkGenerationDelay)
		end
	end)

	task.spawn(function()
		while #chunkOperationQueue.unload > 0 do
			local chunk = table.remove(chunkOperationQueue.unload, 1)
			for _, block in ipairs(chunk.blocks) do
				recycleblock(block)
			end
			if loadedChunks[chunk.x] then
				loadedChunks[chunk.x][chunk.z] = nil
				if not next(loadedChunks[chunk.x]) then
					loadedChunks[chunk.x] = nil
				end
			end
			task.wait(chunk_unload_Delay)
		end
	end)
end

local Map = Instance.new("Folder")
Map.Name = "Map"
Map.Parent = workspace

RunService.Heartbeat:Connect(updateCHUNKS)
RunService.Heartbeat:Connect(processChunkOPERATIONS)

task.spawn(function()
	while task.wait(60) do
		if #noiseCache > noiseCacheLimit then
			table.clear(noiseCache)
		end
	end
end)

return {
	CHUNKsize = CHUNKsize,
	RenderDistance = RenderDistance,
	waterLVL = waterLVL,
	seed = seed,
	blocksize = blocksize,
	STONE_DEPTH = STONE_DEPTH,
	DIRT_DEPTH = DIRT_DEPTH
} 
