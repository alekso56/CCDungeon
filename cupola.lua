--CUPOLA Binary Matrix Interpreter
--Reads files in the following format:
--X DIMENSION
--Y DIMENSION
--Binary data in XY format

local function submove(dir)
	if dir == "f" then
		return turtle.forward()
	elseif dir == "b" then
		return turtle.back()
	elseif dir == "u" then
		return turtle.up()
	elseif dir == "d" then
		return turtle.down()
	else
		return true
	end
end
local function moveFu(dir)
	local worked = submove(dir)
	if worked == false then
		for i = 1,16 do
			turtle.select(i)
			turtle.refuel()
		end
		turtle.select(1)
		local try = submove(dir)
		if try == false then
			print("Refuel then press Enter!")
			read()
			for i = 1,16 do
			turtle.select(i)
			turtle.refuel()
			end
			turtle.select(1)
			submove(dir)
		end
	end
end

local params = {...}
local datafile = params[1]
local nerizu = params[2]
if fs.exists(datafile) then
	if nerizu == "preview" then -- Preview of a level file
		term.clear()
		term.setCursorPos(1,1)
		print("To exit preview mode, press an ALT key.")
		print("Use the up and down keys to navigate")
		print("the preview of the level file.")
		print("The > represents the location and")
		print("orientation of the turtle relative to")
		print("the level when it is printed to world.")
		print("Press any key to continue...")
		os.pullEvent("key")
		local hdl = fs.open(datafile,"r")
		local xDim = tonumber(hdl.readLine())
		local yDim = tonumber(hdl.readLine())
		local bindata = hdl.readLine()
		local monx,mony = term.getSize()
		local linetab = {}
		for y = 1,yDim do
			linetab[y] = ""
			for x = 1,xDim do
				local gratis = ((y-1)*xDim)+x
				local target = string.sub(bindata,gratis,gratis)
				term.setCursorPos(x+1,(y+1))
				if target == "1" then
					linetab[y] = linetab[y].."#"
				else
					linetab[y] = linetab[y].."."
				end
			end
		end
		linetab[1] = ">"..string.sub(linetab[1],2)
		local startpoint = 0
		local keyout = false
		term.clear()
		term.setCursorPos(1,1)
		for i = startpoint,startpoint+12 do
			print(linetab[i])
		end
		repeat
			local event,key = os.pullEvent("key")
			term.setCursorPos(36,1)
			term.write(key)
			if key == 208 then
				startpoint = startpoint + 1
			elseif key == 200 then
				if startpoint>0 then startpoint = startpoint-1 end
			elseif key == 56 or key == 184 then
				keyout = true
				break
			end
			term.clear()
			term.setCursorPos(1,1)
			for i = startpoint,startpoint+12 do
				print(linetab[i])
			end
		until keyout == true
		term.clear()
		term.setCursorPos(1,1)
	else
	local hdl = fs.open(datafile,"r")
	local xDim = tonumber(hdl.readLine())
	local yDim = tonumber(hdl.readLine())
	print(xDim)
	print(yDim)
	local bindata = hdl.readLine()
	hdl.close()
	local xcursor = 1
	local ycursor = 1
	local flipbit = false
	turtle.select(1)
	for y = 1,yDim do
		for x = 1,xDim do
		    local gratis = ((y-1)*xDim)+x
			print(string.sub(bindata,gratis,gratis))
			if string.sub(bindata,gratis,gratis) == "1" then
			if turtle.placeDown() == false and turtle.getItemCount(1) == 0 then
				for i = 2,16 do
					turtle.select(i)
					if turtle.getItemCount(i) > 0 then
					turtle.transferTo(1)
					end
				end
				turtle.select(1)
				turtle.placeDown()
			end
			end
			if x < xDim then
			moveFu("f")
			end
		end
		for x = 1,xDim-1 do
			moveFu("b")
		end
		if y < yDim then
			turtle.turnRight()
			moveFu("f")
			turtle.turnLeft()
		end
	end
	end
end
			