extends RefCounted
## 웨이브 클리어 보상: 능력 강화 목록과 적용 로직.

const LIST := [
	{"id": "hp", "name": "THICK HIDE", "short": "HP", "desc": "Max HP +25\nFull heal", "col": Color("5ee35e"), "max": 5},
	{"id": "bite", "name": "IRON JAW", "short": "JAW", "desc": "Bite damage\n+35%", "col": Color("ff5252"), "max": 5},
	{"id": "reach", "name": "LONG NECK", "short": "REACH", "desc": "Bite range\n+25%", "col": Color("ffb74d"), "max": 3},
	{"id": "speed", "name": "SWIFT LEGS", "short": "SPD", "desc": "Move speed\n+15%", "col": Color("4fc3f7"), "max": 3},
	{"id": "jump", "name": "SPRING LEGS", "short": "STOMP", "desc": "Jump +12%\nStomp damage +50%", "col": Color("ba68c8"), "max": 3},
	{"id": "roar", "name": "BIG LUNGS", "short": "ROAR", "desc": "Roar charges 40% faster\nRoar damage +30%", "col": Color("ffa726"), "max": 4},
	{"id": "armor", "name": "SCALE ARMOR", "short": "ARMOR", "desc": "Damage taken\n-15%", "col": Color("b0bec5"), "max": 4},
	{"id": "vamp", "name": "HUNGER", "short": "VAMP", "desc": "Heal 4 HP\nper kill", "col": Color("e57373"), "max": 4},
	{"id": "reflect", "name": "RICOCHET", "short": "RICO", "desc": "Reflected shells\ndamage +60%", "col": Color("80deea"), "max": 3},
	{"id": "frenzy", "name": "FRENZY", "short": "FRENZY", "desc": "Bite cooldown\n-18%", "col": Color("fff176"), "max": 3},
	{"id": "regen", "name": "REGENERATE", "short": "REGEN", "desc": "Recover\n1.5 HP / sec", "col": Color("aed581"), "max": 3},
]


static func find(id: String) -> Dictionary:
	for u in LIST:
		if u.id == id:
			return u
	return {}


## 최대 레벨이 아닌 강화 중 n개를 무작위로 뽑는다.
static func roll(levels: Dictionary, n: int, rng: RandomNumberGenerator) -> Array:
	var pool: Array = []
	for u in LIST:
		if levels.get(u.id, 0) < u.max:
			pool.append(u)
	var out: Array = []
	while out.size() < n and not pool.is_empty():
		out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return out
