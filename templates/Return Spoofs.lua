--// Sigma Spy 自定义远程响应
--// Return *表格* 将被解包作为响应
--// 如果返回欺骗是一个函数，传递的参数也将传递给该函数

return {
	-- [game.ReplicatedStorage.Remotes.HelloWorld] = {
	-- 	Method = "FireServer",
	-- 	Return = {"Hello world from Sigma Spy!"}
	-- }
	-- [game.ReplicatedStorage.Remotes.some idiotIsCool] = {
	-- 	Method = "FireServer",
	-- 	Return = function(OriginalFunc, ...)
	--		return {"some idiot", "is awesome!"}
	-- end
	-- }
}