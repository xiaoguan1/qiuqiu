local skynet = require "skynet"
local tinsert = table.insert
local pairs = pairs
local error = error
local database_cachecnt = tonumber(skynet.getenv("database_cachecnt")) or 100

local function _empty(tbl)
	for k, v in pairs(tbl) do
		return false
	end
	return true
end

-- {
-- 	[urs] = {
-- 		data_ptr = ,
-- 		sz = ,
-- 		quotedsz = ,
-- 		hsave = nil
-- 	},
-- 	...
-- }
CACHE_URS = {}

-- {
-- 	[uid] = {
-- 		["data"] = {
-- 			data_ptr = ,
-- 			sz = ,
-- 			quotedsz = ,
-- 			name = ,
-- 			hsave = ,
-- 		},
-- 		[act] = {
-- 			data_ptr = ,
-- 			sz = ,
-- 			quotedsz = ,
-- 			hsave = nil,
-- 		},
-- 	}
-- }
CACHE_UID = {}

-- {
-- 	[mod] = {
-- 		data_ptr = ,
-- 		sz = ,
-- 		quotedsz = ,
-- 		hsave = nil,
-- 	},
-- }
CACHE_MOD = {}

-- {
-- 	[urs] = "md5",
-- }
CACHE_URS_MD5 = {}

-- {
-- 	[uid] = {
-- 		[act] = "md5"
-- 	},
-- }
CACHE_UID_MD5 = {}

-- {
-- 	[mod] = "md5"
-- }
CACHE_MOD_MD5 = {}

function GetAllCacheUrs()
	local ret = {}
	local dret = {}
	local cnt = 0
	for _urs, _ in pairs(CACHE_URS) do
		ret[_urs] = true
		cnt = cnt + 1
		if cnt > database_cachecnt then
			dret[_urs] = true
		end
	end
	return ret, dret, cnt
end
function GetCacheUrs(urs)
	local d = CACHE_URS[urs]
	if d then
		return d.data_ptr, d.sz, d.quotedsz
	end
end
function IsSaveCacheUrs(urs)
	local d = CACHE_URS[urs]
	if d then
		return d.hsave
	end
end
function SetSaveCacheUrs(urs, isSave)
	local d = CACHE_URS[urs]
	if d then
		d.hsave = isSave
	end
end
function AddCacheUrs(urs, data_ptr, sz, quotedsz)
	local d = CACHE_URS[urs]
	if d then
		-- 判断一下data_ptr是否一致，是则不用删除
		if data_ptr ~= d.data_ptr then
			-- 删除旧的data_ptr,重置其他属性
			skynet.trash(d.data_ptr, d.sz)
			d.data_ptr = data_ptr
			d.sz = sz
			d.quotedsz = quotedsz
			d.hsave = nil
		end
	else
		CACHE_URS[urs] = {
			data_ptr = data_ptr,
			sz = sz,
			quotedsz = quotedsz,
			hsave = nil,
		}
	end
end
function DelCacheUrs(urs)
	local d = CACHE_URS[urs]
	if not d then
		return
	end
	CACHE_URS[urs] = nil
	local data_ptr, sz = d.data_ptr, d.sz
	d.data_ptr = nil
	d.sz = nil
	d.quotedsz = nil
	d.hsave = nil
	skynet.trash(data_ptr, sz)
end



function GetAllChaceUid()
	local ret = {}
	local dret = {}
	local cnt = 0
	for _uid, _ in pairs(CACHE_UID) do
		ret[_uid] = true
		cnt = cnt + 1
		if cnt > database_cachecnt then
			dret[_uid] = true
		end
	end
	return ret, dret, cnt
end
function GetCacheUid(uid, act)
	local d = CACHE_UID[uid] and CACHE_UID[uid][act]
	if d then
		return d.data_ptr, d.sz, d.quotedsz, d.name
	end
end
function GetCacheUidActList(uid)
	local d = CACHE_UID[uid]
	if not d then
		return
	end

	local ret = {}
	for _actName, _ in pairs(d) do
		tinsert(ret, _actName)
	end
	return ret
end
function IsSaveCacheUid(uid, act)
	local d = CACHE_UID[uid] and CACHE_UID[uid][act]
	if d then
		return d.hsave
	end
end
function SetSaveCacheUid(uid, act, isSave)
	local d = CACHE_UID[uid] and CACHE_UID[uid][act]
	if d then
		d.hsave = isSave
	end
end
function AddCacheUid(uid, act, data_ptr, sz, quotedsz, name)
	local d = CACHE_UID[uid] and CACHE_UID[uid][act]
	if d then
		-- 判断一下data_ptr是否一致，是则不用删除
		if data_ptr ~= d.data_ptr then
			-- 删除旧的data_ptr,重置其他属性
			skynet.trash(d.data_ptr, d.sz)
			d.data_ptr = data_ptr
			d.sz = sz
			d.quotedsz = quotedsz
			d.hsave = nil
		end
		if name then
			d.name = name
		end
	else
		if not CACHE_UID[uid] then
			CACHE_UID[uid] = {}
		end
		CACHE_UID[uid][act] = {
			data_ptr = data_ptr,
			sz = sz,
			quotedsz = quotedsz,
			name = name,
			hsave = nil,
		}
	end
end
function DelCacheUid(uid, act)
	local d = CACHE_UID[uid] and CACHE_UID[uid][act]
	if not d then
		return
	end
	CACHE_UID[uid][act] = nil
	local data_ptr, sz = d.data_ptr, d.sz
	d.data_ptr = nil
	d.sz = nil
	d.quotedsz = nil
	d.name = nil
	d.hsave = nil
	skynet.trash(data_ptr, sz)
	if _empty(CACHE_UID[uid]) then
		CACHE_UID[uid] = nil
	end
end



function GetAllCacheMod()
	local ret = {}
	local dret = {}
	local cnt = 0
	for _mod, _ in pairs(CACHE_MOD) do
		ret[_mod] = true
		cnt = cnt + 1
		-- if cnt > database_cachecnt then
			dret[_mod] = true
		-- end
	end
	return ret, dret, cnt
end
function GetCacheMod(mod)
	local d = CACHE_MOD[mod]
	if d then
		return d.data_ptr, d.sz, d.quotedsz
	end
end
function IsSaveCacheMod(mod)
	local d = CACHE_MOD[mod]
	if d then
		return d.hsave
	end
end
function SetSaveCacheMod(mod, isSave)
	local d = CACHE_MOD[mod]
	if d then
		d.hsave = isSave
	end
end
function AddCacheMod(mod, data_ptr, sz, quotedsz)
	local d = CACHE_MOD[mod]
	if d then
		-- 判断一下data_ptr是否一致，是则不用删除
		if data_ptr ~= d.data_ptr then
			-- 删除旧的data_ptr,重置其他属性
			skynet.trash(d.data_ptr, d.sz)
			d.data_ptr = data_ptr
			d.sz = sz
			d.quotedsz = quotedsz
			d.hsave = nil
		end
	else
		CACHE_MOD[mod]= {
			data_ptr = data_ptr,
			sz = sz,
			quotedsz = quotedsz,
			hsave = nil,
		}
	end
end
function DelCacheMod(mod)
	local d = CACHE_MOD[mod]
	if not d then
		return
	end
	CACHE_MOD[mod] = nil
	local data_ptr, sz = d.data_ptr, d.sz
	d.data_ptr = nil
	d.sz = nil
	d.quotedsz = nil
	d.hsave = nil
	skynet.trash(data_ptr, sz)
end



function RefresUrsMd5(urs, md5)
	CACHE_URS_MD5[urs] = md5
end
function GetUrsMd5(urs)
	return CACHE_URS_MD5[urs]
end

function RefresUidMd5(uid, act, md5)
	CACHE_UID_MD5[uid] = CACHE_UID_MD5[uid] or {}
	CACHE_UID_MD5[uid][act] = md5
end
function GetUidMd5(uid, act)
	return CACHE_UID_MD5[uid] and CACHE_UID_MD5[uid][act]
end

function RefresModMd5(mod, md5)
	CACHE_MOD_MD5[mod] = md5
end
function GetModMd5(mod)
	return CACHE_MOD_MD5[mod]
end