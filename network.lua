do

	local Network = torch.class('Network')

	function Network:__init(nin, nhidden, nout)
		self.nin = nin
		self.nhidden = nhidden
		self.nout = nout

		net = nn.Sequential()
		-- hidden layer
		net:add(nn.Linear(nin, nhidden))
		net:add(nn.HardTanh())

		-- output layer
		net:add(nn.Linear(nhidden, nout))
		net:add(nn.HardTanh())

		self.net = net
	end

	function Network:feed(input)
		return self.net:forward(input)
	end

	function Network:setWeights(weights)
		weights = weights:reshape(weights:size(1), 1):t()

		local weightsHid = weights:sub(1, 1, 1, self.nhidden * self.nin):reshape(self.nhidden, self.nin)
		-- nhidden x nin
		self.net.modules[1].weight = weightsHid

		local nextIndex = self.nhidden * self.nin + 1

		local biasHid = weights:sub(1, 1, nextIndex, nextIndex + self.nhidden - 1):reshape(self.nhidden)
		-- nhidden x 1
		self.net.modules[1].bias = biasHid

		nextIndex = nextIndex + self.nhidden

		local weightsOut = weights:sub(1, 1, nextIndex, nextIndex + self.nout * self.nhidden - 1):reshape(self.nout, self.nhidden)
		-- nout x nhidden
		self.net.modules[3].weight = weightsOut

		nextIndex = nextIndex + self.nout * self.nhidden

		local biasOut = weights:sub(1, 1, nextIndex, nextIndex + self.nout - 1):reshape(self.nout)
		-- nout x 1
		self.net.modules[3].bias = biasOut
	end

	function Network:getWeights()
		local weightsHid = self.net.modules[1].weights:reshape(1, self.nin * self.nhidden)
		local biasHid = self.net.modules[1].bias:reshape(1, self.nhidden)
		local weightsOut = self.net.modules[3].bias:reshape(1, self.nhidden * self.nout)
		local biasOut = self.net.modules[3].bias:reshape(1, self.nout)

		return weightsHid, biasHid, weightsOut, biasOut
	end

	function Network:reset()
		self.net:reset()
	end

end

return Network
