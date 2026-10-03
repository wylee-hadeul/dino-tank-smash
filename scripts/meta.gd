extends RefCounted
## 아웃게임 영구 강화 (골드로 구매). 레벨은 저장 파일에 남는다.

const LIST := [
	{"id": "hp", "name": "체력 단련", "desc": "기본 최대 체력\n+12", "base": 30, "max": 10, "col": Color("5ee35e")},
	{"id": "bite", "name": "이빨 연마", "desc": "물기 데미지\n+10%", "base": 40, "max": 10, "col": Color("ff5252")},
	{"id": "armor", "name": "강철 비늘", "desc": "받는 데미지\n-4%", "base": 50, "max": 8, "col": Color("b0bec5")},
	{"id": "roar", "name": "포효 수련", "desc": "시작 포효 게이지 +20%\n포효 데미지 +10%", "base": 60, "max": 5, "col": Color("ffa726")},
	{"id": "speed", "name": "순발력", "desc": "이동 속도\n+5%", "base": 40, "max": 5, "col": Color("4fc3f7")},
	{"id": "gold", "name": "황금 발톱", "desc": "획득 골드\n+15%", "base": 50, "max": 8, "col": Color("ffd54f")},
	{"id": "luck", "name": "행운", "desc": "강화 카드 선택지\n+1장", "base": 400, "max": 1, "col": Color("ce93d8")},
	{"id": "revive", "name": "불사조 심장", "desc": "스테이지마다\n1회 부활", "base": 350, "max": 1, "col": Color("ff8a65")},
]


static func find(id: String) -> Dictionary:
	for u in LIST:
		if u.id == id:
			return u
	return {}


static func cost(u: Dictionary, level: int) -> int:
	return int(round(u.base * pow(1.45, level)))


static func gold_mult(levels: Dictionary) -> float:
	return 1.0 + 0.15 * levels.get("gold", 0)
