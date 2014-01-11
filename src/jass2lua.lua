
starttime = os.clock()

--�������е�jass��������
jasstypes = {"boolean", "integer", "real", "string", "code", "handle", "agent", "event", "player", "widget", "unit", "destructable", "item", "ability", "buff", "force", "group", "trigger", "triggercondition", "triggeraction", "timer", "location", "region", "rect", "boolexpr", "sound", "conditionfunc", "filterfunc", "unitpool", "itempool", "race", "alliancetype", "racepreference", "gamestate", "igamestate", "fgamestate", "playerstate", "playerscore", "playergameresult", "unitstate", "aidifficulty", "eventid", "gameevent", "playerevent", "playerunitevent", "unitevent", "limitop", "widgetevent", "dialogevent", "unittype", "gamespeed", "gamedifficulty", "gametype", "mapflag", "mapvisibility", "mapsetting", "mapdensity", "mapcontrol", "playerslotstate", "volumegroup", "camerafield", "camerasetup", "playercolor", "placement", "startlocprio", "raritycontrol", "blendmode", "texmapflags", "effect", "effecttype", "weathereffect", "terraindeformation", "fogstate", "fogmodifier", "dialog", "button", "quest", "questitem", "defeatcondition", "timerdialog", "leaderboard", "multiboard", "multiboarditem", "trackable", "gamecache", "version", "itemtype", "texttag", "attacktype", "damagetype", "weapontype", "soundtype", "lightning", "pathingtype", "image", "ubersplat", "hashtable"}
for _, name in ipairs(jasstypes) do
	jasstypes[name] = true --���������
end

luat = {} --���ÿһ�д����table

table.insert(luat, [[
--metatable

_mt_number = { __index = function()
	return 0
end}

_mt_boolean = { __index = function()
	return false
end}

table.newnumber = function()
	local t = {}
	setmetatable(t, _mt_number)
	return t
end

table.newboolean = function()
	local t = {}
	setmetatable(t, _mt_boolean)
	return t
end

--remove all units,wait to recreate by lua

local g = CreateGroup()

for i = 0, 15 do
    GroupEnumUnitsOfPlayer(g, Player(i), Condition(
        function()
            RemoveUnit(GetFilterUnit())
        end
    ))
end
]])

table.insert(luat, "\n\n")

functionTypes = {} --��ź���������
globalTypes = {} --���ȫ�ֱ���������
localTypes = {} --��žֲ�����������,ÿ��endfunction������

functionType = function(word, cj)
	local match = "function%s+([%w_]+)%s+takes.-returns%s+([%w_]+)"
	if cj then
		match = "native%s+([%w_]+)%s+takes.-returns%s+([%w_]+)"
	end
	local name, type = string.match(word, match)
	if type and type ~= "nothing" then
		functionTypes[name] = type

	end
end

globalType = function(word)
	if isglobal then
		local t = {}
		for thisword in string.gmatch(word, "([%w_%/]+)") do
			table.insert(t, thisword)
		end
		if #t ~= 0 then
			if t[1] == "//" then return end
			local name
			local type
			for i, v in ipairs(t) do
				if jasstypes[v] then
					type = v
					if t[i+1] == "array" then
						name = t[i+2]
					else
						name = t[i+1]
					end
					globalTypes[name] = type
					return
				end
			end
		end
	end
end

localType = function(word)
	if not isglobal then
		local type, arrayorname, name = string.match(word, "local (%S+)%s+(%S+)%s+(%S+)")
		if type and jasstypes[type] then
			if arrayorname == "array" then
				localTypes[name] = type
			else
				localTypes[arrayorname] = type
			end
		end
		local thiswords = string.match(word, "takes(.+)returns")
		if thiswords then
			for type, name in string.gmatch(thiswords, "([%w_]+)%s+([%w_]+)") do
				localTypes[name] = type
			end
		end
	end
end

j2lfuncs = {
	--�޸�ת���
	function(word)
		if string.sub(word, 1, 2) == "//" then
			word = false
		end
		return word
	end,
	--ɾ�����ֳ�ʼ��
	function(word)
		if ismain then
			if word == "InitSounds" or word == "CreateRegions" or word == "InitBlizzard" then
				word = false
			end
		end
		return word
	end,
	--�޸�256���Ʒ���
	function(word)
		if string.sub(word, 1, 1) == "'" then
			word = string.gsub(word, "'", "|")
		end
		return word
	end,
	--ɾ��globals��endglobals
	function(word)
		if word == "globals" then
			word = nil
			isglobal = true
		elseif word == "endglobals" then
			isglobal = false
		end
		return word
	end,
	--ɾ����������
	function(word)
		if jasstypes[word] then
			nextType = word
			word = nil
		end
		return word
	end,
	--ɾ��set��call
	function(word)
		if word == "set" or word == "call" then
			word = nil
		end
		return word
	end,
	--�޸�function��ʽ
	function(word)
		if word == "function" then
			word = nil
		elseif word == "takes" then
			word = " = function ("
		elseif word == "returns" then
			word = ")"
		elseif word == "nothing" then
			word = nil
		end
		return word
	end,
	--�޸�end��
	function(word)
		if word == "end" then
			word = "end_"
		elseif word == "endif" or word == "endloop" then
			word = "end"
		elseif word == "endfunction" then
			word = "end"
			localtypes = {} --�����������þֲ�����
		end
		return word
	end,
	--�޸�nullΪnil
	function(word)
		if word == "null" then
			word = "nil"
		end
		return word
	end,
	--�޸�ѭ����ʽ
	function(word)
		if word == "loop" then
			word = "for _i = 1, 10000 do"
		elseif word == "exitwhen" then
			word = "if"
			word2 = "then break end"
		end
		return word
	end,
	--�޸�������ʽ
	function(word)
		if word == "array" then
			word = nil
			if nextType == "integer" or nextType == "real" then
				word2 = "= table.newnumber()"
			elseif nextType == "boolean" then
				word2 = "= table.newboolean()"
			else
				word2 = "= {}"
			end
		end
		return word
	end,
	--�޸�return��ʽ
	function(word)
		if word == "return" then
			word = "do return"
			word2 = "end"
		end
		return word
	end,
	--�޸�����  .0 �Ȳ��淶����
	function(word)
		if string.sub(word, 1, 1) == "." then
			word = 0 .. word
		end
		return word
	end,
	--��¼��ǰ�ߵ�������
	function(word)
		local thisword = string.match(word, "([%w_]+)")
		if string.sub(word, 1, 1) == [["]] then
			lastType = "string"
		elseif thisword then
			lastType = functionTypes[thisword] or localTypes[thisword] or globalTypes[thisword]
		end
		return word
	end,
}

Debug = {}

--����ȡ������jass����ת����lua����
j2l = function(jass, cj)
	local words = {} --��ŵ�ǰ���ҵ������е���
	if jass == "function main takes nothing returns nothing" then
		ismain = true
	end
	functionType(jass, cj) --�ʷ�����(����)
	findString(jass)
	jass = string.gsub(jass, "%$", "0x")
	jass = string.gsub(jass, [[ExecuteFunc%((.-)%)]], "pcall(_G[%1])")
	jass = string.gsub(jass, "([%+%-%*%,%(%)%[%]])", " %1 ")
	jass = string.gsub(jass, "([%/%=])(.)", function(a, b)
		if a == b or (b == "=" and (a == ">" or a == "<")) then
			return a .. b
		else
			return a .. " " .. b
		end
	end)
	jass = string.gsub(jass, "(.)([%/%=])", function(a, b)
		if a == b or (b == "=" and (a == ">" or a == "<")) then
			return a .. b
		else
			return a .. " " .. b
		end
	end)
	jass = string.gsub(jass, "! =", "~=")
	jass = string.gsub(jass, "constant", "")
	globalType(jass) --�ʷ�����(ȫ�ֱ���)
	localType(jass) --�ʷ�����(�ֲ�����)
	for word in string.gmatch(jass, "([%S]+)") do
		for _, func in ipairs(j2lfuncs) do
			word = func(word)
			if not word then
				break
			end
		end
		if word == false then
			break
		elseif word ~= nil then
			if lastType == "string" and words[#words] == "+" then
				--�޸���һ��"+"
				lastType = nil
				words[#words] = ".."
			end
			table.insert(words, word)
		end
	end
	if word2 then
		table.insert(words, word2)
		word2 = nil
	end
	if #words == 1 and words[1] ~= "end" and words[1] ~= "while true do" and words[1] ~= "else" and words[1] ~= "return" then
		if not string.find(words[1], "[^%w_]") then
			if not Debug[words[1]] then
				--print(words[1])
				Debug[words[1]] = true
			end
			return
		end
	end
	if #words ~= 0 and not cj then
		local ss = table.concat(words, " ")
		ss = backString(ss)
		table.insert(luat, ss)
		table.insert(luat, "\n") --�����һ�����з�
	end
end

do
	local strings

	findString = function(s)
		strings = {}
		for word in string.gmatch(s, [["(.-)"]]) do
			table.insert(strings, word)
		end
	end

	backString = function(s)
		if #strings == 0 then
			return s
		end
		return string.gsub(s, [["(.-)"]],
			function(word)
				local word = strings[1]
				table.remove(strings, 1)
				return [["]] .. word .. [["]]
			end
		)
	end
end

local function usage()
	print('\n')
	print('usage: jass2lua.lua input output library_dir\n')
	print('  input       : input script path \n')
	print('  output      : output script path\n')
	print('  library_dir : common.j/blizzard.j\'s dir\n')
	print('\n')
end

local function main()
	if (not arg) or (#arg < 3) then
		usage()
		return
	end
	
	local in_script  = arg[1]
	local out_script = arg[2]
	local library    = arg[3]

	for line in io.lines(library .. "common.j") do
		--����cj��ÿһ��
		j2l(line, true)
	end
	
	for line in io.lines(library .. "blizzard.j") do
		--�����ű���ÿһ��
		j2l(line)
	end
	
	for line in io.lines(in_script) do
		--�����ű���ÿһ��
		j2l(line)
	end
	
	table.insert(luat, string.format("--project 'jass2lua' complete! %d lines in %s second,by '%s'", #luat / 2, os.clock() - starttime, "MoeUshio"))
	
	table.insert(luat, "\n\n")
	
	table.insert(luat, [[
		ModuloInteger = math.fmod
		ModuloReal = math.fmod
	]])
	
	local file = io.open(out_script,"w")
	file:write(table.concat(luat))
	file:close()
	
	print("�������,����", math.floor(#luat / 2), "��,��ʱ", os.clock() - starttime, "��")
end

main()
