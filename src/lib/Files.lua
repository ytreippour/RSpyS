type table = {
	[any]: any
}

--// 模块
local Files = {
	UseWorkspace = false,
	Folder = "Sigma spy",
	RepoUrl = nil,
	FolderStructure = {
		["Sigma Spy"] = {
			"assets",
		}
	}
}

--// 服务
local HttpService: HttpService

function Files:Init(Data)
	local FolderStructure = self.FolderStructure
    local Services = Data.Services

    HttpService = Services.HttpService

	--// 检查是否需要创建文件夹
	self:CheckFolders(FolderStructure)
end

function Files:PushConfig(Config: table)
	for Key, Value in next, Config do
		self[Key] = Value
	end
end

function Files:UrlFetch(Url: string): string
	--// 请求数据
    local Final = {
        Url = Url:gsub(" ", "%%20"), 
        Method = 'GET'
    }

	 --// 发送 HTTP 请求
    local Success, Responce = pcall(request, Final)

    --// 错误检查
    if not Success then 
        warn("[!] HTTP 请求错误！请检查控制台 (F9)")
        warn("> 网址:", Url)
        error(Responce)
        return ""
    end

    local Body = Responce.Body
    local StatusCode = Responce.StatusCode

	--// 状态码检查
    if StatusCode == 404 then
        warn("[!] 请求的文件已被移动或删除。")
        warn(" >", Url)
        return ""
    end

    return Body, Responce
end

function Files:MakePath(Path: string)
	local Folder = self.Folder
	return `{Folder}/{Path}`
end

function Files:LoadCustomasset(Path: string): string?
	if not getcustomasset then return end
	if not Path then return end

	--// 检查内容
	local Content = readfile(Path)
	if #Content <= 0 then return end

	--// 加载自定义资源ID
	local Success, AssetId = pcall(getcustomasset, Path)
	
	if not Success then return end
	if not AssetId or #AssetId <= 0 then return end

	return AssetId
end

function Files:GetFile(Path: string, CustomAsset: boolean?): string?
	local RepoUrl = self.RepoUrl
	local UseWorkspace = self.UseWorkspace

	local LocalPath = self:MakePath(Path)
	local Content = ""

	--// 检查是否应从工作区获取文件
	if UseWorkspace then
		Content = readfile(LocalPath)
	else
		--// 通过 HTTP 请求下载
		Content = self:UrlFetch(`{RepoUrl}/{Path}`)
	end

	--// 自定义资源
	if CustomAsset then
		--// 检查是否应将文件写入
		self:FileCheck(LocalPath, function()
			return Content
		end)

		return self:LoadCustomasset(LocalPath)
	end

	return Content
end

function Files:GetTemplate(Name: string): string
    return self:GetFile(`templates/{Name}.lua`)
end

function Files:FileCheck(Path: string, Callback)
	if isfile(Path) then return end

	--// 创建模板并写入缺失的文件
	local Template = Callback()
	writefile(Path, Template)
end

function Files:FolderCheck(Path: string)
	if isfolder(Path) then return end
	makefolder(Path)
end

function Files:CheckPath(Parent: string, Child: string)
	return Parent and `{Parent}/{Child}` or Child
end

function Files:CheckFolders(Structure: table, Path: string?)
	for ParentName, Name in next, Structure do
		--// 检查父文件夹是否存在
		if typeof(Name) == "table" then
			local NewPath = self:CheckPath(Path, ParentName)
			self:FolderCheck(NewPath)
			self:CheckFolders(Name, NewPath)
			continue
		end

		--// 检查子文件夹是否存在
		local FolderPath = self:CheckPath(Path, Name)
		self:FolderCheck(FolderPath)
	end
end

function Files:TemplateCheck(Path: string, TemplateName: string)
	self:FileCheck(Path, function()
		return self:GetTemplate(TemplateName)
	end)
end

function Files:GetAsset(Name: string, CustomAsset: boolean?): string
    return self:GetFile(`assets/{Name}`, CustomAsset)
end

function Files:GetModule(Name: string, TemplateName: string): string
	local Path = `{Name}.lua`

	--// 如果提供了模板参数，文件将被声明为本地
	if TemplateName then
		self:TemplateCheck(Path, TemplateName)

		--// 检查是否成功加载
		local Content = readfile(Path)
		local Success = loadstring(Content)
		if Success then return Content end

		return self:GetTemplate(TemplateName)
	end

	return self:GetFile(Path)
end

function Files:LoadLibraries(Scripts: table, ...): table
	local Modules = {}
	for Name, Content in next, Scripts do
		--// Base64 格式
		local IsBase64 = typeof(Content) == "table" and Content[1] == "base64"
		Content = IsBase64 and Content[2] or Content

		--// 表格
		if typeof(Content) ~= "string" and not IsBase64 then 
			Modules[Name] = Content
			continue 
		end

		--// 解码 Base64
		if IsBase64 then
			Content = crypt.base64decode(Content)
			Scripts[Name] = Content
		end

		--// 编译库
		local Closure, Error = loadstring(Content, Name)
		assert(Closure, `加载 {Name} 失败: {Error}`)

		Modules[Name] = Closure(...)
	end
	return Modules
end

function Files:LoadModules(Modules: {}, Data: {})
    for Name, Module in next, Modules do
        local Init = Module.Init
        if not Init then continue end

		--// 调用 :Init 函数
        Module:Init(Data)
    end
end

function Files:CreateFont(Name: string, AssetId: string): string?
	if not AssetId then return end

	--// 自定义字体 Json
	local FileName = `assets/{Name}.json`
	local JsonPath = self:MakePath(FileName)
	local Data = {
		name = Name,
		faces = {
			{
				name = "Regular",
				weight = 400,
				style = "Normal",
				assetId = AssetId
			}
		}
	}

	--// 写入 Json
	local Json = HttpService:JSONEncode(Data)
	writefile(JsonPath, Json)

	return JsonPath
end

function Files:CompileModule(Scripts): string
    local Out = "local Libraries = {"
    for Name, Content in Scripts do
		if typeof(Content) ~= "string" then continue end
        Out ..= `	{Name} = (function()\n{Content}\nend)(),\n`
    end
	Out ..= "}"
    return Out
end

function Files:MakeActorScript(Scripts, ChannelId: number): string
	local ActorCode = Files:CompileModule(Scripts)
	ActorCode ..= [[
	local ExtraData = {
		IsActor = true
	}
	]]
	ActorCode ..= `Libraries.Hook:BeginService(Libraries, ExtraData, {ChannelId})`
	return ActorCode
end

return Files