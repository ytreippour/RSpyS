--[[

	偷我的方法 💖💖💖💖
	我喜欢抄袭者和剽窃者，这让我感到恶心

]]

local Hook = {
	OriginalNamecall = nil,
	OriginalIndex = nil,
	PreviousFunctions = {},
	DefaultConfig = {
		FunctionPatches = true
	}
}

type table = {
	[any]: any
}

type MetaFunc = (Instance, ...any) -> ...any
type UnkFunc = (...any) -> ...any

--// 模块
local Modules
local Process
local Configuration
local Config
local Communication

local ExeENV = getfenv(1)

function Hook:Init(Data)
    Modules = Data.Modules

	Process = Modules.Process
	Communication = Modules.Communication or Communication
	Config = Modules.Config or Config
	Configuration = Modules.Configuration or Configuration
end

--// 回调函数有时会返回nil值，这种情况应该被忽略
local HookMiddle = newcclosure(function(OriginalFunc, Callback, AlwaysTable: boolean?, ...)
	--// 调用回调并检查响应，否则忽略
	local ReturnValues = Callback(...)
	if ReturnValues then
		--// 解包
		if not AlwaysTable then
			return Process:Unpack(ReturnValues)
		end

		--// 返回打包的响应
		return ReturnValues
	end

	--// 返回打包的响应
	if AlwaysTable then
		return {OriginalFunc(...)}
	end

	--// 解包
	return OriginalFunc(...)
end)

local function Merge(Base: table, New: table)
	for Key, Value in next, New do
		Base[Key] = Value
	end
end

function Hook:Index(Object: Instance, Key: string)
	return Object[Key]
end

function Hook:PushConfig(Overwrites)
    Merge(self, Overwrites)
end

--// getrawmetatable
function Hook:ReplaceMetaMethod(Object: Instance, Call: string, Callback: MetaFunc): MetaFunc
	local Metatable = getrawmetatable(Object)
	local OriginalFunc = clonefunction(Metatable[Call])
	
	--// 替换函数
	setreadonly(Metatable, false)
	Metatable[Call] = newcclosure(function(...)
		return HookMiddle(OriginalFunc, Callback, false, ...)
	end)
	setreadonly(Metatable, true)

	return OriginalFunc
end

--// hookfunction
function Hook:HookFunction(Func: UnkFunc, Callback: UnkFunc)
	local OriginalFunc
	local WrappedCallback = newcclosure(Callback)
	OriginalFunc = clonefunction(hookfunction(Func, function(...)
		return HookMiddle(OriginalFunc, WrappedCallback, false, ...)
	end))
	return OriginalFunc
end

--// hookmetamethod
function Hook:HookMetaCall(Object: Instance, Call: string, Callback: MetaFunc): MetaFunc
	local Metatable = getrawmetatable(Object)
	local Unhooked
	
	Unhooked = self:HookFunction(Metatable[Call], function(...)
		return HookMiddle(Unhooked, Callback, true, ...)
	end)
	return Unhooked
end

function Hook:HookMetaMethod(Object: Instance, Call: string, Callback: MetaFunc): MetaFunc
	local Func = newcclosure(Callback)
	
	--// Getrawmetatable
	if Config.ReplaceMetaCallFunc then
		return self:ReplaceMetaMethod(Object, Call, Func)
	end
	
	--// Hookmetamethod
	return self:HookMetaCall(Object, Call, Func)
end

--// 这包括一些针对执行器函数的补丁，这些函数会导致检测
--// 这不是万无一失的，因为像hookfunction这样的函数我无法修补
--// 顺便说一句，感谢你们复制这个！超级感谢模仿者
function Hook:PatchFunctions()
	--// 检查配置中是否禁用了此功能
	if Config.NoFunctionPatching then return end

	local Patches = {
		--// 错误检测补丁
		--// hookfunction可能仍会根据执行器被检测到
		-- [pcall] =  function(OldFunc, Func, ...)
		-- 	local Responce = {OldFunc(Func, ...)}
		-- 	local Success, Error = Responce[1], Responce[2]
		-- 	local IsC = iscclosure(Func)

		-- 	--// 修补c闭包错误检测
		-- 	if Success == false and IsC then
		-- 		local NewError = Process:CleanCError(Error)
		-- 		Responce[2] = NewError
		-- 	end

		-- 	--// 栈溢出检测补丁
		-- 	if Success == false and not IsC and Error:find("C stack overflow") then
		-- 		local Tracetable = Error:split(":")
		-- 		local Caller, Line = Tracetable[1], Tracetable[2]
		-- 		local Count = Process:CountMatches(Error, Caller)

		-- 		if Count == 196 then
		-- 			Communication:ConsolePrint(`C栈溢出已修补，计数为{Count}`)
		-- 			Responce[2] = Error:gsub(`{Caller}:{Line}: `, Caller, 1)
		-- 		end
		-- 	end

		-- 	return Responce
		-- end,
		[getfenv] = function(OldFunc, Level: number, ...)
			Level = Level or 1

			--// 防止捕获执行器的环境
			if type(Level) == "number" then
				Level += 2
			end

			local Responce = {OldFunc(Level, ...)}
			local ENV = Responce[1]

			--// __tostring环境检测补丁
			if not checkcaller() and ENV == ExeENV then
				Communication:ConsolePrint("环境逃逸已修补")
				return OldFunc(999999, ...)
			end

			return Responce
		end
	}

	--// 钩住每个函数
	for Func, CallBack in Patches do
		local Wrapped = newcclosure(CallBack)
		local OldFunc; OldFunc = self:HookFunction(Func, function(...)
			return Wrapped(OldFunc, ...)
		end)

		--// 缓存之前的函数
		self.PreviousFunctions[Func] = OldFunc
	end
end

function Hook:GetOriginalFunc(Func)
	return self.PreviousFunctions[Func] or Func
end

function Hook:RunOnActors(Code: string, ChannelId: number)
	if not getactors or not run_on_actor then return end
	
	local Actors = getactors()
	if not Actors then return end
	
	for _, Actor in Actors do 
		pcall(run_on_actor, Actor, Code, ChannelId)
	end
end

local function ProcessRemote(OriginalFunc, MetaMethod: string, self, Method: string, ...)
	return Process:ProcessRemote({
		Method = Method,
		OriginalFunc = OriginalFunc,
		MetaMethod = MetaMethod,
		TransferType = "发送",
		IsExploit = checkcaller()
	}, self, ...)
end

function Hook:HookRemoteTypeIndex(ClassName: string, FuncName: string)
	local Remote = Instance.new(ClassName)
	local Func = Remote[FuncName]
	local OriginalFunc

	--// 远程对象将共享相同的函数
	--// 	例如FireServer将是相同的
	--// 此外，这是用于__index调用。
	--// 	__namecall钩子不会检测到这个
	OriginalFunc = self:HookFunction(Func, function(self, ...)
		--// 检查对象是否被允许
		if not Process:RemoteAllowed(self, "发送", FuncName) then return end

		--// 处理远程数据
		return ProcessRemote(OriginalFunc, "__index", self, FuncName, ...)
	end)
end

function Hook:HookRemoteIndexes()
	local RemoteClassData = Process.RemoteClassData
	for ClassName, Data in RemoteClassData do
		local FuncName = Data.Send[1]
		self:HookRemoteTypeIndex(ClassName, FuncName)
	end
end

function Hook:BeginHooks()
	--// 钩住远程函数
	self:HookRemoteIndexes()

	--// Namecall钩子
	local OriginalNameCall
	OriginalNameCall = self:HookMetaMethod(game, "__namecall", function(self, ...)
		local Method = getnamecallmethod()
		return ProcessRemote(OriginalNameCall, "__namecall", self, Method, ...)
	end)

	Merge(self, {
		OriginalNamecall = OriginalNameCall,
		--OriginalIndex = Oi
	})
end

function Hook:HookClientInvoke(Remote, Method, Callback)
	local Success, Function = pcall(function()
		return getcallbackvalue(Remote, Method)
	end)

	--// 像Potassium这样的执行器如果回调值为nil会抛出错误
	if not Success then return end
	if not Function then return end
	
	--// 测试hookfunction
	local HookSuccess = pcall(function()
		self:HookFunction(Function, Callback)
	end)
	if HookSuccess then return end

	--// 否则替换回调函数
	Remote[Method] = function(...)
		return HookMiddle(Function, Callback, false, ...)
	end
end

function Hook:MultiConnect(Remotes)
	for _, Remote in next, Remotes do
		self:ConnectClientRecive(Remote)
	end
end

function Hook:ConnectClientRecive(Remote)
	--// 检查远程类是否被允许接收
	local Allowed = Process:RemoteAllowed(Remote, "接收")
	if not Allowed then return end

	--// 检查对象是否有远程类数据
    local ClassData = Process:GetClassData(Remote)
    local IsRemoteFunction = ClassData.IsRemoteFunction
	local NoReciveHook = ClassData.NoReciveHook
    local Method = ClassData.Receive[1]

	--// 检查是否应该钩住接收
	if NoReciveHook then return end

	--// 新的回调函数
	local function Callback(...)
        return Process:ProcessRemote({
            Method = Method,
            IsReceive = true,
            MetaMethod = "连接",
			IsExploit = checkcaller()
        }, Remote, ...)
	end

	--// 连接远程
	if not IsRemoteFunction then
   		Remote[Method]:Connect(Callback)
	else -- 远程函数
		self:HookClientInvoke(Remote, Method, Callback)
	end
end

function Hook:BeginService(Libraries, ExtraData, ChannelId, ...)
	--// 库
	local ReturnSpoofs = Libraries.ReturnSpoofs
	local ProcessLib = Libraries.Process
	local Communication = Libraries.Communication
	local Config = Libraries.Config

	--// 检查配置覆盖
	ProcessLib:CheckConfig(Config)

	--// 初始化数据
	local InitData = {
		Modules = {
			ReturnSpoofs = ReturnSpoofs,
			Communication = Communication,
			Process = ProcessLib,
			Config = Config,
			Hook = self
		},
		Services = setmetatable({}, {
			__index = function(self, Name: string): Instance
				local Service = game:GetService(Name)
				return cloneref(Service)
			end,
		})
	}

	--// 初始化库
	Communication:Init(InitData)
	ProcessLib:Init(InitData)

	--// 通信配置
	local Channel, IsWrapped = Communication:GetCommChannel(ChannelId)
	Communication:SetChannel(Channel)
	Communication:AddTypeCallbacks({
		["RemoteData"] = function(Id: string, RemoteData)
			ProcessLib:SetRemoteData(Id, RemoteData)
		end,
		["AllRemoteData"] = function(Key: string, Value)
			ProcessLib:SetAllRemoteData(Key, Value)
		end,
		["UpdateSpoofs"] = function(Content: string)
			local Spoofs = loadstring(Content)()
			ProcessLib:SetNewReturnSpoofs(Spoofs)
		end,
		["BeginHooks"] = function(Config)
			if Config.PatchFunctions then
				self:PatchFunctions()
			end
			self:BeginHooks()
			Communication:ConsolePrint("钩子已加载")
		end
	})
	
	--// 进程配置
	ProcessLib:SetChannel(Channel, IsWrapped)
	ProcessLib:SetExtraData(ExtraData)

	--// 钩子配置
	self:Init(InitData)

	if ExtraData and ExtraData.IsActor then
		Communication:ConsolePrint("Actor已连接!")
	end
end

function Hook:LoadMetaHooks(ActorCode: string, ChannelId: number)
	--// 钩住Actor
	if not Configuration.NoActors then
		self:RunOnActors(ActorCode, ChannelId)
	end

	--// 钩住当前线程
	self:BeginService(Modules, nil, ChannelId) 
end

function Hook:LoadReceiveHooks()
	local NoReceiveHooking = Config.NoReceiveHooking
	local BlackListedServices = Config.BlackListedServices

	if NoReceiveHooking then return end

	--// 远程对象添加
	game.DescendantAdded:Connect(function(Remote) -- TODO
		self:ConnectClientRecive(Remote)
	end)

	--// 收集父级为nil的远程对象
	self:MultiConnect(getnilinstances())

	--// 搜索远程对象
	for _, Service in next, game:GetChildren() do
		if table.find(BlackListedServices, Service.ClassName) then continue end
		self:MultiConnect(Service:GetDescendants())
	end
end

function Hook:LoadHooks(ActorCode: string, ChannelId: number)
	self:LoadMetaHooks(ActorCode, ChannelId)
	self:LoadReceiveHooks()
end

return Hook
