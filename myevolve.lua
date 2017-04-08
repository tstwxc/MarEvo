_buttons = {
  "A",
  "B",
  "up",
  "down",
  "left",
  "right",
}

_boxRadius = 6
_inputSize = (_boxRadius*2+1)*(_boxRadius*2+1)

_inputs = _inputSize + 1
_outputs = #_buttons

_population = 300
_deltaDisjoint = 2.0
_deltaWeights = 0.4
_deltaThreshold = 1.0

_staleGroup = 15

_mutateConnectionsChance = 0.25
_perturbChance = 0.90
_crossoverChance = 0.75
_linkMutationChance = 2.0
_nodeMutationChance = 0.50
_biasMutationChance = 0.40
_stepSize = 0.1
_disableMutationChance = 0.4
_enableMutationChance = 0.2

_timeoutConstant = 20

_maxNodes = 1000000

_score = 0

_stateNum = 1
_state = savestate.create(_stateNum)
savestate.load(_state)

function getPositions()
  marioX = memory.readbyte(0x6D) * 0x100 + memory.readbyte(0x86)
  marioY = memory.readbyte(0x03B8)+16
    
  screenX = memory.readbyte(0x03AD)
  screenY = memory.readbyte(0x03B8)
end


function getTile(dx, dy)
  local x = marioX + dx + 8
  local y = marioY + dy - 16
  local page = math.floor(x/256)%2

  local subx = math.floor((x%256)/16)
  local suby = math.floor((y - 32)/16)
  local addr = 0x500 + page*13*16+suby*16+subx
        
  if suby >= 13 or suby < 0 then
    return 0
  end
        
  if memory.readbyte(addr) ~= 0 then
    return 1
  else
    return 0
  end
end


function getSprites()
  local sprites = {}
  for slot=0,4 do
    local enemy = memory.readbyte(0xF+slot)
    if enemy ~= 0 then
      local ex = memory.readbyte(0x6E + slot)*0x100 + memory.readbyte(0x87+slot)
      local ey = memory.readbyte(0xCF + slot)+24
      sprites[#sprites+1] = {["x"]=ex,["y"]=ey}
    end
  end
      
  return sprites
end

function getExtendedSprites()
  return {}
end
function getInputs()
    getPositions()
    
    sprites = getSprites()
    extended = getExtendedSprites()
    
    local inputs = {}
    
    for dy=-_boxRadius*16,_boxRadius*16,16 do
        for dx=-_boxRadius*16,_boxRadius*16,16 do
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

            for i = 1,#extended do
                distx = math.abs(extended[i]["x"] - (marioX+dx))
                disty = math.abs(extended[i]["y"] - (marioY+dy))
                if distx < 8 and disty < 8 then
                    inputs[#inputs] = -1
                end
            end
        end
    end
    
    --mariovx = memory.read_s8(0x7B)
    --mariovy = memory.read_s8(0x7D)
    
    return inputs
end

function sigmoid(x)
    return 2/(1+math.exp(-4.9*x))-1
end


function newPool()
    local pool = {}
    pool.group = {}
    pool.generation = 0
    pool.innovation = _outputs
    pool.currentGroup = 1
    pool.currentMarioAgent = 1
    pool.currentFrame = 0
    pool.maxFitness = 0
    
    return pool
end

function newMarioAgent()
    local marioAgent = {}
    marioAgent.traits = {}
    marioAgent.fitness = 0
    marioAgent.adjustedFitness = 0
    marioAgent.nn = {}
    marioAgent.maxNeuron = 0
    marioAgent.globalRank = 0
    marioAgent.mutationRates = {}
    marioAgent.mutationRates["connections"] = _mutateConnectionsChance
    marioAgent.mutationRates["link"] = _linkMutationChance
    marioAgent.mutationRates["bias"] = _biasMutationChance
    marioAgent.mutationRates["node"] = _nodeMutationChance
    marioAgent.mutationRates["enable"] = _enableMutationChance
    marioAgent.mutationRates["disable"] = _disableMutationChance
    marioAgent.mutationRates["step"] = _stepSize
    
    return marioAgent
end

function copyMarioAgent(marioAgent)
    local marioAgent2 = newMarioAgent()
    for g=1,#marioAgent.traits do
        table.insert(marioAgent2.traits, copyTrait(marioAgent.traits[g]))
    end
    marioAgent2.maxNeuron = marioAgent.maxNeuron
    marioAgent2.mutationRates["connections"] = marioAgent.mutationRates["connections"]
    marioAgent2.mutationRates["link"] = marioAgent.mutationRates["link"]
    marioAgent2.mutationRates["bias"] = marioAgent.mutationRates["bias"]
    marioAgent2.mutationRates["node"] = marioAgent.mutationRates["node"]
    marioAgent2.mutationRates["enable"] = marioAgent.mutationRates["enable"]
    marioAgent2.mutationRates["disable"] = marioAgent.mutationRates["disable"]
    
    return marioAgent2
end

function basicMarioAgent()
    local marioAgent = newMarioAgent()
    local innovation = 1

    marioAgent.maxNeuron = _inputs
    mutate(marioAgent)
    
    return marioAgent
end

function mutate(marioAgent)
    for mutation,rate in pairs(marioAgent.mutationRates) do
        if math.random(1,2) == 1 then
            marioAgent.mutationRates[mutation] = 0.95*rate
        else
            marioAgent.mutationRates[mutation] = 1.05263*rate
        end
    end

    if math.random() < marioAgent.mutationRates["connections"] then
        pointMutate(marioAgent)
    end
    
    local p = marioAgent.mutationRates["link"]
    while p > 0 do
        if math.random() < p then
            linkMutate(marioAgent, false)
        end
        p = p - 1
    end

    p = marioAgent.mutationRates["bias"]
    while p > 0 do
        if math.random() < p then
            linkMutate(marioAgent, true)
        end
        p = p - 1
    end
    
    p = marioAgent.mutationRates["node"]
    while p > 0 do
        if math.random() < p then
            nodeMutate(marioAgent)
        end
        p = p - 1
    end
    
    p = marioAgent.mutationRates["enable"]
    while p > 0 do
        if math.random() < p then
            enableDisableMutate(marioAgent, true)
        end
        p = p - 1
    end

    p = marioAgent.mutationRates["disable"]
    while p > 0 do
        if math.random() < p then
            enableDisableMutate(marioAgent, false)
        end
        p = p - 1
    end
end

function pointMutate(marioAgent)
    local step = marioAgent.mutationRates["step"]
    
    for i=1,#marioAgent.traits do
        local trait = marioAgent.traits[i]
        if math.random() < _perturbChance then
            trait.weight = trait.weight + math.random() * step*2 - step
        else
            trait.weight = math.random()*4-2
        end
    end
end

function linkMutate(marioAgent, forceBias)
    local neuron1 = randomNeuron(marioAgent.traits, false)
    local neuron2 = randomNeuron(marioAgent.traits, true)
     
    local newLink = newTrait()
    if neuron1 <= _inputs and neuron2 <= _inputs then
        --Both input nodes
        return
    end
    if neuron2 <= _inputs then
        -- Swap output and input
        local temp = neuron1
        neuron1 = neuron2
        neuron2 = temp
    end

    newLink.into = neuron1
    newLink.out = neuron2
    if forceBias then
        newLink.into = _inputs
    end
    
    if containsLink(marioAgent.traits, newLink) then
        return
    end
    newLink.innovation = newInnovation()
    newLink.weight = math.random()*4-2
    
    table.insert(marioAgent.traits, newLink)
end

function nodeMutate(marioAgent)
    if #marioAgent.traits == 0 then
        return
    end

    marioAgent.maxNeuron = marioAgent.maxNeuron + 1

    local trait = marioAgent.traits[math.random(1,#marioAgent.traits)]
    if not trait.enabled then
        return
    end
    trait.enabled = false
    
    local trait1 = copyTrait(trait)
    trait1.out = marioAgent.maxNeuron
    trait1.weight = 1.0
    trait1.innovation = newInnovation()
    trait1.enabled = true
    table.insert(marioAgent.traits, trait1)
    
    local trait2 = copyTrait(trait)
    trait2.into = marioAgent.maxNeuron
    trait2.innovation = newInnovation()
    trait2.enabled = true
    table.insert(marioAgent.traits, trait2)
end

function enableDisableMutate(marioAgent, enable)
    local candidates = {}
    for _,trait in pairs(marioAgent.traits) do
        if trait.enabled == not enable then
            table.insert(candidates, trait)
        end
    end
    
    if #candidates == 0 then
        return
    end
    
    local trait = candidates[math.random(1,#candidates)]
    trait.enabled = not trait.enabled
end

function randomNeuron(traits, nonInput)
    local neurons = {}
    if not nonInput then
        for i=1,_inputs do
            neurons[i] = true
        end
    end
    for o=1,_outputs do
        neurons[_maxNodes+o] = true
    end
    for i=1,#traits do
        if (not nonInput) or traits[i].into > _inputs then
            neurons[traits[i].into] = true
        end
        if (not nonInput) or traits[i].out > _inputs then
            neurons[traits[i].out] = true
        end
    end

    local count = 0
    for _,_ in pairs(neurons) do
        count = count + 1
    end
    local n = math.random(1, count)
    
    for k,v in pairs(neurons) do
        n = n-1
        if n == 0 then
            return k
        end
    end
    
    return 0
end

function newTrait()
    local trait = {}
    trait.into = 0
    trait.out = 0
    trait.weight = 0.0
    trait.enabled = true
    trait.innovation = 0
    
    return trait
end

function copyTrait(trait)
    local trait2 = newTrait()
    trait2.into = trait.into
    trait2.out = trait.out
    trait2.weight = trait.weight
    trait2.enabled = trait.enabled
    trait2.innovation = trait.innovation
    
    return trait2
end

function containsLink(traits, link)
    for i=1,#traits do
        local trait = traits[i]
        if trait.into == link.into and trait.out == link.out then
            return true
        end
    end
end

function newInnovation()
    pool.innovation = pool.innovation + 1
    return pool.innovation
end

function addToGroup(child)
    local foundGroup = false
    for s=1,#pool.group do
        local group = pool.group[s]
        if not foundGroup and sameGroup(child, group.marioAgents[1]) then
            table.insert(group.marioAgents, child)
            foundGroup = true
        end
    end
    
    if not foundGroup then
        local childGroup = newGroup()
        table.insert(childGroup.marioAgents, child)
        table.insert(pool.group, childGroup)
    end
end

function sameGroup(marioAgent1, marioAgent2)
    local dd = _deltaDisjoint*disjoint(marioAgent1.traits, marioAgent2.traits)
    local dw = _deltaWeights*weights(marioAgent1.traits, marioAgent2.traits) 
    return dd + dw < _deltaThreshold
end

function disjoint(traits1, traits2)
    local i1 = {}
    for i = 1,#traits1 do
        local trait = traits1[i]
        i1[trait.innovation] = true
    end

    local i2 = {}
    for i = 1,#traits2 do
        local trait = traits2[i]
        i2[trait.innovation] = true
    end
    
    local disjointTraits = 0
    for i = 1,#traits1 do
        local trait = traits1[i]
        if not i2[trait.innovation] then
            disjointTraits = disjointTraits+1
        end
    end
    
    for i = 1,#traits2 do
        local trait = traits2[i]
        if not i1[trait.innovation] then
            disjointTraits = disjointTraits+1
        end
    end
    
    local n = math.max(#traits1, #traits2)
    
    return disjointTraits / n
end

function weights(traits1, traits2)
    local i2 = {}
    for i = 1,#traits2 do
        local trait = traits2[i]
        i2[trait.innovation] = trait
    end

    local sum = 0
    local coincident = 0
    for i = 1,#traits1 do
        local trait = traits1[i]
        if i2[trait.innovation] ~= nil then
            local gene2 = i2[trait.innovation]
            sum = sum + math.abs(trait.weight - gene2.weight)
            coincident = coincident + 1
        end
    end
    
    return sum / coincident
end

function newGroup()
    local group = {}
    group.topFitness = 0
    group.staleness = 0
    group.marioAgents = {}
    group.averageFitness = 0
    
    return group
end

function initializeRun()
    --savestate.load(Filename);
    rightmost = 0
    pool.currentFrame = 0
    timeout = _timeoutConstant
    clearJoypad()
    
    local group = pool.group[pool.currentGroup]
    local marioAgent = group.marioAgents[pool.currentMarioAgent]
    generateNeuralNet(marioAgent)
    evaluateCurrent()
end

function clearJoypad()
    controller = {}
    for b = 1,#_buttons do
        controller[_buttons[b]] = false
    end
    joypad.set(1,controller)
end

function generateNeuralNet(marioAgent)
    local neuralNet = {}
    neuralNet.neurons = {}
    
    for i=1,_inputs do
        neuralNet.neurons[i] = newNeuron()
    end
    
    for o=1,_outputs do
        neuralNet.neurons[_maxNodes+o] = newNeuron()
    end
    
    table.sort(marioAgent.traits, function (a,b)
        return (a.out < b.out)
    end)
    for i=1,#marioAgent.traits do
        local trait = marioAgent.traits[i]
        if trait.enabled then
            if neuralNet.neurons[trait.out] == nil then
                neuralNet.neurons[trait.out] = newNeuron()
            end
            local neuron = neuralNet.neurons[trait.out]
            table.insert(neuron.incoming, trait)
            if neuralNet.neurons[trait.into] == nil then
                neuralNet.neurons[trait.into] = newNeuron()
            end
        end
    end
    
    marioAgent.nn = neuralNet
end

function newNeuron()
    local neuron = {}
    neuron.incoming = {}
    neuron.value = 0.0
    
    return neuron
end

function evaluateCurrent()
    local group = pool.group[pool.currentGroup]
    local marioAgent = group.marioAgents[pool.currentMarioAgent]

    inputs = getInputs()
    controller = evaluateNeuralNet(marioAgent.nn, inputs)
    
    if controller["Left"] and controller["Right"] then
        controller["Left"] = false
        controller["Right"] = false
    end
    if controller["Up"] and controller["Down"] then
        controller["Up"] = false
        controller["Down"] = false
    end

    joypad.set(1, controller)
    --for b, v in pairs(controller) do 
    --  print(b,v)
    --joypad.set(1, {right = 1})
    --end
end


function evaluateNeuralNet(nn, inputs)
    table.insert(inputs, 1)
    if #inputs ~= _inputs then
        print("Incorrect number of neural net inputs.")
        return {}
    end
    
    for i=1,_inputs do
        nn.neurons[i].value = inputs[i]
    end
    
    for _,neuron in pairs(nn.neurons) do
        local sum = 0
        for j = 1,#neuron.incoming do
            local incoming = neuron.incoming[j]
            local other = nn.neurons[incoming.into]
            sum = sum + incoming.weight * other.value
        end
        
        if #neuron.incoming > 0 then
            neuron.value = sigmoid(sum)
        end
    end
    
    local outputs = {}
    for o=1,_outputs do
        local button = _buttons[o]
        if nn.neurons[_maxNodes+o].value > 0 then
            outputs[button] = true
        else
            outputs[button] = false
        end
    end
    
    return outputs
end

function fitnessAlreadyMeasured()
    local group = pool.group[pool.currentGroup]
    local marioAgent = group.marioAgents[pool.currentMarioAgent]
    
    return marioAgent.fitness ~= 0
end

function nextMarioAgent()
    pool.currentMarioAgent = pool.currentMarioAgent + 1
    if pool.currentMarioAgent > #pool.group[pool.currentGroup].marioAgents then
        pool.currentMarioAgent = 1
        pool.currentGroup = pool.currentGroup+1
        if pool.currentGroup > #pool.group then
            newGeneration()
            pool.currentGroup = 1
        end
    end
end

function newGeneration()
    cullGroup(false) -- Cull the bottom half of each group
    rankGlobally()
    removeStaleGroup()
    rankGlobally()
    for s = 1,#pool.group do
        local group = pool.group[s]
        calculateAverageFitness(group)
    end
    removeWeakGroup()
    local sum = totalAverageFitness()
    local children = {}
    for s = 1,#pool.group do
        local group = pool.group[s]
        breed = math.floor(group.averageFitness / sum * _population) - 1
        for i=1,breed do
            table.insert(children, breedChild(group))
        end
    end
    cullGroup(true) -- Cull all but the top member of each group
    while #children + #pool.group < _population do
        local group = pool.group[math.random(1, #pool.group)]
        table.insert(children, breedChild(group))
    end
    for c=1,#children do
        local child = children[c]
        addToGroup(child)
    end
    
    pool.generation = pool.generation + 1
    
    --writeFile("backup." .. pool.generation .. "." .. forms.gettext(saveLoadFile))
end

function breedChild(group)
    local child = {}
    if math.random() < _crossoverChance then
        g1 = group.marioAgents[math.random(1, #group.marioAgents)]
        g2 = group.marioAgents[math.random(1, #group.marioAgents)]
        child = crossover(g1, g2)
    else
        g = group.marioAgents[math.random(1, #group.marioAgents)]
        child = copyMarioAgent(g)
    end
    
    mutate(child)
    
    return child
end

function crossover(g1, g2)
    -- Make sure g1 is the higher fitness marioAgent
    if g2.fitness > g1.fitness then
        tempg = g1
        g1 = g2
        g2 = tempg
    end

    local child = newMarioAgent()
    
    local innovations2 = {}
    for i=1,#g2.traits do
        local trait = g2.traits[i]
        innovations2[trait.innovation] = trait
    end
    
    for i=1,#g1.traits do
        local gene1 = g1.traits[i]
        local gene2 = innovations2[gene1.innovation]
        if gene2 ~= nil and math.random(2) == 1 and gene2.enabled then
            table.insert(child.traits, copyTrait(gene2))
        else
            table.insert(child.traits, copyTrait(gene1))
        end
    end
    
    child.maxNeuron = math.max(g1.maxNeuron,g2.maxNeuron)
    
    for mutation,rate in pairs(g1.mutationRates) do
        child.mutationRates[mutation] = rate
    end
    
    return child
end


function cullGroup(cutToOne)
    for s = 1,#pool.group do
        local group = pool.group[s]
        
        table.sort(group.marioAgents, function (a,b)
            return (a.fitness > b.fitness)
        end)
        
        local remaining = math.ceil(#group.marioAgents/2)
        if cutToOne then
            remaining = 1
        end
        while #group.marioAgents > remaining do
            table.remove(group.marioAgents)
        end
    end
end

function removeStaleGroup()
    local survived = {}

    for s = 1,#pool.group do
        local group = pool.group[s]
        
        table.sort(group.marioAgents, function (a,b)
            return (a.fitness > b.fitness)
        end)
        
        if group.marioAgents[1].fitness > group.topFitness then
            group.topFitness = group.marioAgents[1].fitness
            group.staleness = 0
        else
            group.staleness = group.staleness + 1
        end
        if group.staleness < _staleGroup or group.topFitness >= pool.maxFitness then
            table.insert(survived, group)
        end
    end

    pool.group = survived
end

function removeWeakGroup()
    local survived = {}

    local sum = totalAverageFitness()
    for s = 1,#pool.group do
        local group = pool.group[s]
        breed = math.floor(group.averageFitness / sum * _population)
        if breed >= 1 then
            table.insert(survived, group)
        end
    end

    pool.group = survived
end

function rankGlobally()
    local global = {}
    for s = 1,#pool.group do
        local group = pool.group[s]
        for g = 1,#group.marioAgents do
            table.insert(global, group.marioAgents[g])
        end
    end
    table.sort(global, function (a,b)
        return (a.fitness < b.fitness)
    end)
    
    for g=1,#global do
        global[g].globalRank = g
    end
end

function calculateAverageFitness(group)
    local total = 0
    
    for g=1,#group.marioAgents do
        local marioAgent = group.marioAgents[g]
        total = total + marioAgent.globalRank
    end
    
    group.averageFitness = total / #group.marioAgents
end

function totalAverageFitness()
    local total = 0
    for s = 1,#pool.group do
        local group = pool.group[s]
        total = total + group.averageFitness
    end

    return total
end

function initializePool()
    pool = newPool()

    for i=1, _population do
        --emu.message(i)
        basic = basicMarioAgent()
        addToGroup(basic)
    end

    initializeRun()
end

if pool == nil then
    initializePool()
    emu.message(#pool.group)
end

function displayMarioAgent(marioAgent)
    local nn = marioAgent.nn
    local cells = {}
    local i = 1
    local cell = {}
    for dy=-_boxRadius,_boxRadius do
        for dx=-_boxRadius,_boxRadius do
            cell = {}
            cell.x = 50+5*dx
            cell.y = 70+5*dy
            cell.value = nn.neurons[i].value
            cells[i] = cell
            i = i + 1
        end
    end
    local biasCell = {}
    biasCell.x = 80
    biasCell.y = 110
    biasCell.value = nn.neurons[_inputs].value
    cells[_inputs] = biasCell
    
    for o = 1,_outputs do
        cell = {}
        cell.x = 220
        cell.y = 30 + 8 * o
        cell.value = nn.neurons[_maxNodes + o].value
        cells[_maxNodes+o] = cell
        local color
        if cell.value > 0 then
            color = 0xFF0000FF
        else
            color = 0xFF000000
        end
        gui.drawtext(223, 24+8*o, _buttons[o], color, 9)
        --gui.text(0, 0+8*o, _buttons[o])
    end
    
    for n,neuron in pairs(nn.neurons) do
        cell = {}
        if n > _inputs and n <= _maxNodes then
            cell.x = 140
            cell.y = 40
            cell.value = neuron.value
            cells[n] = cell
        end
    end
    
    for n=1,4 do
        for _,trait in pairs(marioAgent.traits) do
            if trait.enabled then
                local c1 = cells[trait.into]
                local c2 = cells[trait.out]
                if trait.into > _inputs and trait.into <= _maxNodes then
                    c1.x = 0.75*c1.x + 0.25*c2.x
                    if c1.x >= c2.x then
                        c1.x = c1.x - 40
                    end
                    if c1.x < 90 then
                        c1.x = 90
                    end
                    
                    if c1.x > 220 then
                        c1.x = 220
                    end
                    c1.y = 0.75*c1.y + 0.25*c2.y
                    
                end
                if trait.out > _inputs and trait.out <= _maxNodes then
                    c2.x = 0.25*c1.x + 0.75*c2.x
                    if c1.x >= c2.x then
                        c2.x = c2.x + 40
                    end
                    if c2.x < 90 then
                        c2.x = 90
                    end
                    if c2.x > 220 then
                        c2.x = 220
                    end
                    c2.y = 0.25*c1.y + 0.75*c2.y
                end
            end
        end
    end
    
    gui.drawbox(50-_boxRadius*5-3,70-_boxRadius*5-3,50+_boxRadius*5+2,70+_boxRadius*5+2,0xFF000000, 0x80808080)
    for n,cell in pairs(cells) do
        if n > _inputs or cell.value ~= 0 then
            local color = math.floor((cell.value+1)/2*256)
            if color > 255 then color = 255 end
            if color < 0 then color = 0 end
            local opacity = 0xFF000000
            if cell.value == 0 then
                opacity = 0x50000000
            end
            color = opacity + color*0x10000 + color*0x100 + color
            gui.drawbox(cell.x-2,cell.y-2,cell.x+2,cell.y+2,opacity,color)
        end
    end
    for _,trait in pairs(marioAgent.traits) do
        if trait.enabled then
            local c1 = cells[trait.into]
            local c2 = cells[trait.out]
            local opacity = 0xA0000000
            if c1.value == 0 then
                opacity = 0x20000000
            end
            
            local color = 0x80-math.floor(math.abs(sigmoid(trait.weight))*0x80)
            if trait.weight > 0 then 
                color = opacity + 0x8000 + 0x10000*color
            else
                color = opacity + 0x800000 + 0x100*color
            end
            gui.drawline(c1.x+1, c1.y, c2.x-3, c2.y, color)
        end
    end
    
    gui.drawbox(49,71,51,78,0x00000000,0x80FF0000)
    
    --[[if forms.ischecked(showMutationRates) then
        local pos = 100
        for mutation,rate in pairs(marioAgent.mutationRates) do
            gui.drawText(100, pos, mutation .. ": " .. rate, 0xFF000000, 10)
            pos = pos + 8
        end
    end]]
end

emu.speedmode('maximum')

while true do
    local group = pool.group[pool.currentGroup]
    local marioAgent = group.marioAgents[pool.currentMarioAgent]
    
    displayMarioAgent(marioAgent)
    
    if pool.currentFrame%5 == 0 then
        evaluateCurrent()
    end
    
    joypad.set(1, controller)
    
    getPositions()
    if marioX > rightmost then
        rightmost = marioX
        timeout = _timeoutConstant
    end
    
    timeout = timeout - 1
    
    local timeoutBonus = pool.currentFrame / 4
    
    if timeout + timeoutBonus <= 0 then
        local fitness = rightmost - pool.currentFrame / 2
        if rightmost > 3186 then
            fitness = fitness + 1000
        end
        if fitness == 0 then
            fitness = -1
        end
        marioAgent.fitness = fitness
        
        gui.text(0, 150, "Mario fitness: " .. marioAgent.fitness)
        
        if fitness > pool.maxFitness then
            pool.maxFitness = fitness
        end
        
        --emu.message("Gen " .. pool.generation .. " group " .. pool.currentgroup .. " marioAgent " .. pool.currentmarioAgent .. " fitness: " .. fitness)
        pool.currentGroup = 1
        pool.currentMarioAgent = 1
        while fitnessAlreadyMeasured() do
            nextMarioAgent()
        end
        savestate.load(_state)
        initializeRun()
    end

    local measured = 0
    local total = 0
    for _,group in pairs(pool.group) do
        for _,marioAgent in pairs(group.marioAgents) do
            total = total + 1
            if marioAgent.fitness ~= 0 then
                measured = measured + 1
            end
        end
    end
    
    gui.text(0, 212, "Gen: " .. pool.generation .. " || Group: " .. pool.currentGroup .. " || Agent: " .. pool.currentMarioAgent .. " || Measured: " .. math.floor(measured/total*100) .. " %")
        gui.text(0, 220, "Fitness: " .. math.floor(rightmost - (pool.currentFrame) / 2 - (timeout + timeoutBonus)*2/3) .. " || Max Fitness: " .. math.floor(pool.maxFitness))
    
    pool.currentFrame = pool.currentFrame + 1
  
    emu.frameadvance();
end

