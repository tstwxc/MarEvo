_player = 1
_maxEnemies = 5
_leftMargin = 20
_topMargin = 40
_bottomMargin = 240
_lineHeight = 10
_maxDist = 255
_maxTime = 400
_maxEvals = 750
_endLevel = 3000
_endLevelBonus = 1000
_smallBonus = 0
_bigBonus = 50
_fieryBonus = 100
_coinBonus = 10
_boxRadius = 5
_numTiles = (_boxRadius*2+1)*(_boxRadius*2+1)

_numInputs = _maxEnemies + _numTiles
_numHidden = 5
_numOutputs = 3

--			|hidden weights| + |hidden bias| + |out weights| + |out bias|
_genomeSize = _numHidden * _numInputs + _numHidden + _numOutputs * _numHidden + _numOutputs
_maxGenerations = 100

_curOffspring = 1
_generationCount = 1

_generationStats = {}

_frameCounter = 0