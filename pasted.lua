local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local Toggles = Library.Toggles

local SCRIPT_URL = "https://raw.githubusercontent.com/jakenortha2-beep/pasted.lol/refs/heads/main/pasted.lua"

local StateFolder = "ScriptMenu"
local StateFile = StateFolder .. "/state.json"

local LOAD_TIMEOUT = 15

local RIVALS_MODULES = {
	"CONSTANTS",
	"EnumLibrary",
	"InputLibrary",
	"ItemLibrary",
	"DuelLibrary",
	"Utility",
	"PlayerDataUtility",
	"TaskLibrary",
	"ReplicatedClass",
}

local RIVALS_CONTROLLERS = {
	"ControlsController",
	"FighterController",
	"MechanicsController",
	"EnemyController",
	"CameraController",
	"DuelController",
	"PlayerDataController",
	"MatchmakingController",
}

local RIVALS_REMOTES = {
	"UseItem",
	"UpdateState",
	"PickWeapons",
	"UpdateCameraRotation",
	"RegisterQuickAttack",
}

local function toRawUrl(url)
	local owner, name, branch, path = url:match("^https?://github%.com/([^/]+)/([^/]+)/blob/([^/]+)/(.+)$")

	if owner then
		return string.format("https://raw.githubusercontent.com/%s/%s/%s/%s", owner, name, branch, path)
	end

	return url
end

SCRIPT_URL = toRawUrl(SCRIPT_URL)

local function loadState()
	local state = {}

	if typeof(readfile) == "function" and typeof(isfile) == "function" then
		local hasFile, exists = pcall(isfile, StateFile)

		if hasFile and exists then
			local readOk, contents = pcall(readfile, StateFile)

			if readOk and typeof(contents) == "string" and contents ~= "" then
				local decodeOk, decoded = pcall(HttpService.JSONDecode, HttpService, contents)

				if decodeOk and typeof(decoded) == "table" then
					state = decoded
				end
			end
		end
	end

	return state
end

local function saveState(state)
	if typeof(makefolder) == "function" and typeof(isfolder) == "function" then
		local folderOk, exists = pcall(isfolder, StateFolder)

		if folderOk and not exists then
			pcall(makefolder, StateFolder)
		end
	end

	if typeof(writefile) == "function" then
		local encodeOk, encoded = pcall(HttpService.JSONEncode, HttpService, state)

		if encodeOk then
			pcall(writefile, StateFile, encoded)
		end
	end
end

local function colorToTable(color)
	return { math.round(color.R * 255), math.round(color.G * 255), math.round(color.B * 255) }
end

local function tableToColor(value, fallback)
	if type(value) == "table" then
		return Color3.fromRGB(value[1] or 255, value[2] or 255, value[3] or 255)
	end

	return fallback or Color3.new(1, 1, 1)
end

local function withDefaults(saved, defaults)
	local result = {}

	for key, value in pairs(defaults) do
		result[key] = value
	end

	if type(saved) == "table" then
		for key, value in pairs(saved) do
			result[key] = value
		end
	end

	return result
end

local WorldColorDefaults = {
	Enabled = false,
	Ambient = { 128, 128, 128 },
	ClockTime = 14,
	Brightness = 2,
	Fog = { 192, 192, 192 },
	FogEnd = 5000,
	Exposure = 0,
	Saturation = 0,
	Tint = { 255, 255, 255 },
}

local SkyboxDefaults = {
	Enabled = false,
	Preset = "None",
}

local WeatherDefaults = {
	Enabled = false,
	Preset = "Rain",
	Intensity = 1,
	Color = { 255, 255, 255 },
}

local WEATHER_OPTIONS = { "Rain", "Snow" }

local function resolveQueueOnTeleport()
	local candidates = {
		queue_on_teleport,
		queueonteleport,
		getgenv().queue_on_teleport,
		getgenv().queueonteleport,
		syn and syn.queue_on_teleport,
		fluxus and fluxus.queue_on_teleport,
		Krnl and Krnl.queue_on_teleport,
	}

	for _, candidate in ipairs(candidates) do
		if typeof(candidate) == "function" then
			return candidate
		end
	end

	return nil
end

local function findChild(parent, name, deadline)
	if not parent then
		return nil
	end

	local existing = parent:FindFirstChild(name)

	if existing then
		return existing
	end

	local budget = deadline - os.clock()

	if budget <= 0 then
		return nil
	end

	local ok, child = pcall(parent.WaitForChild, parent, name, budget)

	if ok and child then
		return child
	end

	return parent:FindFirstChild(name)
end

local function awaitCharacter(player, deadline)
	while os.clock() < deadline do
		local character = player.Character

		if character and character.Parent and character:FindFirstChild("Humanoid") then
			return character
		end

		task.wait(0.1)
	end

	return nil
end

local function awaitRivals()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end

	local deadline = os.clock() + LOAD_TIMEOUT
	local player = Players.LocalPlayer

	while not player and os.clock() < deadline do
		task.wait(0.1)
		player = Players.LocalPlayer
	end

	if not player then
		return false, "LocalPlayer"
	end

	local character = awaitCharacter(player, deadline)

	if not character then
		return false, "Character/Humanoid"
	end

	local modules = findChild(ReplicatedStorage, "Modules", deadline)

	if not modules then
		return false, "ReplicatedStorage.Modules"
	end

	for _, name in ipairs(RIVALS_MODULES) do
		if not findChild(modules, name, deadline) then
			return false, "Modules." .. name
		end
	end

	local remotes = findChild(ReplicatedStorage, "Remotes", deadline)

	if not remotes then
		return false, "ReplicatedStorage.Remotes"
	end

	local replication = findChild(remotes, "Replication", deadline)

	if not replication then
		return false, "Remotes.Replication"
	end

	local fighter = findChild(replication, "Fighter", deadline)

	if not fighter then
		return false, "Replication.Fighter"
	end

	for _, name in ipairs(RIVALS_REMOTES) do
		if not findChild(fighter, name, deadline) then
			return false, "Fighter." .. name
		end
	end

	local playerScripts = findChild(player, "PlayerScripts", deadline)

	if not playerScripts then
		return false, "PlayerScripts"
	end

	local controllers = findChild(playerScripts, "Controllers", deadline)

	if not controllers then
		return false, "PlayerScripts.Controllers"
	end

	for _, name in ipairs(RIVALS_CONTROLLERS) do
		if not findChild(controllers, name, deadline) then
			return false, "Controllers." .. name
		end
	end

	local clientModules = findChild(playerScripts, "Modules", deadline)

	if not clientModules then
		return false, "PlayerScripts.Modules"
	end

	local replicatedClasses = findChild(clientModules, "ClientReplicatedClasses", deadline)

	if not replicatedClasses then
		return false, "ClientReplicatedClasses"
	end

	if not findChild(replicatedClasses, "ClientFighter", deadline) then
		return false, "ClientReplicatedClasses.ClientFighter"
	end

	return true
end

local QueueOnTeleport = resolveQueueOnTeleport()

local RERUN_CODE = string.format("pcall(function() loadstring(game:HttpGet(%q))() end)", SCRIPT_URL)

local function applyRerun(enabled)
	if not QueueOnTeleport then
		return
	end

	if enabled then
		pcall(QueueOnTeleport, RERUN_CODE)
	else
		pcall(QueueOnTeleport, "")
	end
end

local State = loadState()

applyRerun(State.ReRunAfterTeleport == true)

local loaded, ready, reason = pcall(awaitRivals)

local CollectionService = game:GetService("CollectionService")

local function requireFrom(parent, ...)
	if not parent then
		return nil
	end

	local node = parent

	for index = 1, select("#", ...) do
		node = node:FindFirstChild(select(index, ...))

		if not node then
			return nil
		end
	end

	local ok, result = pcall(require, node)

	if ok then
		return result
	end

	return nil
end

local localPlayer = Players.LocalPlayer
local playerScripts = localPlayer and localPlayer:FindFirstChild("PlayerScripts")
local controllers = playerScripts and playerScripts:FindFirstChild("Controllers")
local clientModules = playerScripts and playerScripts:FindFirstChild("Modules")
local userInterface = clientModules and clientModules:FindFirstChild("UserInterface")
local sharedModules = ReplicatedStorage:FindFirstChild("Modules")
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
local replication = remotes and remotes:FindFirstChild("Replication")
local fighterRemotes = replication and replication:FindFirstChild("Fighter")

local Rivals = {
	MatchmakingController = requireFrom(controllers, "MatchmakingController"),
	FighterController = requireFrom(controllers, "FighterController"),
	ItemLibrary = requireFrom(sharedModules, "ItemLibrary"),
	DuelLibrary = requireFrom(sharedModules, "DuelLibrary"),
	Constants = requireFrom(sharedModules, "CONSTANTS"),
	Pages = requireFrom(userInterface, "Pages"),
	PickWeaponsRemote = fighterRemotes and fighterRemotes:FindFirstChild("PickWeapons"),
	UseItemRemote = fighterRemotes and fighterRemotes:FindFirstChild("UseItem"),
}

local Settings = {
	AutoQueue = State.AutoQueue or { Enabled = false, Queue = "1v1" },
	AutoLoadout = State.AutoLoadout or { Enabled = false, Slots = {} },
	AntiKatana = State.AntiKatana or { Enabled = false },
	SubspaceTripmines = State.SubspaceTripmines or { AutoTrigger = false, TeamTrigger = false },
	WorldColor = withDefaults(State.WorldColor, WorldColorDefaults),
	Skybox = withDefaults(State.Skybox, SkyboxDefaults),
	Weather = withDefaults(State.Weather, WeatherDefaults),
}

for name, value in pairs(Settings) do
	State[name] = value
end

if type(Settings.AutoLoadout.Slots) ~= "table" then
	Settings.AutoLoadout.Slots = {}
end

if not table.find(WEATHER_OPTIONS, Settings.Weather.Preset) then
	Settings.Weather.Preset = WEATHER_OPTIONS[1]
end

local firetouchinterest = firetouchinterest or function() end

local function localHitboxBody()
	local character = Players.LocalPlayer.Character

	if character then
		return character:FindFirstChild("HitboxBody")
	end

	return nil
end

local function localEnvironmentId()
	local character = Players.LocalPlayer.Character

	if character then
		local value = character:GetAttribute("EnvironmentID") or character:GetAttribute("EnvironmentId")

		if value ~= nil then
			return value
		end
	end

	return Players.LocalPlayer:GetAttribute("EnvironmentID") or Players.LocalPlayer:GetAttribute("EnvironmentId")
end

local function tripmineBelongsToTeam(hitbox)
	if hitbox:GetAttribute("PlacedByUserID") == Players.LocalPlayer.UserId then
		return true
	end

	local teamId = hitbox:GetAttribute("TeamID")
	local myTeamId = Players.LocalPlayer:GetAttribute("TeamID") or Players.LocalPlayer:GetAttribute("TeamId")

	return teamId ~= nil and myTeamId ~= nil and teamId == myTeamId
end

local function triggerTripmines()
	if not Settings.SubspaceTripmines.AutoTrigger then
		return
	end

	local body = localHitboxBody()

	if not body then
		return
	end

	local environment = localEnvironmentId()

	for _, hitbox in ipairs(CollectionService:GetTagged("SubspaceTripmine")) do
		if hitbox:IsA("BasePart") then
			local teamMine = tripmineBelongsToTeam(hitbox)
			local environmentMatches = environment == nil or hitbox:GetAttribute("EnvironmentID") == environment

			if environmentMatches and (Settings.SubspaceTripmines.TeamTrigger or not teamMine) then
				firetouchinterest(hitbox, body, 0)
				firetouchinterest(hitbox, body, 1)
			end
		end
	end
end

task.spawn(function()
	while true do
		pcall(triggerTripmines)
		task.wait(0.15)
	end
end)

local queueToken = 0

local function queueNames()
	local options = {}
	local library = Rivals.DuelLibrary

	if type(library) == "table" then
		local queues = library.MatchmakingQueues

		if type(queues) == "table" then
			for _, name in ipairs(library.MatchmakingQueueOrder or {}) do
				if queues[name] ~= nil then
					table.insert(options, name)
				end
			end
		end

		for _, name in ipairs(library.ArcadeModeOrder or {}) do
			table.insert(options, name)
		end
	end

	if #options == 0 then
		options = { "1v1", "2v2", "3v3", "4v4" }
	end

	return options
end

local function applyAutoQueue()
	queueToken = queueToken + 1

	local controller = Rivals.MatchmakingController

	if not Settings.AutoQueue.Enabled or type(controller) ~= "table" or typeof(controller.QueueInto) ~= "function" then
		return
	end

	local token = queueToken

	task.spawn(function()
		while Settings.AutoQueue.Enabled and token == queueToken do
			if Players.LocalPlayer.Character ~= nil then
				pcall(controller.QueueInto, controller, Settings.AutoQueue.Queue)
			end

			task.wait(5)
		end
	end)
end

local loadoutSlots = {
	{ Name = "Primary", Class = "Primary" },
	{ Name = "Secondary", Class = "Secondary" },
	{ Name = "Melee", Class = "Melee" },
	{ Name = "Utility", Class = "Utility" },
}

local function itemOptions(class)
	local options = { "Unselected" }
	local library = Rivals.ItemLibrary

	if type(library) == "table" and type(library.Items) == "table" then
		for name, item in pairs(library.Items) do
			if name ~= "MISSING_WEAPON" and type(item) == "table" and item.Class == class then
				table.insert(options, name)
			end
		end

		table.sort(options, function(left, right)
			if left == "Unselected" then
				return true
			end

			if right == "Unselected" then
				return false
			end

			return left < right
		end)
	end

	return options
end

local lastLoadoutPick = 0

local function applyAutoLoadout()
	if not Settings.AutoLoadout.Enabled or os.clock() - lastLoadoutPick < 1 then
		return
	end

	local remote = Rivals.PickWeaponsRemote

	if not remote then
		return
	end

	lastLoadoutPick = os.clock()

	local constants = Rivals.Constants
	local defaults = type(constants) == "table" and constants.DEFAULT_WEAPONS or nil
	local payload = {}

	for index, slot in ipairs(loadoutSlots) do
		local chosen = Settings.AutoLoadout.Slots[slot.Name]

		if chosen == nil or chosen == "Unselected" then
			chosen = defaults and defaults[index]
		end

		payload[index] = chosen
	end

	pcall(function()
		remote:FireServer(payload)
	end)
end

local pages = Rivals.Pages
local pageSystem = type(pages) == "table" and pages.PageSystem or nil
local pageOpened = type(pageSystem) == "table" and pageSystem.PageOpened or nil

if pageOpened and typeof(pageOpened.Connect) == "function" then
	pageOpened:Connect(function(page)
		local name = page and page.Name

		if typeof(name) == "string" and string.sub(name, 1, 11) == "PickWeapons" then
			applyAutoLoadout()
		end
	end)
end

local function targetIsShielded()
	local controller = Rivals.FighterController

	if type(controller) ~= "table" then
		return false
	end

	local fighters = controller._player_to_fighter

	if type(fighters) ~= "table" then
		return false
	end

	for player, fighter in pairs(fighters) do
		if player ~= Players.LocalPlayer and fighter and fighter.IsEnemy == true then
			local observer = fighter.ItemObserver

			if observer and typeof(observer.EquippedItemAsMelee) == "function" then
				local ok, melee = pcall(observer.EquippedItemAsMelee, observer)

				if ok and melee and typeof(melee.IsDeflecting) == "function" then
					local ok2, deflecting = pcall(melee.IsDeflecting, melee)

					if ok2 and deflecting == true then
						return true
					end
				end
			end
		end
	end

	return false
end

if typeof(hookmetamethod) == "function" and typeof(getnamecallmethod) == "function" then
	pcall(function()
		local originalNamecall

		originalNamecall = hookmetamethod(game, "__namecall", function(...)
			local self = ...

			if self == Rivals.UseItemRemote and Settings.AntiKatana.Enabled and getnamecallmethod() == "FireServer" then
				local ok, shielded = pcall(targetIsShielded)

				if ok and shielded then
					return
				end
			end

			return originalNamecall(...)
		end)
	end)
end

local worldColorOriginal = nil

local function captureWorldColor()
	if worldColorOriginal then
		return
	end

	worldColorOriginal = {
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		ClockTime = Lighting.ClockTime,
		Brightness = Lighting.Brightness,
		FogColor = Lighting.FogColor,
		FogEnd = Lighting.FogEnd,
		ExposureCompensation = Lighting.ExposureCompensation,
		ColorShiftTop = Lighting.ColorShift_Top,
		ColorShiftBottom = Lighting.ColorShift_Bottom,
	}
end

local function restoreWorldColor()
	local effect = Lighting:FindFirstChild("ScriptMenuColorCorrection")

	if effect then
		effect:Destroy()
	end

	if not worldColorOriginal then
		return
	end

	Lighting.Ambient = worldColorOriginal.Ambient
	Lighting.OutdoorAmbient = worldColorOriginal.OutdoorAmbient
	Lighting.ClockTime = worldColorOriginal.ClockTime
	Lighting.Brightness = worldColorOriginal.Brightness
	Lighting.FogColor = worldColorOriginal.FogColor
	Lighting.FogEnd = worldColorOriginal.FogEnd
	Lighting.ExposureCompensation = worldColorOriginal.ExposureCompensation
	Lighting.ColorShift_Top = worldColorOriginal.ColorShiftTop
	Lighting.ColorShift_Bottom = worldColorOriginal.ColorShiftBottom

	worldColorOriginal = nil
end

local function applyWorldColor()
	local settings = Settings.WorldColor

	if not settings.Enabled then
		restoreWorldColor()
		return
	end

	captureWorldColor()

	local ambient = tableToColor(settings.Ambient, Color3.fromRGB(128, 128, 128))

	Lighting.Ambient = ambient
	Lighting.OutdoorAmbient = ambient
	Lighting.ClockTime = math.clamp(tonumber(settings.ClockTime) or 14, 0, 24)
	Lighting.Brightness = math.clamp(tonumber(settings.Brightness) or 2, 0, 10)
	Lighting.FogColor = tableToColor(settings.Fog, Color3.fromRGB(192, 192, 192))
	Lighting.FogEnd = math.max(tonumber(settings.FogEnd) or 5000, 1)
	Lighting.ExposureCompensation = math.clamp(tonumber(settings.Exposure) or 0, -5, 5)

	local effect = Lighting:FindFirstChild("ScriptMenuColorCorrection")

	if not effect then
		effect = Instance.new("ColorCorrectionEffect")
		effect.Name = "ScriptMenuColorCorrection"
		effect.Parent = Lighting
	end

	effect.TintColor = tableToColor(settings.Tint, Color3.new(1, 1, 1))
	effect.Saturation = math.clamp(tonumber(settings.Saturation) or 0, -1, 1)
end

local SKYBOX_PRESETS = {
	["Classic Blue"] = {
		SkyboxBk = "rbxassetid://135483466",
		SkyboxDn = "rbxassetid://135483484",
		SkyboxFt = "rbxassetid://135483461",
		SkyboxLf = "rbxassetid://135483495",
		SkyboxRt = "rbxassetid://135483499",
		SkyboxUp = "rbxassetid://135483475",
		StarCount = 0,
		CelestialBodiesShown = true,
	},
	Sunset = {
		SkyboxBk = "rbxassetid://323494035",
		SkyboxDn = "rbxassetid://323494368",
		SkyboxFt = "rbxassetid://323494130",
		SkyboxLf = "rbxassetid://323494252",
		SkyboxRt = "rbxassetid://323494067",
		SkyboxUp = "rbxassetid://323493360",
		StarCount = 0,
		CelestialBodiesShown = true,
	},
	["Red Night"] = {
		SkyboxBk = "rbxassetid://401664839",
		SkyboxDn = "rbxassetid://401664862",
		SkyboxFt = "rbxassetid://401664960",
		SkyboxLf = "rbxassetid://401664881",
		SkyboxRt = "rbxassetid://401664901",
		SkyboxUp = "rbxassetid://401664936",
		StarCount = 0,
		CelestialBodiesShown = true,
	},
	Galaxy = {
		SkyboxBk = "rbxassetid://159454299",
		SkyboxDn = "rbxassetid://159454296",
		SkyboxFt = "rbxassetid://159454293",
		SkyboxLf = "rbxassetid://159454286",
		SkyboxRt = "rbxassetid://159454300",
		SkyboxUp = "rbxassetid://159454288",
		StarCount = 3000,
		CelestialBodiesShown = true,
	},
	Vaporwave = {
		SkyboxBk = "rbxassetid://8631780182",
		SkyboxDn = "rbxassetid://8631784904",
		SkyboxFt = "rbxassetid://8631769834",
		SkyboxLf = "rbxassetid://8631777199",
		SkyboxRt = "rbxassetid://8631735555",
		SkyboxUp = "rbxassetid://8631782345",
		StarCount = 0,
		CelestialBodiesShown = false,
	},
	["Pink Morning"] = {
		SkyboxBk = "rbxassetid://12635309703",
		SkyboxDn = "rbxassetid://12635311686",
		SkyboxFt = "rbxassetid://12635312870",
		SkyboxLf = "rbxassetid://12635313718",
		SkyboxRt = "rbxassetid://12635315817",
		SkyboxUp = "rbxassetid://12635316856",
		StarCount = 0,
		CelestialBodiesShown = true,
	},
	["Deep Space"] = {
		SkyboxBk = "rbxassetid://159248188",
		SkyboxDn = "rbxassetid://159248183",
		SkyboxFt = "rbxassetid://159248187",
		SkyboxLf = "rbxassetid://159248173",
		SkyboxRt = "rbxassetid://159248192",
		SkyboxUp = "rbxassetid://159248176",
		StarCount = 0,
		CelestialBodiesShown = true,
	},
	Winter = {
		SkyboxBk = "rbxassetid://510645155",
		SkyboxDn = "rbxassetid://510645130",
		SkyboxFt = "rbxassetid://510645179",
		SkyboxLf = "rbxassetid://510645117",
		SkyboxRt = "rbxassetid://510645146",
		SkyboxUp = "rbxassetid://510645195",
		StarCount = 0,
		CelestialBodiesShown = true,
	},
	["Clouded Sky"] = {
		SkyboxBk = "rbxassetid://252760981",
		SkyboxDn = "rbxassetid://252763035",
		SkyboxFt = "rbxassetid://252761439",
		SkyboxLf = "rbxassetid://252760980",
		SkyboxRt = "rbxassetid://252760986",
		SkyboxUp = "rbxassetid://252762652",
		StarCount = 0,
		CelestialBodiesShown = false,
	},
	["Golden Warm"] = {
		SkyboxBk = "rbxassetid://162001887",
		SkyboxDn = "rbxassetid://161998893",
		SkyboxFt = "rbxassetid://162001897",
		SkyboxLf = "rbxassetid://162001904",
		SkyboxRt = "rbxassetid://162001919",
		SkyboxUp = "rbxassetid://162001926",
		StarCount = 0,
		CelestialBodiesShown = true,
	},
	["Starry Night"] = {
		SkyboxBk = "rbxassetid://15536110634",
		SkyboxDn = "rbxassetid://15536112543",
		SkyboxFt = "rbxassetid://15536116141",
		SkyboxLf = "rbxassetid://15536114370",
		SkyboxRt = "rbxassetid://15536118762",
		SkyboxUp = "rbxassetid://15536117282",
		SunTextureId = "rbxassetid://4547507884",
		MoonTextureId = "rbxassetid://6196665106",
		StarCount = 3000,
		CelestialBodiesShown = true,
	},
	Midnight = {
		SkyboxBk = "rbxassetid://6444884337",
		SkyboxDn = "rbxassetid://6444884785",
		SkyboxFt = "rbxassetid://6444884337",
		SkyboxLf = "rbxassetid://6444884337",
		SkyboxRt = "rbxassetid://6444884337",
		SkyboxUp = "rbxassetid://6412503613",
		StarCount = 3000,
		CelestialBodiesShown = true,
	},
}

local SKYBOX_OPTIONS = { "None", "Classic Blue", "Sunset", "Red Night", "Galaxy", "Vaporwave", "Pink Morning", "Deep Space", "Winter", "Clouded Sky", "Golden Warm", "Starry Night", "Midnight" }

local hiddenSkies = {}

local function hideExistingSkies()
	if #hiddenSkies > 0 then
		return
	end

	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Sky") and child.Name ~= "ScriptMenuSky" then
			table.insert(hiddenSkies, { instance = child, parent = child.Parent })
			child.Parent = nil
		end
	end
end

local function restoreExistingSkies()
	for _, entry in ipairs(hiddenSkies) do
		if entry.instance and entry.instance.Parent == nil then
			entry.instance.Parent = entry.parent or Lighting
		end
	end

	table.clear(hiddenSkies)
end

local function applySkybox()
	local existing = Lighting:FindFirstChild("ScriptMenuSky")

	if existing then
		existing:Destroy()
	end

	restoreExistingSkies()

	local settings = Settings.Skybox

	if not settings.Enabled then
		return
	end

	local preset = SKYBOX_PRESETS[settings.Preset]

	if not preset then
		return
	end

	hideExistingSkies()

	local sky = Instance.new("Sky")
	sky.Name = "ScriptMenuSky"

	for property, value in pairs(preset) do
		pcall(function()
			sky[property] = value
		end)
	end

	sky.Parent = Lighting
end

local WEATHER_PRESETS = {
	Rain = {
		Height = 45,
		Rate = 600,
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Lifetime = NumberRange.new(1.2, 1.8),
		Speed = NumberRange.new(70, 90),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.14),
			NumberSequenceKeypoint.new(1, 0.1),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(1, 0.35),
		}),
		Acceleration = Vector3.new(0, -40, 0),
		SpreadAngle = Vector2.new(0, 0),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Rotation = NumberRange.new(0, 0),
		RotSpeed = NumberRange.new(0, 0),
	},
	Snow = {
		Height = 50,
		Rate = 220,
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Lifetime = NumberRange.new(6, 9),
		Speed = NumberRange.new(6, 10),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(1, 0.25),
		}),
		Transparency = NumberSequence.new(0.15),
		Acceleration = Vector3.new(0, -1, 0),
		SpreadAngle = Vector2.new(15, 15),
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-40, 40),
	},
}

local weatherRig = {
	part = nil,
	emitter = nil,
	connection = nil,
	height = 45,
}

local function updateWeatherTransform()
	local part = weatherRig.part

	if not part then
		return
	end

	local camera = workspace.CurrentCamera

	if not camera then
		return
	end

	part.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, weatherRig.height, 0))
end

local function stopWeather()
	if weatherRig.connection then
		weatherRig.connection:Disconnect()
		weatherRig.connection = nil
	end

	if weatherRig.part then
		weatherRig.part:Destroy()
		weatherRig.part = nil
	end

	weatherRig.emitter = nil
end

local function applyWeather()
	local settings = Settings.Weather
	local spec = WEATHER_PRESETS[settings.Preset]

	if not settings.Enabled or not spec then
		stopWeather()
		return
	end

	if not weatherRig.part then
		local part = Instance.new("Part")
		part.Name = "ScriptMenuWeather"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Transparency = 1
		part.Size = Vector3.new(180, 1, 180)
		part.Parent = workspace

		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "Weather"
		emitter.EmissionDirection = Enum.NormalId.Bottom
		emitter.Shape = Enum.ParticleEmitterShape.Box
		emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		emitter.Parent = part

		weatherRig.part = part
		weatherRig.emitter = emitter
		weatherRig.connection = RunService.RenderStepped:Connect(updateWeatherTransform)
	end

	weatherRig.height = spec.Height

	local emitter = weatherRig.emitter

	emitter.Texture = spec.Texture
	emitter.Lifetime = spec.Lifetime
	emitter.Speed = spec.Speed
	emitter.Size = spec.Size
	emitter.Transparency = spec.Transparency
	emitter.Acceleration = spec.Acceleration
	emitter.SpreadAngle = spec.SpreadAngle
	emitter.Orientation = spec.Orientation
	emitter.Rotation = spec.Rotation
	emitter.RotSpeed = spec.RotSpeed
	emitter.Rate = spec.Rate * math.clamp(tonumber(settings.Intensity) or 1, 0, 3)
	emitter.Color = ColorSequence.new(tableToColor(settings.Color, Color3.new(1, 1, 1)))

	updateWeatherTransform()
end

for _, child in ipairs(workspace:GetChildren()) do
	if child.Name == "ScriptMenuWeather" then
		child:Destroy()
	end
end

applyWorldColor()
applySkybox()
applyWeather()

if Settings.AutoQueue.Enabled then
	applyAutoQueue()
end

local Window = Library:CreateWindow({
	Title = "Script Menu",
	Footer = "v1.0",
	Center = true,
	AutoShow = false,
	Resizable = true,
	NotifySide = "Right",
	ShowCustomCursor = true,
})

local Tabs = {
	Rage = Window:AddTab("Rage", "sword"),
	Character = Window:AddTab("Character", "user"),
	Visuals = Window:AddTab("Visuals", "eye"),
	Misc = Window:AddTab("Misc", "layers"),
	Settings = Window:AddTab("Settings", "settings"),
}

local StartupGroup = Tabs.Settings:AddLeftGroupbox("Startup", "play")

StartupGroup:AddToggle("SilentLoad", {
	Text = "Silent Load",
	Default = State.SilentLoad == true,
	Tooltip = "Hides the menu when the script loads. Press RightControl to open it.",
	Callback = function(value)
		State.SilentLoad = value
		saveState(State)
	end,
})

StartupGroup:AddToggle("ReRunAfterTeleport", {
	Text = "Re-run After Teleport",
	Default = State.ReRunAfterTeleport == true,
	Tooltip = "Queues the script to run itself again automatically after a teleport or server hop.",
	Callback = function(value)
		State.ReRunAfterTeleport = value
		saveState(State)

		if value and not QueueOnTeleport then
			Library:Notify("This executor does not support re-running after teleport.", 6)
		else
			applyRerun(value)
		end
	end,
})

local MiscTab = Tabs.Misc
local queueOptions = queueNames()
local queueDefault = Settings.AutoQueue.Queue

if not table.find(queueOptions, queueDefault) then
	queueDefault = queueOptions[1]
	Settings.AutoQueue.Queue = queueDefault
end

local AutoQueueGroup = MiscTab:AddLeftGroupbox("Auto Queue", "users")

AutoQueueGroup:AddToggle("AutoQueueEnabled", {
	Text = "Enabled",
	Default = Settings.AutoQueue.Enabled,
	Tooltip = "Automatically joins your selected queue whenever you are sitting in the lobby.",
	Callback = function(value)
		Settings.AutoQueue.Enabled = value
		saveState(State)
		applyAutoQueue()
	end,
})

AutoQueueGroup:AddDropdown("AutoQueueQueue", {
	Text = "Queue",
	Values = queueOptions,
	Default = queueDefault,
	Callback = function(value)
		Settings.AutoQueue.Queue = value
		saveState(State)
		applyAutoQueue()
	end,
})

local AutoLoadoutGroup = MiscTab:AddLeftGroupbox("Auto Loadout", "package")

AutoLoadoutGroup:AddToggle("AutoLoadoutEnabled", {
	Text = "Enabled",
	Default = Settings.AutoLoadout.Enabled,
	Tooltip = "Picks your saved loadout automatically at the weapon selection screen.",
	Callback = function(value)
		Settings.AutoLoadout.Enabled = value
		saveState(State)
	end,
})

for _, slot in ipairs(loadoutSlots) do
	local options = itemOptions(slot.Class)
	local current = Settings.AutoLoadout.Slots[slot.Name]

	if current == nil or not table.find(options, current) then
		current = "Unselected"
		Settings.AutoLoadout.Slots[slot.Name] = current
	end

	AutoLoadoutGroup:AddDropdown("AutoLoadout" .. slot.Name, {
		Text = slot.Name,
		Values = options,
		Default = current,
		Searchable = true,
		Callback = function(value)
			Settings.AutoLoadout.Slots[slot.Name] = value
			saveState(State)
		end,
	})
end

local AntiKatanaGroup = MiscTab:AddRightGroupbox("Anti Katana", "shield")

AntiKatanaGroup:AddToggle("AntiKatanaEnabled", {
	Text = "Enabled",
	Default = Settings.AntiKatana.Enabled,
	Tooltip = "Blocks your gun shots at enemies who are deflecting or front-blocking.",
	Callback = function(value)
		Settings.AntiKatana.Enabled = value
		saveState(State)
	end,
})

local TripminesGroup = MiscTab:AddRightGroupbox("Subspace Tripmines", "bomb")

TripminesGroup:AddToggle("TripmineAutoTrigger", {
	Text = "Auto Trigger",
	Default = Settings.SubspaceTripmines.AutoTrigger,
	Tooltip = "Detonates enemy subspace tripmines automatically.",
	Callback = function(value)
		Settings.SubspaceTripmines.AutoTrigger = value
		saveState(State)
	end,
})

TripminesGroup:AddToggle("TripmineTeamTrigger", {
	Text = "Team Trigger",
	Default = Settings.SubspaceTripmines.TeamTrigger,
	Tooltip = "Also detonates tripmines placed by your own team.",
	Callback = function(value)
		Settings.SubspaceTripmines.TeamTrigger = value
		saveState(State)
	end,
})

local VisualsTab = Tabs.Visuals

local WorldColorGroup = VisualsTab:AddLeftGroupbox("World Color", "palette")

WorldColorGroup:AddToggle("WorldColorEnabled", {
	Text = "Enabled",
	Default = Settings.WorldColor.Enabled,
	Tooltip = "Overrides ambient light, fog, time, and color grading to recolor the map, walls, and buildings.",
	Callback = function(value)
		Settings.WorldColor.Enabled = value
		saveState(State)
		applyWorldColor()
	end,
})

WorldColorGroup:AddLabel("Ambient"):AddColorPicker("WorldColorAmbient", {
	Title = "Ambient",
	Default = tableToColor(Settings.WorldColor.Ambient, Color3.fromRGB(128, 128, 128)),
	Callback = function(color)
		Settings.WorldColor.Ambient = colorToTable(color)
		saveState(State)
		applyWorldColor()
	end,
})

WorldColorGroup:AddLabel("Tint"):AddColorPicker("WorldColorTint", {
	Title = "Tint",
	Default = tableToColor(Settings.WorldColor.Tint, Color3.new(1, 1, 1)),
	Callback = function(color)
		Settings.WorldColor.Tint = colorToTable(color)
		saveState(State)
		applyWorldColor()
	end,
})

WorldColorGroup:AddLabel("Fog"):AddColorPicker("WorldColorFog", {
	Title = "Fog",
	Default = tableToColor(Settings.WorldColor.Fog, Color3.fromRGB(192, 192, 192)),
	Callback = function(color)
		Settings.WorldColor.Fog = colorToTable(color)
		saveState(State)
		applyWorldColor()
	end,
})

WorldColorGroup:AddSlider("WorldColorClockTime", {
	Text = "Clock Time",
	Min = 0,
	Max = 24,
	Rounding = 1,
	Default = Settings.WorldColor.ClockTime,
	Suffix = "h",
	Callback = function(value)
		Settings.WorldColor.ClockTime = value
		saveState(State)
		applyWorldColor()
	end,
})

WorldColorGroup:AddSlider("WorldColorBrightness", {
	Text = "Brightness",
	Min = 0,
	Max = 10,
	Rounding = 1,
	Default = Settings.WorldColor.Brightness,
	Callback = function(value)
		Settings.WorldColor.Brightness = value
		saveState(State)
		applyWorldColor()
	end,
})

WorldColorGroup:AddSlider("WorldColorFogEnd", {
	Text = "Fog End",
	Min = 0,
	Max = 10000,
	Rounding = 10,
	Default = Settings.WorldColor.FogEnd,
	Callback = function(value)
		Settings.WorldColor.FogEnd = value
		saveState(State)
		applyWorldColor()
	end,
})

WorldColorGroup:AddSlider("WorldColorExposure", {
	Text = "Exposure",
	Min = -5,
	Max = 5,
	Rounding = 1,
	Default = Settings.WorldColor.Exposure,
	Callback = function(value)
		Settings.WorldColor.Exposure = value
		saveState(State)
		applyWorldColor()
	end,
})

WorldColorGroup:AddSlider("WorldColorSaturation", {
	Text = "Saturation",
	Min = -1,
	Max = 1,
	Rounding = 0.05,
	Default = Settings.WorldColor.Saturation,
	Callback = function(value)
		Settings.WorldColor.Saturation = value
		saveState(State)
		applyWorldColor()
	end,
})

local WeatherGroup = VisualsTab:AddLeftGroupbox("Weather", "cloud-rain")

WeatherGroup:AddToggle("WeatherEnabled", {
	Text = "Enabled",
	Default = Settings.Weather.Enabled,
	Tooltip = "Spawns camera-following particles for your selected weather preset.",
	Callback = function(value)
		Settings.Weather.Enabled = value
		saveState(State)
		applyWeather()
	end,
})

WeatherGroup:AddDropdown("WeatherPreset", {
	Text = "Preset",
	Values = WEATHER_OPTIONS,
	Default = Settings.Weather.Preset,
	Callback = function(value)
		Settings.Weather.Preset = value
		saveState(State)
		applyWeather()
	end,
})

WeatherGroup:AddSlider("WeatherIntensity", {
	Text = "Intensity",
	Min = 0.2,
	Max = 3,
	Rounding = 0.1,
	Default = Settings.Weather.Intensity,
	Callback = function(value)
		Settings.Weather.Intensity = value
		saveState(State)
		applyWeather()
	end,
})

WeatherGroup:AddLabel("Color"):AddColorPicker("WeatherColor", {
	Title = "Color",
	Default = tableToColor(Settings.Weather.Color, Color3.new(1, 1, 1)),
	Callback = function(color)
		Settings.Weather.Color = colorToTable(color)
		saveState(State)
		applyWeather()
	end,
})

local SkyboxGroup = VisualsTab:AddRightGroupbox("Skybox", "cloud")

if not table.find(SKYBOX_OPTIONS, Settings.Skybox.Preset) then
	Settings.Skybox.Preset = SKYBOX_OPTIONS[1]
	State.Skybox.Preset = Settings.Skybox.Preset
end

SkyboxGroup:AddToggle("SkyboxEnabled", {
	Text = "Enabled",
	Default = Settings.Skybox.Enabled,
	Tooltip = "Replaces the map sky with your selected skybox preset.",
	Callback = function(value)
		Settings.Skybox.Enabled = value
		saveState(State)
		applySkybox()
	end,
})

SkyboxGroup:AddDropdown("SkyboxPreset", {
	Text = "Preset",
	Values = SKYBOX_OPTIONS,
	Default = Settings.Skybox.Preset,
	Callback = function(value)
		Settings.Skybox.Preset = value
		saveState(State)
		applySkybox()
	end,
})

if not loaded or not ready then
	local detail = loaded and reason or ready
	Library:Notify("Rivals was not fully loaded in time on: " .. tostring(detail), 6)
end

if Toggles.SilentLoad.Value ~= true then
	Library:Toggle(true)
end
