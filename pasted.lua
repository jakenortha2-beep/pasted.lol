local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

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
}

for name, value in pairs(Settings) do
	State[name] = value
end

if type(Settings.AutoLoadout.Slots) ~= "table" then
	Settings.AutoLoadout.Slots = {}
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

if not loaded or not ready then
	local detail = loaded and reason or ready
	Library:Notify("Rivals was not fully loaded in time on: " .. tostring(detail), 6)
end

if Toggles.SilentLoad.Value ~= true then
	Library:Toggle(true)
end
