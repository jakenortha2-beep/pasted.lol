local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Toggles = Library.Toggles

local SCRIPT_URL = "https://raw.githubusercontent.com/jakenortha2-beep/pasted.lol/refs/heads/main/main.lua"

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
	local direct = queue_on_teleport

	if typeof(direct) == "function" then
		return direct
	end

	local fn

	local names = { "queue_on_teleport", "queueonteleport" }

	for _, name in ipairs(names) do
		pcall(function()
			fn = getgenv()[name]
		end)

		if typeof(fn) == "function" then
			return fn
		end
	end

	local hubs = { syn, fluxus, securecall, Krnl }

	for _, hub in ipairs(hubs) do
		if hub then
			pcall(function()
				fn = hub.queue_on_teleport
			end)

			if typeof(fn) == "function" then
				return fn
			end
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

	local hitboxDeadline = math.min(deadline, os.clock() + 3)

	if not findChild(character, "HitboxHead", hitboxDeadline) then
		warn("[Script] Character combat hitboxes are still loading.")
	end

	return true
end

local QueueOnTeleport = resolveQueueOnTeleport()

local RERUN_CODE = string.format(
	"local ok, err = pcall(function() loadstring(game:HttpGet(%q))() end) if not ok then warn('[Rerun] ' .. tostring(err)) end",
	SCRIPT_URL
)

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

local readyOk, readyResult, readyReason = pcall(awaitRivals)
local ready = readyOk and readyResult == true

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

if not ready then
	local detail = readyOk and readyReason or readyResult
	Library:Notify("Rivals was not fully loaded in time on: " .. tostring(detail), 6)
	warn("[Script] Rivals readiness check failed on: " .. tostring(detail))
else
	print("[Script] Rivals modules, controllers and remotes are fully loaded.")
end

if Toggles.SilentLoad.Value ~= true then
	Library:Toggle(true)
end
