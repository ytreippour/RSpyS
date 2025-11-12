type table = {
	[any]: any
}

type RemoteData = {
	Remote: Instance,
	IsReceive: boolean?,
	MetaMethod: string,
	Args: table,
	Method: string,
    TransferType: string,
	ValueReplacements: table,
	NoVariables: boolean?
}

--// 模块
local Sizeof = require("@lib/Sizeof")

--// 模块
local Generation = {
	DumpBaseName = "SigmaSpy-Dump %s.lua", -- "-- 使用 sigma spy 生成 BOIIIIIIIII (+9999999 AURA)\n"
	ScriptTemplates = {
		["Remote"] = {
			{"%RemoteCall%"}
		},
		["Spam"] = {
			{"while wait() do"},
			{"%RemoteCall%", 2},
			{"end"}
		},
		["Repeat"] = {
			{"for Index = 1, 10 do"},
			{"%RemoteCall%", 2},
			{"end"}
		},
		["Block"] = {
			["__index"] = {
				{"local Old; Old = hookfunction(%Signal%, function(self, ...)"},
				{"if self == %Remote% then", 2},
				{"return", 3},
				{"end", 2},
				{"return Old(self, ...)", 2},
				{"end)"}
			},
			["__namecall"] = {
				{"local Old; Old = hookmetamethod(game, \"__namecall\", function(self, ...)"},
				{"local Method = getnamecallmethod()", 2},
				{"if self == %Remote% and Method == \"%Method%\" then", 2},
				{"return", 3},
				{"end", 2},
				{"return Old(self, ...)", 2},
				{"end)"}
			},
			["Connect"] = {
				{"for _, Connection in getconnections(%Signal%) do"},
				{"Connection:Disable()", 2},
				{"end"}
			}
		}
	}
}

--// 模块
local Config
local Hook
local ParserModule
local Flags
local ThisScript = script

local function Merge(Base: table, New: table?)
	if not New then return end
	for Key, Value in next, New do
		Base[Key] = Value
	end
end

function Generation:Init(Data: table)
    local Modules = Data.Modules
	local Configuration = Modules.Configuration

	--// 模块
	Config = Modules.Config
	Hook = Modules.Hook
	Flags = Modules.Flags
	
	--// 导入解析器
	local ParserUrl = Configuration.ParserUrl
	self:LoadParser(ParserUrl)
end

function Generation:MakePrintable(String: string): string
	local Formatter = ParserModule.Modules.Formatter
	return Formatter:MakePrintable(String)
end

function Generation:TimeStampFile(FilePath: string): string
	local TimeStamp = os.date("%Y-%m-%d_%H-%M-%S")
	local Formatted = FilePath:format(TimeStamp)
	return Formatted
end

function Generation:WriteDump(Content: string): string
	local DumpBaseName = self.DumpBaseName
	local FilePath = self:TimeStampFile(DumpBaseName)

	--// 写入文件
	writefile(FilePath, Content)

	return FilePath
end

function Generation:LoadParser(ModuleUrl: string)
	ParserModule = loadstring(game:HttpGet(ModuleUrl), "解析器")()
end

function Generation:MakeValueSwapsTable(): table
	local Formatter = ParserModule.Modules.Formatter
	return Formatter:MakeReplacements()
end

function Generation:SetSwapsCallback(Callback: (Interface: table) -> ())
	self.SwapsCallback = Callback
end

function Generation:GetBase(Module): (string, boolean)
	--local NoComments = Flags:GetFlagValue("NoComments")

	--// 生成变量代码
	local Variables = Module.Parser:MakeVariableCode({
		"Services", "Remote", "Variables"
	}, true)

	local NoVariables = Variables == ""
	return Variables, NoVariables
end

function Generation:GetSwaps()
	local Func = self.SwapsCallback
	local Swaps = {}

	local Interface = {}
	function Interface:AddSwap(Object: Instance, Data: table)
		if not Object then return end
		Swaps[Object] = Data
	end

	--// 调用 GetSwaps 函数
	Func(Interface)

	return Swaps
end

function Generation:PickVariableName(): string
	local Names = Config.VariableNames
	return Names[math.random(1, #Names)]
end

function Generation:NewParser(Extra: table?)
	local VariableName = self:PickVariableName()
	local Swaps = self:GetSwaps()

	local Configuration = {
		VariableBase = VariableName,
		Swaps = Swaps,
		IndexFunc = function(...)
			return Hook:Index(...)
		end,
	}

	--// 合并额外配置
	Merge(Configuration, Extra)

	--// 创建新的解析器实例
	return ParserModule:New(Configuration)
end

function Generation:Indent(IndentString: string, Line: string)
	return `{IndentString}{Line}`
end

type CallInfo = {
	Arguments: table,
	Indent: number,
	RemoteVariable: string,
	Module: table
}
function Generation:CallRemoteScript(Data, Info: CallInfo): string
	local IsReceive = Data.IsReceive
	local Method = Data.Method
	local Args = Data.Args

	local RemoteVariable = Info.RemoteVariable
	local Indent = Info.Indent or 0
	local Module = Info.Module

	local Variables = Module.Variables
	local Parser = Module.Parser
	local NoVariables = Data.NoVariables

	local IndentString = self:MakeIndent(Indent)

	--// 解析参数
	local ParsedArgs, ItemsCount, IsArray = Parser:ParseTableIntoString({
		NoBrackets = true,
		NoVariables = NoVariables,
		Table = Args,
		Indent = Indent
	})

	--// 如果不是数组则创建表格变量
	if not IsArray or NoVariables then
		ParsedArgs = Variables:MakeVariable({
			Value = ("{%s}"):format(ParsedArgs),
			Comment = not IsArray and "参数未排序" or nil,
			Name = "RemoteArgs",
			Class = "Remote"
		})
	end

	--// 如果表格是字典，则用unpack包装
	if ItemsCount > 0 and not IsArray then
		ParsedArgs = `unpack({ParsedArgs}, 1, table.maxn({ParsedArgs}))`
	end

	--// 客户端接收的触发信号脚本
	if IsReceive then
		local Second = ItemsCount <= 0 and "" or `, {ParsedArgs}`
		local Signal = `{RemoteVariable}.{Method}`

		local Code = `-- 此数据是从服务器接收的`
		ParsedArgs = self:Indent(IndentString, Code)
		Code ..= `\n{IndentString}firesignal({Signal}{Second})`
		
		return Code
	end
	
	--// 远程调用脚本
	return `{RemoteVariable}:{Method}({ParsedArgs})`
end

--// 变量: %VariableName%
function Generation:ApplyVariables(String: string, Variables: table, ...): string
	for Variable, Value in Variables do
		--// 调用值函数
		if typeof(Value) == "function" then
			Value = Value(...)
		end

		String = String:gsub(`%%{Variable}%%`, function()
			return Value
		end)
	end
	return String
end

function Generation:MakeIndent(Indent: number)
	return string.rep("	", Indent)
end

type ScriptData = {
	Variables: table,
	MetaMethod: string
}
function Generation:MakeCallCode(ScriptType: string, Data: ScriptData): string
	local ScriptTemplates = self.ScriptTemplates
	local Template = ScriptTemplates[ScriptType]

	assert(Template, `{ScriptType} 不是有效的脚本类型!`)

	local Variables = Data.Variables
	local MetaMethod = Data.MetaMethod
	local MetaMethods = {"__index", "__namecall", "Connect"}

	local function Compile(Template: table): string
		local Out = ""

		for Key, Value in next, Template do
			--// 元方法检查
			local IsMetaTypeOnly = table.find(MetaMethods, Key)
			if IsMetaTypeOnly then
				if Key == MetaMethod then
					local Line = Compile(Value)
					Out ..= Line
				end
				continue
			end

			--// 信息
			local Content, Indent = Value[1], Value[2] or 0
			Indent = math.clamp(Indent-1, 0, 9999)

			--// 创建行
			local Line = self:ApplyVariables(Content, Variables, Indent)
			local IndentString = self:MakeIndent(Indent)

			--// 附加到代码
			Out ..= `{IndentString}{Line}\n`
		end

		return Out
	end
	
	return Compile(Template)
end

function Generation:RemoteScript(Module, Data: RemoteData, ScriptType: string): string
	--// 解包数据
	local Remote = Data.Remote
	local Args = Data.Args
	local Method = Data.Method
	local MetaMethod = Data.MetaMethod

	--// 标志
	local NoComments = Flags:GetFlagValue("NoComments")

	--// 远程信息
	local ClassName = Hook:Index(Remote, "ClassName")
	local IsNilParent = Hook:Index(Remote, "Parent") == nil
	
	local Variables = Module.Variables
	local Formatter = Module.Formatter
	
	--// 预渲染变量
	Variables:PrerenderVariables(Args, {"Instance"})

	--// 创建远程变量
	local RemoteVariable = Variables:MakeVariable({
		Value = Formatter:Format(Remote, {
			NoVariables = true
		}),
		Comment = `{ClassName} {IsNilParent and "| 远程父级为空" or ""}`,
		Name = Formatter:MakeName(Remote),
		Lookup = Remote,
		Class = "Remote"
	})

	--// 生成调用脚本
	local CallCode = self:MakeCallCode(ScriptType, {
		Variables = {
			["RemoteCall"] = function(Indent: number)
				return self:CallRemoteScript(Data, {
					RemoteVariable = RemoteVariable,
					Indent = Indent,
					Module = Module
				})
			end,
			["Remote"] = RemoteVariable,
			["Method"] = Method,
			["Signal"] = `{RemoteVariable}.{Method}`
		},
		MetaMethod = MetaMethod
	})

	--// 创建代码
	local Code = ""
	if not NoComments then 
		local Success, Bytes = pcall(Sizeof, Args)
		local Count = Success and `{Bytes} 字节` or "失败!"
		Code ..= `-- 远程数据包大小(~): {Count}\n\n`
	end
	
	--// 编译基础
	Code ..= self:GetBase(Module)

	return `{Code}\n{CallCode}`
end

function Generation:ConnectionsTable(Signal: RBXScriptSignal): table
	local Connections = getconnections(Signal)
	local DataArray = {}

	for _, Connection in next, Connections do
		local Function = Connection.Function
		local Script = rawget(getfenv(Function), "script")

		--// 跳过自身
		if Script == ThisScript then continue end

		--// 连接数据
		local Data = {
			Function = Function,
			State = Connection.State,
			Script = Script
		}

		table.insert(DataArray, Data)
	end

	return DataArray
end

function Generation:TableScript(Module, Table: table): string
	--// 预渲染变量
	Module.Variables:PrerenderVariables(Table, {"Instance"})

	--// 解析参数
	local ParsedTable = Module.Parser:ParseTableIntoString({
		Table = Table
	})

	--// 生成脚本
	local Code, NoVariables = self:GetBase(Module)
	local Seperator = NoVariables and "" or "\n"
	Code ..= `{Seperator}return {ParsedTable}`

	return Code
end

function Generation:MakeTypesTable(Table: table): table
	local Types = {}

	for Key, Value in next, Table do
		local Type = typeof(Value)
		if Type == "table" then
			Type = self:MakeTypesTable(Value)
		end

		Types[Key] = Type
	end

	return Types
end

function Generation:ConnectionInfo(Remote: Instance, ClassData: table): table?
	local ReceiveMethods = ClassData.Receive
	if not ReceiveMethods then return end

	local Connections = {}
	for _, Method: string in next, ReceiveMethods do
		pcall(function() -- TODO: GETCALLBACKVALUE
			local Signal = Hook:Index(Remote, Method)
			Connections[Method] = self:ConnectionsTable(Signal)
		end)
	end

	return Connections
end

function Generation:AdvancedInfo(Module, Data: table): string
	--// 解包远程数据
	local Function = Data.CallingFunction
	local ClassData = Data.ClassData
	local Remote = Data.Remote
	local Args = Data.Args
	
	--// 高级信息表格基础
	local FunctionInfo = {
		["调用者"] = {
			["源脚本"] = Data.SourceScript,
			["调用脚本"] = Data.CallingScript,
			["调用函数"] = Function
		},
		["远程"] = {
			["远程对象"] = Remote,
			["远程ID"] = Data.Id,
			["方法"] = Data.Method,
			["连接"] = self:ConnectionInfo(Remote, ClassData)
		},
		["参数"] = {
			["长度"] = #Args,
			["类型"] = self:MakeTypesTable(Args),
		},
		["元方法"] = Data.MetaMethod,
		["是否为Actor"] = Data.IsActor,
	}

	--// 某些闭包可能不是Lua
	if Function and islclosure(Function) then
		FunctionInfo["上值"] = debug.getupvalues(Function)
		FunctionInfo["常量"] = debug.getconstants(Function)
	end

	--// 生成脚本
	return self:TableScript(Module, FunctionInfo)
end

function Generation:DumpLogs(Logs: table): string
	local BaseData
	local Parsed = {
		Remote = nil,
		Calls = {}
	}

	--// 创建新的解析器实例
	local Module = Generation:NewParser()

	for _, Data in Logs do
		local Calls = Parsed.Calls
		local Table = {
			Args = Data.Args,
			Timestamp = Data.Timestamp,
			ReturnValues = Data.ReturnValues,
			Method = Data.Method,
			MetaMethod = Data.MetaMethod,
			CallingScript = Data.CallingScript,
		}

		--// 附加
		table.insert(Calls, Table)

		--// 设置基础数据
		if not BaseData then
			BaseData = Data
		end
	end

	--// 合并基础数据
	Parsed.Remote = BaseData.Remote

	--// 编译并保存
	local Output = self:TableScript(Module, Parsed)
	local FilePath = self:WriteDump(Output)
	
	return FilePath
end

return Generation