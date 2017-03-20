State = savestate.create(1)
savestate.load(State)

Player = 1
MaxEnemies = 5
LeftMargin = 10
TopMargin = 40
LineHeight = 10
MaxDistance = 255

ButtonNames = {
    "A",
    "B",
    "Up",
    "Down",
    "Left",
    "Right",
}

NumInputs = 5
NumOutputs = 3
--network = makeNeuralNet(NumInputs, NumOutputs)



init_time = os.time()

BoxRadius = 6
InputSize = (BoxRadius*2+1)*(BoxRadius*2+1)

function getMario()
	marioX = memory.readbyte(0x6D) * 0x100 + memory.readbyte(0x86)
	marioY = memory.readbyte(0x03B8)+16
	
	screenX = memory.readbyte(0x03AD)
	screenY = memory.readbyte(0x03B8)
end

function getTile(dx, dy)
	local x = marioX + dx + 8
	local y = marioY + dy - 16
	local page = math.floor(x/256)%2
    -- 0x0500-0x069F	Current tile
    -- terrain is at 0x5B0-0x5CF and 0x680-0x69F (two rows)
    -- 0x500-0x5DF First screen 16x13
    -- 0x5E0-0x69F Second screen 16x13
	local subx = math.floor((x%256)/16)
	local suby = math.floor((y - 32)/16)
	local addr = 0x500 + page*13*16+suby*16+subx
		
	if suby >= 13 or suby < 0 then
		return 0
	end
		
    local tileContent = memory.readbyte(addr)
	if tileContent ~= 0 then
		return 1
	else
		return 0
	end
end

function getSprites()
	local sprites = {}
	for slot=0,4 do
		-- 0x000F-0x0013 Enemy active?
		local enemy = memory.readbyte(0xF+slot)
		if enemy ~= 0 then
			-- 0x006E-0x0072 Enemy horizontal position in level
			-- 0x0087/B	Enemy x position on screen
			local inLevel = memory.readbyte(0x6E + slot)
			local onScreen = memory.readbyte(0x87 + slot)
			local ex = inLevel * 0x100 + onScreen
			-- 0x00CF-0x00D3	Enemy y pos on screen (multiply with value at 0x00B6/A to get level y pos)
			local ey = memory.readbyte(0xCF + slot) + 24
			
			--emu.print(ex .. ' ' .. ey .. ' ' .. inLevel .. ' ' .. onScreen)
			sprites[#sprites+1] = { x = ex, y = ey }
		end
	end

	-- emu.print('Found ' .. #sprites .. ' sprites')
		
	return sprites
end

function getExtendedSprites()
	return {}
end

function getMarioState()
		-- 0x000E	Player's state
		local states = { 
			'Leftmost of screen',
			'Climbing vine',
			'Entering reversed-L pipe',
			'Going down a pipe',
			'Autowalk',
			'Autowalk',
			'Player dies',
			'Entering area',
			'Normal',
			'Cannot move',
			--' ',
			'Dying',
			'Palette cycling, can\'t move'
		}
		local stateCode = memory.readbyte(0xE)

    return states[stateCode]
end


function getInputs()
	getMario()
	
	sprites = getSprites()
	extended = getExtendedSprites()
	
	local inputs = {}
	
	for dy=-BoxRadius*16,BoxRadius*16,16 do
		for dx=-BoxRadius*16,BoxRadius*16,16 do
			inputs[#inputs+1] = 0
			
			tile = getTile(dx, dy)
			if tile == 1 and marioY+dy < 0x1B0 then
				inputs[#inputs] = 1
			end
			
			for i = 1,#sprites do
				distx = math.abs(sprites[i]["x"] - (marioX+dx))
				disty = math.abs(sprites[i]["y"] - (marioY+dy))
				if distx <= 8 and disty <= 8 then
					inputs[#inputs] = -1
				end
			end
		end
	end
	
	--mariovx = memory.read_s8(0x7B)
	--mariovy = memory.read_s8(0x7D)
	
	return inputs
end

while true do
	emu.print('Hello, frame!')

	getMario()
	sprites = getSprites()

	emu.print('MarioXY ' .. marioX .. ' ' .. marioY)

	if os.time() - init_time > .05 then
		init_time = os.time()
	end
    
    local padInput = joypad.get(Player)
 	print(padInput)
    
    gui.text(LeftMargin, TopMargin, 'Mario ' .. (string.format('%d, %d', marioX, marioY) or 'NaN'))
 	for i = 1, MaxEnemies do
 		local text = sprites[i] and string.format('%d, %d', sprites[i].x, sprites[i].y) or 'NaN'
 		gui.text(LeftMargin, TopMargin + (i*LineHeight), 'Sprite' .. i .. ' ' .. text)
  	end

	--gui.text(12, 50, 'SpriteX ' .. (sprites and #sprites > 0 and sprites[1].x or 'NaN'))
	--gui.text(12, 60, 'MarioX ' .. (marioX or 'NaN'))
    --gui.text(12, 80, 'State ' .. (states and #states > 0 or 'NaN'))

	emu.frameadvance()
end