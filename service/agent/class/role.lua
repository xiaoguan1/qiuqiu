local skynet = require "skynet"

--autogen-begin
function clsRole:Getplayerid()
    return self.__data.playerid
end
function clsRole:Setplayerid(playerid)
    self.__data.playerid = playerid
end

function clsRole:Getcoin()
    return self.__data.coin
end
function clsRole:Setcoin(coin)
    self.__data.coin = coin
end

function clsRole:Getname()
    return self.__data.name
end
function clsRole:Setname(name)
    self.__data.name = name
end

function clsRole:Getlevel()
    return self.__data.level
end
function clsRole:Setlevel(level)
    self.__data.level = level
end

function clsRole:Getlast_login_time()
    return self.__data.last_login_time
end
function clsRole:Setlast_login_time(last_login_time)
    self.__data.last_login_time = last_login_time
end


--autogen-end

function a()
    print("11111111111111")
end