----------------------------------------
-- 创建者：Ghost
-- 创建日期: 2019/08/02
-- 模块作用: agent服务对象的scm变量
----------------------------------------

local paris = paris
local error = error
local assert = assert

assert(MYSQL_FIELDTYPE_MAP)

-- 此属性变量为后台在mysql中使用的字段，角色每次存盘的时候会顺便存储
-- 注意：该字段必须是可以在agent clsRole中直接Get变量名，例如：BindYuanBao，必定有GetBindYuanBao函数才行
-- 类型选择：int(11)，bigint(20)，double(16,2)，bigint(20)，varchar(32)，varchar(64)，varchar(128)，varchar(256)，text
local SCM_ROLEVAR = {
	Grade				= "int(11)",
	Cash				= "bigint(20)",
	RealYuanBao			= "int(11)",
	LoginTime			= "int(11)",
	LogoutTime			= "int(11)",
	Account				= "varchar(64)",
	ServerId			= "int(11)",
	Score				= "int(11)",
	Vip					= "int(11)",
	ClubId				= "varchar(32)",
	ClubName			= "varchar(64)",
	Birthday			= "int(11)",
	ClientIp			= "varchar(32)",
	AccuChongZhiYuanBao	= "int(11)",
	TotalOnlineSec		= "int(11)",
	BreakStone			= "int(11)",
	GoldKey				= "int(11)",
	ColorKey			= "int(11)",
	WishCoin			= "int(11)",
	DayOnlineSec		= "int(11)",
	Photo				= "varchar(32)",
	ServerIndex			= "int(11)",
	TotalRechargeAmount	= "double(16,2)",
	MagicEatMedicineNum	= "int(11)",
	CorpId				= "int(11)",
	MachineCode			= "varchar(64)",
}

-- 实时存盘字段，只能int(11)类型的字段，如果后续有需要别的字段就加(但是绝对不能是table的字段，因为要手动SetSave才知道改变)
local SCM_ROLEVAR_REALTIMESAVE = {
	Grade				= true,
	Cash				= true,
	RealYuanBao			= true,
	LoginTime			= true,
	LogoutTime			= true,
	Account				= true,
	Vip					= true,
	ClubId				= true,
	ClubName			= true,
	AccuChongZhiYuanBao	= true,
	Score				= true,
	TotalRechargeAmount	= true,
}

for _varName, _filedType in pairs(SCM_ROLEVAR) do
	if not MYSQL_FIELDTYPE_MAP[_filedType] then
		local msg = string.format("scm role var:%s filedType:%s", _varName, _filedType)
		error(msg)
	end
end

local SCM_ROLE_FUNCVAR = {}
for _varName, _ in pairs(SCM_ROLEVAR) do
	SCM_ROLE_FUNCVAR["Get" .. _varName] = _varName
end
local SCM_ROLE_REALTIMESAVE_FUNCVAR = {}
for _varName, _ in pairs(SCM_ROLEVAR_REALTIMESAVE) do
	local ctype = SCM_ROLEVAR[_varName]
	assert( -- 只能int(11)类型的字段，如果后续有需要别的字段就加(但是绝对不能是table的字段)
		ctype == "int(11)" or ctype == "bigint(20)" or
		ctype == "varchar(64)" or ctype == "varchar(32)" or
		ctype == "double(16,2)"
	)
	SCM_ROLE_REALTIMESAVE_FUNCVAR["Get" .. _varName] = _varName
end

function GetScmRoleFuncVar()
	return SCM_ROLE_FUNCVAR
end
function GetScmRoleVar()
	return SCM_ROLEVAR
end

function GetScmRoleFuncVar_RealTimeSave()
	return SCM_ROLE_REALTIMESAVE_FUNCVAR
end
function GetScmRoleVar_RealTimeSave()
	return 	SCM_ROLEVAR_REALTIMESAVE
end