extends Node
## 같이 하기 (최대 4명). 방장이 적/포탄/웨이브를 계산하고 참가자는 자기 공룡만 움직인다.
##  - 방장 → 참가자: 스냅샷(공룡/적/포탄/위험지대/점수), 연출 이벤트(폭발/소리/흔들림), RPC(피해/넉백/회복/부활 등)
##  - 참가자 → 방장: 내 공룡 상태, 행동(물기/포효)

const NetScript = preload("res://scripts/net.gd")
const DinoScript = preload("res://scripts/dino.gd")
const TankScript = preload("res://scripts/tank.gd")
const HeliScript = preload("res://scripts/heli.gd")
const DroneScript = preload("res://scripts/drone.gd")
const BomberScript = preload("res://scripts/bomber.gd")
const BossScript = preload("res://scripts/boss.gd")
const ShellScript = preload("res://scripts/shell.gd")

const SYNC := 1.0 / 15.0
const COLORS := ["green", "blue", "orange", "pink"]

## 적 종류별로 동기화하는 속성
const FIELDS := {
	"tank": ["dir", "barrel_angle", "hp", "max_hp", "flash", "stun", "recoil", "volley_left", "vel_x", "tread_phase"],
	"heli": ["hp", "max_hp", "flash", "dir", "vel_x"],
	"drone": ["hp", "max_hp", "flash", "mode", "vel"],
	"bomber": ["hp", "max_hp", "flash", "dir", "warn_t"],
	"boss": ["hp", "max_hp", "flash", "state", "state_t", "dir", "jaw", "walk", "charge_dir", "barrel_angle", "stun", "laser_from"],
	"shell": ["vel", "style", "reflected", "big", "grav"],
}

var main
var net
var roster: Array = []     # [{id, nick}] 첫 번째가 방장
var room_stage := 1
var host_id := ""
var next_id := 1
var sync_t := 0.0
var events: Array = []     # 방장: 다음 스냅샷에 실어 보낼 연출
var picked := {}           # 강화 카드를 고른 사람
var pick_wait := 0.0
var puppets := {}          # 참가자: id -> 노드


func _ready() -> void:
	net = NetScript.new()
	add_child(net)
	net.joined.connect(_on_joined)
	net.left.connect(_on_left)
	net.received.connect(_on_msg)


func _process(_delta: float) -> void:
	# 방장: 방이 열리면 자기 자신을 맨 앞에 넣는다
	if net.is_host and net.status == "hosting" and (roster.is_empty() or roster[0].id != net.my_id):
		roster.insert(0, {"id": net.my_id, "nick": "공룡 1"})
		for i in roster.size():
			roster[i].nick = "공룡 %d" % (i + 1)
		_broadcast_roster()


func my_id() -> String:
	return net.my_id if net.active() else "local"


func is_host() -> bool:
	return main.mode == "host"


func is_guest() -> bool:
	return main.mode == "guest"


# ------------------------------------------------------------------ 방

func create_room() -> void:
	var code := "%04d" % (randi() % 10000)
	if main.autoplay and main.autoplay.room_code != "":
		code = main.autoplay.room_code
	net.host(code)
	roster = []
	room_stage = main.unlocked
	main.set_state(main.State.ROOM)
	main.dlog("create room %s" % code)


func join_room(code: String) -> void:
	net.join(code)
	roster = []
	main.dlog("join room %s" % code)


func leave_room() -> void:
	net.leave()
	roster = []
	if main.mode != "solo":
		main.mode = "solo"
		main.goto_lobby()
	else:
		main.set_state(main.State.LOBBY)


func set_room_stage(s: int) -> void:
	room_stage = clampi(s, 1, main.unlocked)
	_broadcast_roster()


func host_start(s: int) -> void:
	if roster.is_empty():
		roster = [{"id": net.my_id, "nick": "공룡 1"}]
	room_stage = s
	net.send("*", {"t": "start", "s": s, "roster": roster})
	_begin(s, "host")


func _begin(s: int, mode: String) -> void:
	main.mode = mode
	puppets.clear()
	next_id = 1
	events.clear()
	main.start_stage(s)


func _broadcast_roster() -> void:
	if net.is_host:
		net.send("*", {"t": "roster", "list": roster, "stage": room_stage})


func slot_of(id: String) -> int:
	for i in roster.size():
		if roster[i].id == id:
			return i
	return 0


## 다른 사람들의 공룡(표시/대리 객체) 생성
func spawn_remote_dinos() -> void:
	for i in roster.size():
		var e: Dictionary = roster[i]
		if e.id == my_id():
			main.dino.slot = i
			main.dino.nick = "나"
			main.dino.position.x = main.view.x * (0.3 + 0.13 * i)  # 순번별로 떨어져서 시작
			continue
		var d = DinoScript.new()
		d.main = main
		d.is_remote = true
		d.net_id = e.id
		d.slot = i
		d.nick = e.nick
		d.position = Vector2(main.view.x * (0.3 + 0.13 * i), main.ground_y)
		d.net_pos = d.position
		main.world.add_child(d)
		main.dinos.append(d)


func remote_dino(id: String):
	for d in main.dinos:
		if d.is_remote and d.net_id == id:
			return d
	return null


# ------------------------------------------------------------------ 방장

## 적/포탄에 네트워크 id 부여
func tag(node, kind: String) -> void:
	if not is_host():
		return
	node.set_meta("nid", next_id)
	node.set_meta("nkind", kind)
	next_id += 1


func rec(e: Array) -> void:
	if is_host() and events.size() < 200:
		events.append(e)


func recfx(fname: String, args: Array) -> void:
	if not is_host():
		return
	var a: Array = []
	for v in args:
		if typeof(v) == TYPE_VECTOR2:
			a.append([snappedf(v.x, 0.1), snappedf(v.y, 0.1)])
		elif typeof(v) == TYPE_COLOR:
			a.append([snappedf(v.r, 0.01), snappedf(v.g, 0.01), snappedf(v.b, 0.01), snappedf(v.a, 0.01)])
		else:
			a.append(v)
	rec(["fx", fname, a])


func send_rpc(id: String, d: Dictionary) -> void:
	if is_host():
		d["t"] = "rpc"
		net.send(id, d)


func _ser(node) -> Array:
	var kind: String = node.get_meta("nkind")
	var row: Array = [node.get_meta("nid"), kind, snappedf(node.position.x, 0.1), snappedf(node.position.y, 0.1)]
	match kind:
		"tank", "boss":
			row.append(node.kind)
		_:
			row.append(0)
	var key: String = kind if kind != "tank" else "tank"
	for f in FIELDS[key]:
		var v = node.get(f)
		if typeof(v) == TYPE_VECTOR2:
			row.append([snappedf(v.x, 0.1), snappedf(v.y, 0.1)])
		elif typeof(v) == TYPE_FLOAT:
			row.append(snappedf(v, 0.01))
		else:
			row.append(v)
	return row


func _dino_row(d) -> Array:
	return [d.net_id if d.is_remote else my_id(), snappedf(d.position.x, 0.1), snappedf(d.position.y, 0.1), snappedf(d.vel.x, 1), snappedf(d.vel.y, 1),
		d.facing, snappedf(d.hp, 0.1), d.max_hp, int(d.dead), snappedf(d.bite_t, 0.01), snappedf(d.roar_t, 0.01), int(d.on_ground), snappedf(d.roar_meter, 0.1)]


func _snapshot() -> Dictionary:
	var ents: Array = []
	for arr in [main.tanks, main.helis]:
		for n in arr:
			if not n.dead and n.has_meta("nid"):
				ents.append(_ser(n))
	var sh: Array = []
	for s in main.shells:
		if not s.dead and s.has_meta("nid"):
			sh.append(_ser(s))
	var ds: Array = []
	for d in main.dinos:
		ds.append(_dino_row(d))
	var snap := {"t": "s", "d": ds, "e": ents, "sh": sh, "hz": main.hazards.items,
		"sc": main.score, "k": main.kills, "g": main.run_gold, "w": main.wave, "cb": main.combo,
		"bn": main.banner_text, "bt": snappedf(main.banner_t, 0.01), "ev": events}
	events = []
	return snap


func host_update(delta: float) -> void:
	sync_t -= delta
	if sync_t <= 0.0:
		sync_t = SYNC
		net.send("*", _snapshot())
	if main.state == main.State.UPGRADE:
		pick_wait -= delta
		var all := true
		for e in roster:
			if not picked.has(e.id):
				all = false
		if all or pick_wait <= 0.0:
			_resume_after_upgrade()


func begin_upgrade() -> void:
	picked.clear()
	pick_wait = 20.0
	net.send("*", {"t": "upgrade"})


func on_local_picked() -> void:
	if is_host():
		picked[my_id()] = true
	elif is_guest():
		net.send(host_id, {"t": "picked"})


func _resume_after_upgrade() -> void:
	main.state = main.State.PLAYING
	main.next_wave_t = 1.4
	net.send("*", {"t": "resume"})


func send_end(cleared: bool) -> void:
	net.send("*", {"t": "end", "c": cleared, "sc": main.score, "k": main.kills, "g": main.run_gold, "w": main.wave})


# ------------------------------------------------------------------ 참가자

func guest_update(delta: float) -> void:
	sync_t -= delta
	if sync_t <= 0.0:
		sync_t = SYNC
		var d = main.dino
		net.send(host_id, {"t": "d", "x": snappedf(d.position.x, 0.1), "y": snappedf(d.position.y, 0.1), "vx": snappedf(d.vel.x, 1), "vy": snappedf(d.vel.y, 1),
			"f": d.facing, "hp": snappedf(d.hp, 0.1), "mhp": d.max_hp, "dead": int(d.dead), "bt": snappedf(d.bite_t, 0.01), "rt": snappedf(d.roar_t, 0.01),
			"og": int(d.on_ground), "rm": snappedf(d.roar_meter, 0.1)})


func send_bite(rect: Rect2, dmg: float, facing: float) -> void:
	net.send(host_id, {"t": "bite", "r": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "dmg": dmg, "f": facing})


func send_roar(dmg: float) -> void:
	net.send(host_id, {"t": "roar", "dmg": dmg})


func _make_puppet(kind: String, sub) -> Node:
	var n
	match kind:
		"tank":
			n = TankScript.new()
			n.main = main
			n.setup(str(sub))
		"heli":
			n = HeliScript.new()
		"drone":
			n = DroneScript.new()
		"bomber":
			n = BomberScript.new()
		"boss":
			n = BossScript.new()
			n.main = main
			n.setup(int(sub), main.stage)
		_:
			n = ShellScript.new()
	n.main = main
	n.set_meta("puppet", true)
	return n


func _apply_snapshot(s: Dictionary) -> void:
	if main.state != main.State.PLAYING and main.state != main.State.UPGRADE:
		return
	# 공룡
	for row in s.d:
		var id: String = str(row[0])
		if id == my_id():
			continue
		var d = remote_dino(id)
		if d == null:
			continue
		d.net_pos = Vector2(row[1], row[2])
		d.vel = Vector2(row[3], row[4])
		d.facing = float(row[5])
		d.hp = float(row[6])
		d.max_hp = float(row[7])
		d.dead = bool(row[8])
		d.bite_t = float(row[9])
		d.roar_t = float(row[10])
		d.on_ground = bool(row[11])
		d.roar_meter = float(row[12])
	# 적/포탄
	var seen := {}
	for row in s.e + s.sh:
		var nid: int = int(row[0])
		seen[nid] = true
		var kind: String = row[1]
		var n = puppets.get(nid)
		if n == null or not is_instance_valid(n):
			n = _make_puppet(kind, row[4])
			n.position = Vector2(row[2], row[3])
			puppets[nid] = n
			main.world.add_child(n)
			if kind == "shell":
				main.shells.append(n)
			elif kind in ["heli", "drone", "bomber"] or (kind == "boss" and n.is_air):
				main.helis.append(n)
			else:
				main.tanks.append(n)
			if kind == "boss":
				main.boss = n
		n.set_meta("net_pos", Vector2(row[2], row[3]))
		var fields: Array = FIELDS[kind]
		for i in fields.size():
			var v = row[5 + i]
			if typeof(v) == TYPE_ARRAY:
				v = Vector2(v[0], v[1])
			n.set(fields[i], v)
	for nid in puppets.keys():
		if not seen.has(nid):
			var n = puppets[nid]
			if is_instance_valid(n):
				n.dead = true
				if n == main.boss:
					main.boss = null
			puppets.erase(nid)
	main.hazards.items = s.hz
	main.score = int(s.sc)
	main.kills = int(s.k)
	main.run_gold = int(s.g)
	main.wave = int(s.w)
	main.combo = int(s.cb)
	if str(s.bn) != main.banner_text or float(s.bt) > main.banner_t + 0.3:
		main.banner_text = str(s.bn)
		main.banner_t = float(s.bt)
	for e in s.ev:
		_replay(e)


## 방장이 기록한 연출 재생
func _replay(e: Array) -> void:
	match e[0]:
		"sfx":
			main.sfx.play(e[1], e[2], e[3], true)
		"shake":
			main.add_shake(e[1])
		"fx":
			var a: Array = e[2]
			for i in a.size():
				if typeof(a[i]) == TYPE_ARRAY and a[i].size() == 2:
					a[i] = Vector2(a[i][0], a[i][1])
				elif typeof(a[i]) == TYPE_ARRAY and a[i].size() == 4:
					a[i] = Color(a[i][0], a[i][1], a[i][2], a[i][3])
			main.fx.callv(e[1], a)


func _on_rpc(d: Dictionary) -> void:
	var me = main.dino
	match d.k:
		"hurt":
			me.hurt(float(d.v))
		"kb":
			me.knockback(Vector2(d.x, d.y), float(d.v))
		"gain":
			me.add_roar(float(d.v))
		"heal":
			me.heal(float(d.v))
		"kill":
			me.on_kill()
		"revive":
			if me.dead:
				me.revive()
				me.hp = me.max_hp * 0.5
		"invuln":
			me.invuln = float(d.v)
		"bounce":
			me.vel.y = -880.0
			me.position.y = min(me.position.y, float(d.v))


# ------------------------------------------------------------------ 메시지

func _on_joined(from: String) -> void:
	if net.is_host:
		main.dlog("peer connected %s" % from)
	else:
		host_id = from
		net.send(from, {"t": "hello"})
		main.set_state(main.State.ROOM)
		main.dlog("connected to host")


func _on_left(from: String) -> void:
	if net.is_host:
		for i in range(roster.size() - 1, -1, -1):
			if roster[i].id == from:
				main.menu.show_toast("%s 님이 나갔어요" % roster[i].nick)
				roster.remove_at(i)
		var d = remote_dino(from)
		if d:
			main.dinos.erase(d)
			d.queue_free()
		_broadcast_roster()
	elif from == host_id:
		leave_room()
		main.menu.show_toast("방장과 연결이 끊어졌어요")


func _on_msg(from: String, d: Dictionary) -> void:
	var t: String = str(d.get("t", ""))
	if net.is_host:
		match t:
			"hello":
				if roster.size() < 4 and main.state == main.State.ROOM:
					roster.append({"id": from, "nick": "공룡 %d" % (roster.size() + 1)})
					_broadcast_roster()
			"d":
				var rd = remote_dino(from)
				if rd:
					rd.prev_y = rd.position.y
					rd.net_pos = Vector2(d.x, d.y)
					rd.position = rd.net_pos
					rd.vel = Vector2(d.vx, d.vy)
					rd.facing = float(d.f)
					rd.hp = float(d.hp)
					rd.max_hp = float(d.mhp)
					rd.dead = bool(d.dead)
					rd.bite_t = float(d.bt)
					rd.roar_t = float(d.rt)
					rd.on_ground = bool(d.og)
					rd.roar_meter = float(d.rm)
			"bite":
				var rd = remote_dino(from)
				if rd:
					main.on_bite(Rect2(d.r[0], d.r[1], d.r[2], d.r[3]), rd, float(d.dmg))
			"roar":
				var rd = remote_dino(from)
				if rd:
					main.do_roar(rd, float(d.dmg))
			"picked":
				picked[from] = true
		return
	match t:
		"roster":
			roster = d.list
			room_stage = int(d.stage)
		"start":
			roster = d.roster
			_begin(int(d.s), "guest")
		"s":
			_apply_snapshot(d)
		"rpc":
			_on_rpc(d)
		"upgrade":
			main.open_upgrade_local()
		"resume":
			if main.state == main.State.UPGRADE:
				main.state = main.State.PLAYING
		"end":
			main.score = int(d.sc)
			main.kills = int(d.k)
			main.run_gold = int(d.g)
			main.wave = int(d.w)
			if bool(d.c):
				main._stage_clear()
			else:
				main._game_over()
		"room":
			main.mode = "solo"
			main.goto_lobby()
			main.set_state(main.State.ROOM)
		"full":
			main.menu.show_toast("방이 가득 찼어요 (최대 4명)")
			leave_room()
