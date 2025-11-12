--// 基础配置
local Configuration = {
	UseWorkspace = false, 
	NoActors = false,
	FolderName = "Sigma Spy",
	RepoUrl = "https://raw.githubusercontent.com/depthso/Sigma-Spy/refs/heads/main",
	ParserUrl = "https://raw.githubusercontent.com/depthso/Roblox-parser/refs/heads/main/dist/Main.luau"
}

--// 加载覆盖配置
local Parameters = {...}
local Overwrites = Parameters[1]
if typeof(Overwrites) == "table" then
	for Key, Value in Overwrites do
		Configuration[Key] = Value
	end
end

--// 服务处理器
local Services = setmetatable({}, {
	__index = function(self, Name: string): Instance
		local Service = game:GetService(Name)
		return cloneref(Service)
	end,
})

--// 文件模块
local Files = (function()
	--INSERT: @lib/Files.lua
end)()
Files:PushConfig(Configuration)
Files:Init({
	Services = Services
})

local Folder = Files.FolderName
local Scripts = {
	--// 用户配置
	Config = Files:GetModule(`{Folder}/Config`, "Config"),
	ReturnSpoofs = Files:GetModule(`{Folder}/Return spoofs`, "返回值欺骗"),
	Configuration = Configuration,
	Files = Files,

	--// 库
	Process = {"base64", "COMPILE: @lib/Process.lua"},
	Hook = {"base64", "COMPILE: @lib/Hook.lua"},
	Flags = {"base64", "COMPILE: @lib/Flags.lua"},
	Ui = {"base64", "COMPILE: @lib/Ui.lua"},
	Generation = {"base64", "COMPILE: @lib/Generation.lua"},
	Communication = {"base64", "COMPILE: @lib/Communication.lua"}
}

--// 服务
local Players: Players = Services.Players

--// 依赖项
local Modules = Files:LoadLibraries(Scripts)
local Process = Modules.Process
local Hook = Modules.Hook
local Ui = Modules.Ui
local Generation = Modules.Generation
local Communication = Modules.Communication
local Config = Modules.Config

--// 使用自定义字体（可选）
local FontContent = Files:GetAsset("ProggyClean.ttf", true)
local FontJsonFile = Files:CreateFont("ProggyClean", FontContent)
Ui:SetFontFile(FontJsonFile)

--// 加载模块
Process:CheckConfig(Config)
Files:LoadModules(Modules, {
	Modules = Modules,
	Services = Services
})

--// ReGui 创建窗口
local Window = Ui:CreateMainWindow()

--// 检查 Sigma 间谍工具是否受支持
local Supported = Process:CheckIsSupported()
if not Supported then 
	Window:Close()
	return
end

--// 创建通信通道
local ChannelId, Event = Communication:CreateChannel()
Communication:AddCommCallback("QueueLog", function(...)
	Ui:QueueLog(...)
end)
Communication:AddCommCallback("Print", function(...)
	Ui:ConsoleLog(...)
end)

--// 生成替换
local LocalPlayer = Players.LocalPlayer
Generation:SetSwapsCallback(function(self)
	self:AddSwap(LocalPlayer, {
		String = "LocalPlayer",
	})
	self:AddSwap(LocalPlayer.Character, {
		String = "Character",
		NextParent = LocalPlayer
	})
end)

--// 创建窗口内容
Ui:CreateWindowContent(Window)

--// 开始日志队列服务
Ui:SetCommChannel(Event)
Ui:BeginLogService()

--// 加载钩子
local ActorCode = Files:MakeActorScript(Scripts, ChannelId)
Hook:LoadHooks(ActorCode, ChannelId)

local EnablePatches = Ui:AskUser({
	Title = "启用函数补丁？",
	Content = {
		"在某些执行器上，函数补丁可以防止执行器常见的检测",
		"启用此功能可能会在某些游戏中触发钩子检测，因此需要询问您。",
		"如果不起作用，请重新加入并选择'否'",
		"",
		"（这不会影响游戏功能）"
	},
	Options = {"是", "否"}
}) == "是"

--// 开始钩子
Event:Fire("BeginHooks", {
	PatchFunctions = EnablePatches
})
