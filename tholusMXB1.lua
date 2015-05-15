--Project THOLUS - RPG Engine
--Initiated by Kubius 1/7/2015
--Major Version X, Build 1
--for Command Computers

--CHANGELOG--
--[[
 MXB1 - 5/13/2015
  Added "burntoworld": creates a dungeon via commands
  starting at two blocks southeast of the coordinates
  specified in the configuration. Credit Kaikaku for
  the buildCol() command.
  Modified worldgen to add chest generation.
  Added many comments to code.
 M4B3 - 1/19/2015
  Another attempt at fixing the vacillation bug.
  Fixed custom room-size parameter capability.
   If a spot for a room can't be found within four tries,
   the room is now discarded from generation.
  "Doormat" functionality added - edge doors will now automatically
   force a ground tile to be present in front of them if edge
   doors are enabled during generation.
  Tweaked room generation ordering - search-head movement is now
   done after directional search, not before.
  Tweaked door generation to compensate for an ordering effect -
   doors will no longer generate at a path's start if the path
   immediately turns at the beginning.
 M4B2 - 1/18/2015
  New command for end-of-generation: burntodisk
  burntodisk writes a binary version of the level file to
  disk/levelfile, overwriting any present items.
  Removed time delay on EDGEFLAG.
  Found out vacillation glitch still isn't fixed.
 M4B1 - 1/17/2015
  Considerable improvements to level generation:
	Edge doors - always appear at the center of level edges -
	they generate corridors to always connect to the level.
	Fixed a glitch where [GEN] -1 0 and [GEN] 1 0 would spam - bug
	was caused by vacillation between two options.
 M3B4 - 1/9/2015
  Random seed upgraded to increase capabilities.
  Overlap detector modified to only work in cases of extreme overlap.
 M3B3 - 1/9/2015
  Further tweaks to generation algorithm, including door insertion.
 M3B2 - 1/8/2015
  Slightly tweaked room distribution in generation algorithm.
 M3B1 - 1/8/2015
  Allowed export of a simplified table to allow turtle building.
  Custom parameter hack added.
 M2B3 - 1/8/2015
  Revised path generation algorithm to remove dummy paths.
 M2B2 - 1/8/2015
  Removed hard-coded X/Y dimensions.
 M2B1 - 1/8/2015
  Successfully completed world generation algorithm.
]]

--THOLUS Launch Parameter Guide
--[[
 tholus(distnumber) genedges xdim ydim rooms seed
 ALL PARAMETERS OPTIONAL
 genedges: If 0, turns off edge generation.
 xdim,ydim: Sets X and Y dimensions. Experimental.
 rooms: Sets room attempt count.
 seed: Sets seed.
 Manually specifies things to generate with.
]]

--THOLUS Post-Generation Commands
--[[
  burntoworld: New in Tholus MX - creates the
  generated dungeon in-world with loot chests
  populated with loot from the loot list.
  Coordinates are set in the configuration
  
  burntodisk: Creates a binary schematic from
  the current level in the following format:
  Level X size - Level Y size - binary string
  This is useful for Turtle construction -
  CUPOLA is a good program for this.
  
  (anything else): Quit without saving.
]]

--Resource Notes:
--[[
Primary Data Table Matrix Structure:
mt
 X Coordinate
  Y Coordinate
   Tile Data
    Tile Type (wall, ground, door)
	Contextual List (wall, ground, door - use tiletype)
   Mob Data
    Mob (nil if no mob, or is name of mob table)
	  MobName
	  MobHP
	  MobDead
	Container (nil if not container, or is name of container table)
   
Examples on pulling data for a tile

Check if an entity can enter the tile at 1,1
canmove = mt[1][1]["tile"]["type"] ~= "wall" and [1][1]["tile"]["canEnter"]

Check if you can destroy the turf of 1,1
candestroy = mt[1][1]["tile"]["type"]

Check if there is a mob at 1,1
mobexists = mt[1][1]["mob"] and mt[1][1]["mob"]["name"]

Check if you can attack a mob at 1,1
canattack = mt[1][1]["mob"] and [1][1]["mob"]["alive"]

]]

--Build coordinate configuration: enter in the coordinates for the
--bottom of the northwest corner and the program
--will appropriately set up positions.

local worldX = -1109
local worldZ = 773
local worldY = 2

--TILESET CONFIGURATION: Changing materials used by burntoworld
--How to use: Uncomment the tileset you want to use.

--Factory Tileset
--
local c1="chisel:factoryblock"
local c2="chisel:glass"
local c3="minecraft:air"
local c4="chisel:glowstone"

local b1={c1,4} --regular metal
local b2={c1,7} --hazard block
local b3={c3,0} --air
local b4={c2,3} --glass
local b5={c4,4} --chisel mod lamp

local w1={b1,b1,b1,b2,b1} --Walls
local w2={b1,b3,b3,b2,b1} --Low door: unused
local w3={b1,b3,b3,b3,b4} --Main hallway
local w4={b1,b3,b3,b5,b1} --Regular door
local w5={b2,b3,b3,b5,b2} --Edge door
--]]

--Gardens Tileset
--[[
local c1="chisel:cobblestone"
local c2="chisel:glass"
local c3="minecraft:air"
local c4="chisel:glowstone"
local c5="minecraft:grass"

local b1={c1,2} --detailed cobble brick
local b2={c1,3} --small bricks
local b3={c3,0} --air
local b4={c2,11} --stone frame glass
local b5={c4,4} --chisel mod lamp
local b6={c5,0} --grass

local w1={b1,b1,b1,b2,b1} --Walls
local w2={b1,b3,b3,b2,b1} --Low door: unused
local w3={b6,b3,b3,b3,b4} --Main hallway
local w4={b1,b3,b3,b3,b5} --Regular door
local w5={b2,b3,b3,b2,b2} --Edge door
--]]

--Loot table: Data values / max stack size
local lootTab = {
	{5474,5},
	{268,1},
	{5767,1},
	{334,4},
	{5369,14},
	{334,3},
	{6498,3},
	{367,4},
	{5871,8},
	{5158,1},
	{5,5}
}



--Main data table
local mt = {}

--Sprite table
local stab = {
	["ground"] = "_",
	["wall"] = "#",
	["dooropen"] = "|",
	["doorclosed"] = "D",
	["player"] = "@",
	["mob"] = "&",
	["edgedoor"] = "X",
	["chest"] = "n"
}

--Directions for figuring out which way a corridor is to be built
--1: Down (+Y)
--2: Right (+X)
--3: Up (-Y)
--4: Left (-X)
local dirTabX = {
	0,
	1,
	0,
	-1
}
local dirTabY = {
	1,
	0,
	-1,
	0
}
local function sDir(intIn)
	return dirTabX[intIn],dirTabY[intIn]
end

local params = {...}

--Variables for map size
local MX = 21 --Left-right (X) map size
local MY = 17 --Up-down (Y) map size
--LEVEL SIZE MUST BE ODD

--Variable for quantity of rooms - leave nil for amount determined by mapsize
osc = nil

--Seed create
local ransack = os.time() * 100 + os.day()
local genedges = true --Flag for edge generation

--HACKY BYPASS LAND
if params[1] ~= nil then
if tonumber(params[1]) == 0 then
genedges = false
end
if params[2] ~= nil and params[3] ~= nil then
MXn = tonumber(params[2])
MYn = tonumber(params[3])
if not (MXn % 2 == 0 or MYn % 2 == 0) and (MXn > 10 and MYn > 10) then
MX = MXn
MY = MYn
else
print("Invalid level size - selecting default")
sleep(3)
end
end
if params[4] ~= nil then osc = params[4] end
if params[5] ~= nil then ransack = tonumber(params[5]) end
end
--END HACKY BYPASS LAND

--Set randomness from seed
math.randomseed(ransack)

--Directional variable tracking necessary for dungeon door construction
local ignoreDown = false
local ignoreRight = false
local ignoreUp = false
local ignoreLeft = false
local ignoreTable = {ignoreDown,ignoreRight,ignoreUp,ignoreLeft}

--Constructs a basic level's data framework including world border
local function buildBaseLevel()
    for x = 1,MX do
	    mt[x] = {}
	    for y = 1,MY do
		    mt[x][y] = {
				["mob"]={},
				["container"]={},
				["tile"]={
					["type"] = nil,
					["canEnter"] = false,
					["canGen"] = false, --For room generator
					["canDoor"] = nil --And again
				}
			}
		end
	end
	for x = 2,MX-1 do
		for y = 2,MY-1 do
			mt[x][y]["tile"]["type"] = "wall"
		end
	end
	for x = 3,MX-2 do
		for y = 3,MY-2 do
			mt[x][y]["tile"]["canGen"] = true
		end
	end
end

--Level size distribution, to try and reduce quantity of oversized rooms
local sizeDist = {1,2,1,2,1}


--Populates a level with rooms, halls and entrances
local function populateLevel()
	--Figure out how many rooms you need for this size of level
	--21x17 level will generate 5 to 7
	local tilect = MX*MY
	local roomfactor = (tilect-(tilect%50))/50 --Default room count: generates from map size
	local roomcount = tonumber(osc or "0") --This and below check for a custom room count
	if roomcount < 1 then
		roomcount = nil
	end
	local iters = roomcount or math.random(roomfactor-2,roomfactor) --Room generation attempts
	--Room generation
	local chest = math.ceil(iters/3) --Flag to ensure chests are not generated in ALL rooms
	for i = 1,iters do
		local size = sizeDist[math.random(1,5)] --Select 3x3 or 5x5 room
		local gatesize = size + 1 --For positioning of doors
		local pX = math.random(3,MX-2)
		local pY = math.random(3,MY-2)
		--To avoid generating rooms RIGHT on top of each other.
		local tries = 0 --For if rooms are too crowded. Eight tries is the max.
		while true do
		print("[GEN] OVERLAP TEST")
		sleep(0.05)
		local luga = false
		local vinx,viny = term.getCursorPos()
		for modx = -1,1 do
			term.write(modx)
			term.setCursorPos(1,viny)
			sleep(0.05)
			for mody = -1,1 do
				term.write(mody)
				term.setCursorPos(1,viny)
				sleep(0.05)
				if mt[pX+modx][pY+mody]["tile"]["canGen"] == false and mt[pX+modx][pY+mody]["tile"]["type"] == "ground"
				then print("LUGA") luga = true break end
			end
			if luga == true then break end
		end
		if luga == false then break end
		if tries > 3 then
			print("[GEN] NO ROOM FOR ROOM")
			print("[GEN] ROOM DISCARDED")
			sleep(0.2)
			break
		end
		print("[GEN] ROOM REROLL")
		sleep(0.1)
		size = sizeDist[math.random(1,5)] --Select 3x3 or 5x5 room, again
		gatesize = size + 1
		pX = math.random(3,MX-2)
		pY = math.random(3,MY-2)
		tries = tries+1
		end
		--Two tables for crosscomparison to determine door compatibility
		--Doors generate along the center of room walls
		local tabA = {pX,pX+size,pX,pX-size}
		local tabB = {pY+size,pY,pY-size,pY}
		for x = pX-size,pX+size do
			for y = pY-size,pY+size do
				if mt[x][y]["tile"]["canGen"] ~= false then
					if mt[x][y]["tile"]["canDoor"] then
						mt[x][y]["tile"]["canDoor"] = nil
					end
					mt[x][y]["tile"]["canGen"] = false
					if x == pX and y == pY and chest > 0 then --Chest generation
						mt[x][y]["tile"]["type"] = "chest"
						mt[x][y]["tile"]["canEnter"] = false
						chest = chest-1
					else
						mt[x][y]["tile"]["type"] = "ground"
						mt[x][y]["tile"]["canEnter"] = true
					end
				end
			end
		end
		--This section attempts to generate doors at the center of rooms' edges
		--The two tables are used to iterate easily over the possibilities
		local tabC = {pX,pX+gatesize,pX,pX-gatesize}
		local tabD = {pY+gatesize,pY,pY-gatesize,pY}
		for a = 1,4 do
			sleep(0.05)
			local xv = tabC[a]
			local yv = tabD[a]
			if xv < 3 or (MX-2) < xv or yv < 3 or (MY-2) < yv then
			print("[GEN]OUT OF BOUNDS: "..a)
			else
			if mt[xv][yv]["tile"]["canGen"] == ((not nil) and true) then
				mt[xv][yv]["tile"]["canDoor"] = a --Saves door direction for pathgen
				term.clearLine()
				print("[GEN]IN BOUNDS: "..a.." "..mt[xv][yv]["tile"]["canDoor"])
			else
			print("[GEN]OUT OF BOUNDS: "..a)
			end
			end
		end
	end
	local xcent = math.ceil(MX/2)
	local ycent = math.ceil(MY/2)
	--Generate area-exit doorways with location determined by map size
	--1:down|2:right|3:up|4:left
	if genedges == true then
		local tabE = {xcent,2,xcent,MX-1}
		local tabF = {2,ycent,MY-1,ycent}
		for a = 1,4 do
			local xv = tabE[a]
			local yv = tabF[a]
			mt[xv][yv]["tile"]["canDoor"] = a
			mt[xv][yv]["tile"]["type"] = "edgedoor"
			mt[xv][yv]["tile"]["edgeflag"] = true 
		--Edgeflag is used for special generation behaviors, especially regarding path generation
		end
	end
	--Inter-room path generation
	for x = 2,MX-1 do
		for y = 2,MY-1 do
			if mt[x][y]["tile"]["canDoor"] ~= nil then
				local dirVar = mt[x][y]["tile"]["canDoor"] --Fetches door direction from earlier
				local startDirVar = dirVar --Saves initial direction
				local curX = x
				local curY = y
				local mdx,mdy = sDir(dirVar)
				--Summon a table to store the pathline in
				local pTab = {}
				--Fail var, to remove any unneccessary corridors
				local fail = false
				local flippy = 0
				local searchtries = 0 --Breaks if searches cease to work
				local turnedFirst = false --Prevents generation of a door where it shouldn't be
				repeat
				    print("[GEN]"..mdx.." "..mdy)
					sleep(0.05)
					if mt[curX][curY]["tile"]["canGen"] == not nil and mt[curX][curY]["tile"]["type"] == "wall" then
						table.insert(pTab,{curX,curY})
					elseif mt[curX][curY]["tile"]["canGen"] == nil and mt[curX][curY]["tile"]["edgeflag"] == "false" then 
						print("OUT OF MAP") 
						fail = true
						break 
					elseif mt[curX][curY]["tile"]["type"] == "ground" then print("PATH ENDED") break
					elseif mt[curX][curY]["tile"]["edgeflag"] == true then print("EDGEFLAG") sleep(0.1)
					else print("OUT OF MAP") fail = true break
					end
					if searchtries > MX+MY then
					print("[GEN] ABORT CORRIDOR")
					sleep(1)
					else
					--Science begins
					if dirVar % 2 == 0 then
						print("SEARCH UP/DOWN")
						for i = 2,MY-1 do
							if i < curY and mt[curX][i]["tile"]["canDoor"] == 1 then
								mdx,mdy = sDir(3)
								dirVar = 3
								if searchtries == 0 then turnedFirst = true end
							end
							if i > curY and mt[curX][i]["tile"]["canDoor"] == 3 then
								mdx,mdy = sDir(1)
								dirVar = 1
								if searchtries == 0 then turnedFirst = true end
							end
						end
						print("DONE")
					else
						print("SEARCH LEFT/RIGHT")
						for i = 2,MX-1 do
							if i < curX and mt[i][curY]["tile"]["canDoor"] == 2 then
								mdx,mdy = sDir(4)
								dirVar = 4
								if searchtries == 0 then turnedFirst = true end
							end
							if i > curX and mt[i][curY]["tile"]["canDoor"] == 4 then
								mdx,mdy = sDir(2)
								dirVar = 2
								if searchtries == 0 then turnedFirst = true end
							end
						end
						print("DONE")
					end
					searchtries = searchtries + 1
					end
					curX = curX + mdx
					curY = curY + mdy
				until false == true
				--Execute path assembly
				if fail == false then
				local ender = #pTab
				sleep(0.1)
				local noDoor = false
				for i,v in ipairs(pTab) do
					mt[v[1]][v[2]]["tile"]["canGen"] = false
					mt[v[1]][v[2]]["tile"]["type"] = "ground"
					mt[v[1]][v[2]]["tile"]["canEnter"] = "true"
					local upT = mt[v[1]][v[2]-1]["tile"]["type"]
					local downT = mt[v[1]][v[2]+1]["tile"]["type"]
					local leftT = mt[v[1]-1][v[2]]["tile"]["type"]
					local rightT = mt[v[1]+1][v[2]]["tile"]["type"]
					if (i == ender) or (i == 1 and turnedFirst == false) or (noDoor == true and i == 2) then
						print("[GEN] DOOR STARTED AT "..i)
						print(downT.."|"..rightT.."|"..upT.."|"..leftT)
						sleep(0.1)
						if i == 1 then --This is to ensure doors at the start of paths don't break
						for a = 1,4 do
							ignoreTable[a] = false
							if startDirVar == a then
							ignoreTable[a] = true
							print("IGNORED: "..a)
							end
						end
						end
						if (upT == "ground" or ignoreTable[3]) and (downT == "ground" or ignoreTable[1]) and leftT == "wall" and rightT == "wall" then
							mt[v[1]][v[2]]["tile"]["type"] = "doorclosed"
							mt[v[1]][v[2]]["tile"]["canEnter"] = "false"
							mt[v[1]-1][v[2]]["tile"]["canGen"] = "false"
							mt[v[1]+1][v[2]]["tile"]["canGen"] = "false"
							print("[GEN] UP/DOWN DOOR AT "..i)
							noDoor = false
						elseif upT == "wall" and downT == "wall" and (leftT == "ground" or ignoreTable[4]) and (rightT == "ground" or ignoreTable[2]) then
							mt[v[1]][v[2]]["tile"]["type"] = "doorclosed"
							mt[v[1]][v[2]]["tile"]["canEnter"] = "false"
							mt[v[1]][v[2]-1]["tile"]["canGen"] = "false"
							mt[v[1]][v[2]+1]["tile"]["canGen"] = "false"
							print("[GEN] LEFT/RIGHT DOOR AT "..i)
							noDoor = false
						elseif mt[v[1]][v[2]]["tile"]["edgeflag"] ~= true then
							noDoor = true
						end
					end
				end
				end
			end
		end
	end
	--Make AB-SO-LUTE-LY sure that there is accessible terrain in front of the door zone
	if genedges == true then
		local tabG = {xcent,3,xcent,MX-2}
		local tabH = {3,ycent,MY-2,ycent}
		for a = 1,4 do
			local xv = tabG[a]
			local yv = tabH[a]
			mt[xv][yv]["tile"]["type"] = "ground"
			mt[xv][yv]["tile"]["canEnter"] = true
			print("[GEN] DOORMAT "..a.." DONE")
			sleep(0.2)
		--This function makes absolutely sure anyone coming through an edge door has somewhere to put their feet
		end
	end
end

local function renderLevel()
	term.clear()
	term.setCursorPos(1,1)
	for x = 1,MX do
		for y = 1,MY do
			term.setCursorPos(x,y)
			--Tile draw
			local iconic = mt[x][y]["tile"]["type"]
			local character = stab[iconic]
			if character ~= nil then term.write(character) end
		end
	end
end

function mtToBinary()
	local binary = ""
	for y = 1,MY do
		for x = 1,MX do
			if mt[x][y]["tile"]["type"] == "wall" then
				binary = binary.."1"
			else
				binary = binary.."0"
			end
		end
	end
	return binary
end

--Begin command blocky stuff

local xx=worldX-2 yy=worldY zz=worldZ-2

local y = 0 --Necessary: Y differential for builder

--Returns a random value/stack pair from loot table
local function genLoot()
	local miniTab = lootTab[math.random(1,#lootTab)]
	local lootA = miniTab[1]
	local lootB = miniTab[2]
	return lootA,lootB
end

--Generates an NBT tag for the chest creator
local function formatLoot(seed)
	local lstr = ""
	local strintab = {28,28}
	math.randomseed(ransack*seed)
	local lootCount = math.random(3,5) --How many loot items to gen
	for i = 1,lootCount do
		ltitem,ltcount = genLoot()
		lstr = lstr.."{id:"
		lstr = lstr..ltitem
		lstr = lstr..",Slot:"
		local runr = math.random(0,26)
		lstr = lstr..runr
		lstr = lstr..",Count:"
		local howmany = math.random(1,ltcount)
		lstr = lstr..howmany
		lstr = lstr.."}"
		if i < lootCount then
			lstr = lstr..","
		end
	end
	term.setCursorPos(30,2)
	term.write(lstr)
	return lstr
end

--Creates a chest at coordinates using randomly generated loot
local function genLootChest(x,y,z,seeder)
	local loot = formatLoot(seeder)
	commands.summon("FallingSand",xx+x,yy+y+1,zz+z,"{TileID:54,Time:1,TileEntityData:{Items:["..loot.."]}}")
	term.setCursorPos(30,3)
	term.write("[GEN] Chest placed!")
end

--Column generator with relative coordinates, credit Kaikaku
local function buildCol(x,y,z,tTab)
  for iy=1,#tTab,1 do
    commands.setBlock(xx+x, yy+y+iy, zz+z, tTab[iy][1],tTab[iy][2])
  end 
end

--
function mtToWorld()
	for z = 2,MY-1 do
		for x = 2,MX-1 do
			if mt[x][z]["tile"]["type"] == "wall" then
			    buildCol(x,y,z,w1)
			elseif mt[x][z]["tile"]["type"] == "edgedoor" then
			    buildCol(x,y,z,w5)
			elseif mt[x][z]["tile"]["type"] == "doorclosed" then
				buildCol(x,y,z,w4)
			elseif mt[x][z]["tile"]["type"] == "chest" then
				buildCol(x,y,z,w3)
				basesum = z*(MX+MY)+x
				genLootChest(x,y+1,z,basesum)
			else
				buildCol(x,y,z,w3)
			end
		end
	end
end

--End command blocky stuff

buildBaseLevel()
populateLevel()
renderLevel()		
term.setCursorPos(30,1)
local input = read()
if input == "flushtofile" then
	local h = fs.open("levelfile","w")
	bin = mtToBinary()
	h.writeLine(MX-2)
	h.writeLine(MY-2)
	h.writeLine(bin)
	h.close()
	term.clear()
end
if input == "burntodisk" then
	if fs.isDir("disk") then
		if fs.exists("disk/levelfile") then
			fs.delete("disk/levelfile")
		end
		h = fs.open("disk/levelfile","w")
		bin = mtToBinary()
		h.writeLine(MX-2)
		h.writeLine(MY-2)
		h.writeLine(bin)
		h.close()
	    term.clear()
	end
end
if input == "burntoworld" then
	mtToWorld()
end
term.clear()
term.setCursorPos(1,1)


















