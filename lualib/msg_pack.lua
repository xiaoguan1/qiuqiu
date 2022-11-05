local table = table
local M = {}

-- 消息的解码
M.str_unpack = function(msgstr)
        local msg = {}

        while true do
                local arg, rest = string.match(msgstr, "(.-),(.*)")
                if arg then
                        msgstr = rest
                        table.insert(msg, arg)
                else
                        table.insert(msg, msgstr)
                        break
                end
        end
        return msg[1], msg
end

-- 消息的编码
M.str_pack = function(cmd, msg)
	return table.concat(msg, ",") .. "\r\n"
end

return M
