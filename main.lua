require 'torch'
require 'rnn'

Inputs = require './inputs'
Helpers = require './helpers'
Globals = require './globals'
Network = require './network'
CMAES = require './cmaes'

_stateNum = 1
_state = savestate.create(_stateNum)
savestate.load(_state)

_nn = Network(_numInputs, _numHidden, _numOutputs)

_cmaes = CMAES(_genomeSize)
_lambda = _cmaes.lambda
_offspring = _cmaes:generateOffspring()

_nn:setWeights(_offspring[_curOffspring].genome)

emu.speedmode('maximum')

while true do
  
	local mario = Inputs.getMario()

	local marioState = Inputs.getMarioState()
   --print ('Mario has state ' .. marioState)
	local marioDead = marioState == 'Dying' or marioState == 'Player dies'
  
  local marioPowerupState = Inputs.getMarioPowerupState()
  local bigScore = 0
  local fieryScore = 0
  
  if marioPowerupState == 'Big' then
    bigScore = _bigBonus
  elseif marioPowerupState == 'Fiery' then
    fieryScore = _fieryBonus
  end 
    
  --print ('Mario has powerup state ' .. marioPowerupState)

	gui.text(_leftMargin, _bottomMargin - 3*_lineHeight, 'Generation: ' .. _generationCount)
	gui.text(_leftMargin, _bottomMargin - 2*_lineHeight, 'Individual: ' .. _curOffspring)

	if _frameCounter > _maxEvals or marioDead then
		--local gameTime = Inputs.getTime()
    
    local marioScore = Inputs.getMarioScore() + mario.x + (mario.x > _endLevel and _endLevelBonus or 0) - 40
  
    local coinScore = Inputs.getCoins() * _coinBonus
    
    local powerupScore = bigScore + fieryScore

		local fitness = marioScore + powerupScore + coinScore--(_maxTime - gameTime)

    if marioDead then 
      print('Mario is dead') 
    end

		_cmaes:setFitness(_curOffspring, fitness)
    print('Gen ' .. _generationCount .. ': Offspring ' .. _curOffspring .. ' finished with fitness of ' .. fitness .. ' at x pos ' .. mario.x)

		_frameCounter = 0
		_curOffspring = _curOffspring + 1

		if _curOffspring > _lambda then
      --writeFile("backup." .. _cmaes .. "." .. '.cmaes')
      print('---- Generation ' .. _generationCount .. ' ended. ----')
			local stats = _cmaes:endGeneration()
			print('---- Best fitness for Generation ' .. _generationCount .. ' is ' .. stats.best.fitness.. ' ----')

			table.insert(_generationStats, stats)

			if _generationCount == _maxGenerations then
				_.each(_generationStats, function(k, v)
					print(string.format('%.4f', v.best.fitness))
					print(v.best.genome)
				end)
				os.exit()
			end

			_offspring = _cmaes:generateOffspring()
			_curOffspring = 1
			_generationCount = _generationCount + 1
		end

		_nn:setWeights(_offspring[_curOffspring].genome)
		savestate.load(_state)
	else
		local sprites = Inputs.getSprites()
		local distances = Inputs.getDistances(mario, sprites)
		local distancesTensor = torch.Tensor(1, 5):fill(_maxDist)
		for i = 1, #distances do
			distancesTensor[1][i] = distances[i]
		end
		distancesTensor = (distancesTensor:div(_maxDist) * 2) - 1

		if _frameCounter % 3 == 0 then
			local tiles = Inputs.getTiles(_boxRadius, mario)
			local tilesTensor = torch.Tensor(tiles):reshape(1, #tiles)

			local input = torch.cat(tilesTensor, distancesTensor)

			output = _nn:feed(input)
		end
    
    --print('A: ' .. output[1][1] .. ', Left: ' .. output[1][2] .. ', Right: ' .. output[1][3])
    
    --if #distances == 0 then
    --  joypad.set(_player, {right = 1})
    --else
    
    --if _frameCounter % 100 == 0 then
      --local randA = torch.bernoulli(0.5)
      --local randLeft = torch.bernoulli(0.5)
      --local randRight = torch.bernoulli(0.5)
      
      --joypad.set(_player, { A = (randA == 1), left = (randLeft == 1), right = (randRight == 1) })
    --else
      joypad.set(_player, { A = (output[1][1] > 0), left = (output[1][2] > 0), right = (output[1][3] > 0) })
    --end

		gui.text(_leftMargin, _topMargin, 'Mario ' .. (mario and string.format('%d, %d', mario.x, mario.y) or 'NaN'))
		for i = 1, _maxEnemies do
			local text = sprites[i] and string.format('%d, %d, %.3f', sprites[i].x, sprites[i].y, distancesTensor[1][i]) or 'NaN'
			gui.text(_leftMargin, _topMargin + (i*_lineHeight), 'Sprite' .. i .. ' ' .. text)
		end

		_frameCounter = _frameCounter + 1
	end

	emu.frameadvance()
end
