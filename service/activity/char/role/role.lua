--autogen-begin
function clsRole:GetName()
	return self.__tmp.Name
end
function clsRole:SetName(Name)
	self.__tmp.Name = Name
end

function clsRole:GetSex()
	return self.__tmp.Sex
end
function clsRole:SetSex(Sex)
	self.__tmp.Sex = Sex
end

if SERVICE_NAME == "actsvc/boxofficeSave" then
	function clsRole:GetBoxofficeSave()
		return self.__data.BoxofficeSave
	end
	function clsRole:SetBoxofficeSave(BoxofficeSave)
		self.__data.BoxofficeSave = BoxofficeSave
	end
else
	function clsRole:GetBoxofficeSave()
		return self.__tmp.BoxofficeSave
	end
	function clsRole:SetBoxofficeSave(BoxofficeSave)
		self.__tmp.BoxofficeSave = BoxofficeSave
	end
end

if SERVICE_NAME == "actsvc/maze" then
	function clsRole:GetMaze()
		return self.__data.Maze
	end
	function clsRole:SetMaze(Maze)
		self.__data.Maze = Maze
	end
else
	function clsRole:GetMaze()
		return self.__tmp.Maze
	end
	function clsRole:SetMaze(Maze)
		self.__tmp.Maze = Maze
	end
end

if SERVICE_NAME == "actsvc/champion" then
	function clsRole:GetChampionData()
		return self.__data.ChampionData
	end
	function clsRole:SetChampionData(ChampionData)
		self.__data.ChampionData = ChampionData
	end
else
	function clsRole:GetChampionData()
		return self.__tmp.ChampionData
	end
	function clsRole:SetChampionData(ChampionData)
		self.__tmp.ChampionData = ChampionData
	end
end

if SERVICE_NAME == "actsvc/arena" then
	function clsRole:GetArenaMaxIntegral()
		return self.__data.ArenaMaxIntegral
	end
	function clsRole:SetArenaMaxIntegral(ArenaMaxIntegral)
		self.__data.ArenaMaxIntegral = ArenaMaxIntegral
	end
else
	function clsRole:GetArenaMaxIntegral()
		return self.__tmp.ArenaMaxIntegral
	end
	function clsRole:SetArenaMaxIntegral(ArenaMaxIntegral)
		self.__tmp.ArenaMaxIntegral = ArenaMaxIntegral
	end
end

if SERVICE_NAME == "actsvc/arena" then
	function clsRole:GetArenaAttTotalWinCnt()
		return self.__data.ArenaAttTotalWinCnt
	end
	function clsRole:SetArenaAttTotalWinCnt(ArenaAttTotalWinCnt)
		self.__data.ArenaAttTotalWinCnt = ArenaAttTotalWinCnt
	end
else
	function clsRole:GetArenaAttTotalWinCnt()
		return self.__tmp.ArenaAttTotalWinCnt
	end
	function clsRole:SetArenaAttTotalWinCnt(ArenaAttTotalWinCnt)
		self.__tmp.ArenaAttTotalWinCnt = ArenaAttTotalWinCnt
	end
end

if SERVICE_NAME == "actsvc/chat" then
	function clsRole:GetBattleShareCnt()
		return self.__data.BattleShareCnt
	end
	function clsRole:SetBattleShareCnt(BattleShareCnt)
		self.__data.BattleShareCnt = BattleShareCnt
	end
else
	function clsRole:GetBattleShareCnt()
		return self.__tmp.BattleShareCnt
	end
	function clsRole:SetBattleShareCnt(BattleShareCnt)
		self.__tmp.BattleShareCnt = BattleShareCnt
	end
end

if SERVICE_NAME == "actsvc/chat" then
	function clsRole:GetBattleShareTime()
		return self.__data.BattleShareTime
	end
	function clsRole:SetBattleShareTime(BattleShareTime)
		self.__data.BattleShareTime = BattleShareTime
	end
else
	function clsRole:GetBattleShareTime()
		return self.__tmp.BattleShareTime
	end
	function clsRole:SetBattleShareTime(BattleShareTime)
		self.__tmp.BattleShareTime = BattleShareTime
	end
end

if SERVICE_NAME == "actsvc/chat" then
	function clsRole:GetShieldRedChannel()
		return self.__data.ShieldRedChannel
	end
	function clsRole:SetShieldRedChannel(ShieldRedChannel)
		self.__data.ShieldRedChannel = ShieldRedChannel
	end
else
	function clsRole:GetShieldRedChannel()
		return self.__tmp.ShieldRedChannel
	end
	function clsRole:SetShieldRedChannel(ShieldRedChannel)
		self.__tmp.ShieldRedChannel = ShieldRedChannel
	end
end


--autogen-end