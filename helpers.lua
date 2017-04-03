local helpers = {}

helpers.distance = function(a, b)
	return torch.sqrt(torch.pow(a.x - b.x, 2) + torch.pow(a.y - b.y, 2))
end

return helpers
