extends RefCounted
## 웨이브 클리어 보상: 능력 강화 목록과 적용 로직.

const LIST := [
	{"id": "hp", "name": "두꺼운 가죽", "short": "체력", "desc": "최대 체력 +25\n체력 완전 회복", "col": Color("5ee35e"), "max": 5},
	{"id": "bite", "name": "강철 턱", "short": "턱", "desc": "물기 데미지\n+35%", "col": Color("ff5252"), "max": 5},
	{"id": "reach", "name": "긴 목", "short": "사거리", "desc": "물기 범위\n+25%", "col": Color("ffb74d"), "max": 3},
	{"id": "speed", "name": "날쌘 다리", "short": "속도", "desc": "이동 속도\n+15%", "col": Color("4fc3f7"), "max": 3},
	{"id": "jump", "name": "용수철 다리", "short": "밟기", "desc": "점프력 +12%\n밟기 데미지 +50%", "col": Color("ba68c8"), "max": 3},
	{"id": "roar", "name": "거대한 폐", "short": "포효", "desc": "포효 충전 40% 빠르게\n포효 데미지 +30%", "col": Color("ffa726"), "max": 4},
	{"id": "armor", "name": "비늘 갑옷", "short": "방어", "desc": "받는 데미지\n-15%", "col": Color("b0bec5"), "max": 4},
	{"id": "vamp", "name": "포식 본능", "short": "흡혈", "desc": "적 처치 시\n체력 4 회복", "col": Color("e57373"), "max": 4},
	{"id": "reflect", "name": "되받아치기", "short": "반사", "desc": "반사한 포탄 데미지\n+60%", "col": Color("80deea"), "max": 3},
	{"id": "frenzy", "name": "광폭화", "short": "광폭", "desc": "물기 쿨타임\n-18%", "col": Color("fff176"), "max": 3},
	{"id": "regen", "name": "재생 능력", "short": "재생", "desc": "초당 체력\n1.5 회복", "col": Color("aed581"), "max": 3},
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
