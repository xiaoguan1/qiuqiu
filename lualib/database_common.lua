--------------------------
-- 创建者：Ghost
-- 创建日期：2019/08/02
-- 模块作用：数据库同用接口
--------------------------

local skynet = require "skynet"
local string = string
local table = table
local debug = debug
local assert = assert

local traceback = debug.traceback
-- local dpclusterData = assert(load("return " .. skynet.getenv("dpcluster"))())
-- local node_ipport = dpclusterData["node_ipport"]
-- local DATABASE_NODE = NAMED_SERVER_NODE.dbserver.node
-- local IS_DATA_SELFNODE = dpclusterData[DATABASE_NODE] == node_ipport
local DB_CNT = tonumber(skynet.getenv("database_num")) or 10

local PROXYSVR = Import("lualib/base/proxysvr.lua")
local DATABASE_SVR = PROXYSVR.GetProxyByServiceName("dbserver")

function Send_ModCreateNexist(modName)
   DATABASE_SVR.send.mod_createnexist(modName)
end

function Call_ModGetData(modName)
    return DATABASE_SVR.call.mod_getdata(modName)
end

function Send_ModSave(save_name, data_tbl, is_imm)
    if IS_DATA_SELFNODE then
        local ptr_data, sz, quotedsz = lserialize.lua_seri_ptr_quotedlen(data_tbl)
        DATABASE_SVR.send.mod_setdata_ptrq(save_name, ptr_data, sz, quotedsz, is_imm)
    else
        local data, quotedsz = lserialize.lua_seri_ptr_quotedlen(data_tbl)
        DATABASE_SVR.send.mod_setdata(save_name, data, quotedsz, is_imm)
    end
end