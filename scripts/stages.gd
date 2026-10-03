extends RefCounted
## 스테이지 구성: 적 등장 테이블, 난이도 배율, 보스, 테마, 보상.

const WAVES_PER_STAGE := 3

## unlock: 처음 등장하는 스테이지, w: 등장 가중치, gold: 처치 골드
const ENEMIES := {
	"light": {"name": "경전차", "unlock": 1, "w": 10.0, "gold": 3},
	"medium": {"name": "중형 전차", "unlock": 1, "w": 7.0, "gold": 5},
	"jeep": {"name": "돌격 지프", "unlock": 2, "w": 6.0, "gold": 4},
	"heli": {"name": "공격 헬기", "unlock": 3, "w": 3.5, "gold": 8},
	"heavy": {"name": "중전차", "unlock": 4, "w": 4.0, "gold": 10},
	"rocket": {"name": "로켓 트럭", "unlock": 4, "w": 3.5, "gold": 8},
	"drone": {"name": "자폭 드론", "unlock": 5, "w": 4.5, "gold": 2},
	"armored": {"name": "장갑 전차", "unlock": 6, "w": 3.0, "gold": 12},
	"bomber": {"name": "폭격기", "unlock": 7, "w": 1.5, "gold": 15},
}

const BOSSES := [
	{"name": "기가 탱크", "desc": "거대한 몸으로 돌진한다. 위에서 밟아라!"},
	{"name": "하늘 요새", "desc": "폭탄과 미사일을 퍼붓는다. 점프해서 물어라!"},
	{"name": "아이언 렉스", "desc": "레이저와 지진파! 점프로 피하라!"},
]

const THEME_NAMES := ["초원", "노을", "밤", "화산 지대"]


static func hp_mult(s: int) -> float:
	return 1.0 + 0.2 * (s - 1)


static func dmg_mult(s: int) -> float:
	return 1.0 + 0.1 * (s - 1)


## 발사 간격 배율 (작을수록 자주 쏜다)
static func fire_mult(s: int) -> float:
	return max(0.5, 1.0 - 0.05 * (s - 1))


static func boss_kind(s: int) -> int:
	return (s - 1) % BOSSES.size()


static func boss_hp_mult(s: int) -> float:
	return 1.0 + 0.4 * (s - 1)


static func wave_count(s: int, w: int) -> int:
	return 4 + s + w * 2


static func escort_count(s: int) -> int:
	return 1 + s / 3


static func max_alive(s: int) -> int:
	return min(3 + s / 2, 8)


static func spawn_interval(s: int) -> float:
	return max(0.6, 2.2 - s * 0.12)


static func clear_gold(s: int) -> int:
	return 30 + 15 * s


static func boss_gold(s: int) -> int:
	return 50 + 20 * s


static func theme(s: int) -> int:
	return (s - 1) % THEME_NAMES.size()


## 난이도 별 (1~5)
static func stars(s: int) -> int:
	return clampi(1 + (s - 1) / 2, 1, 5)


static func new_enemies(s: int) -> Array:
	var out: Array = []
	for k in ENEMIES:
		if ENEMIES[k].unlock == s:
			out.append(ENEMIES[k].name)
	return out


## 가중치 랜덤으로 적 종류를 고른다. 이번 스테이지에 새로 나온 적은 가중치 2배.
static func pick(s: int, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	var pool: Array = []
	for k in ENEMIES:
		var e: Dictionary = ENEMIES[k]
		if e.unlock > s:
			continue
		var w: float = e.w * (2.0 if e.unlock == s and s > 1 else 1.0)
		pool.append([k, w])
		total += w
	var r := rng.randf() * total
	for p in pool:
		r -= p[1]
		if r <= 0.0:
			return p[0]
	return pool[-1][0]
