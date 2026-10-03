extends Node2D
## 게임 전체 흐름: 로비/상점 ↔ 스테이지(웨이브 3개, 마지막은 보스), 충돌, 점수, 골드, 저장.

const DinoScript = preload("res://scripts/dino.gd")
const TankScript = preload("res://scripts/tank.gd")
const HeliScript = preload("res://scripts/heli.gd")
const DroneScript = preload("res://scripts/drone.gd")
const BomberScript = preload("res://scripts/bomber.gd")
const BossScript = preload("res://scripts/boss.gd")
const ShellScript = preload("res://scripts/shell.gd")
const FxScript = preload("res://scripts/fx.gd")
const HazardScript = preload("res://scripts/hazards.gd")
const BgScript = preload("res://scripts/background.gd")
const HudScript = preload("res://scripts/hud.gd")
const MenuScript = preload("res://scripts/menu.gd")
const TouchScript = preload("res://scripts/touch_controls.gd")
const SfxScript = preload("res://scripts/sfx.gd")
const AutoplayScript = preload("res://scripts/autoplay.gd")
const Upgrades = preload("res://scripts/upgrades.gd")
const Stages = preload("res://scripts/stages.gd")
const Meta = preload("res://scripts/meta.gd")
const CoopScript = preload("res://scripts/coop.gd")

enum State { TITLE, LOBBY, SHOP, PLAYING, UPGRADE, STAGE_CLEAR, GAMEOVER, MULTI, JOIN, ROOM }

const AIR_KINDS := ["heli", "drone", "bomber"]

var save_path := "user://save.cfg"
var state := State.TITLE
var view := Vector2(1280, 720)
var ground_y := 610.0

var bg: Node2D
var world: Node2D
var fx: Node2D
var hazards: Node2D
var hud: Node2D
var menu: Node2D
var touch: Node2D
var sfx: Node
var autoplay: Node
var dino: Node2D       # 내 공룡
var dinos: Array = []  # 같이 하기: 모든 공룡 (내 공룡 포함)
var mode := "solo"     # solo / host / guest
var coop
var actor = null       # 지금 피해를 주는 공룡 (포효 게이지/흡혈 보상 대상)
var tanks: Array = []   # 지상 적 (지상 보스 포함)
var helis: Array = []   # 공중 적 (공중 보스 포함)
var shells: Array = []
var boss = null

# 저장 데이터
var gold := 0
var meta := {}
var unlocked := 1
var best := {}
var high_score := 0

# 스테이지 진행
var stage := 1
var selected_stage := 1
var score := 0
var kills := 0
var run_gold := 0
var wave := 0
var to_spawn := 0
var spawn_timer := 0.0
var next_wave_t := 0.0
var boss_spawn_t := -1.0
var stage_clear_t := -1.0
var revive_used := false
var result := {}

var banner_text := ""
var banner_t := 0.0
var shake := 0.0
var combo := 0
var combo_t := 0.0
var gameover_t := 0.0
var time := 0.0
var rng := RandomNumberGenerator.new()
var upgrade_pending := false
var upgrade_wait := 0.0
var upgrade_choices: Array = []
var upgrade_sel := 0
var upgrade_t := 0.0


func _ready() -> void:
	ThemeDB.fallback_font = load("res://fonts/Jua-Regular.ttf")  # 한글 폰트
	rng.randomize()
	_setup_input()
	var ap_args = _autoplay_args()
	if ap_args != null:
		save_path = "user://save_autoplay.cfg"  # 테스트가 실제 저장을 건드리지 않게
		if ap_args.has("--fresh"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	_load_save()
	bg = BgScript.new()
	bg.main = self
	add_child(bg)
	world = Node2D.new()
	add_child(world)
	hazards = HazardScript.new()
	hazards.main = self
	hazards.z_index = 5
	world.add_child(hazards)
	fx = FxScript.new()
	fx.main = self
	fx.z_index = 10
	world.add_child(fx)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = HudScript.new()
	hud.main = self
	layer.add_child(hud)
	menu = MenuScript.new()
	menu.main = self
	layer.add_child(menu)
	touch = TouchScript.new()
	touch.main = self
	layer.add_child(touch)
	sfx = SfxScript.new()
	add_child(sfx)
	coop = CoopScript.new()
	coop.main = self
	add_child(coop)
	sfx.recorder = func(n, v, pt): coop.rec(["sfx", n, v, pt])
	_update_view()
	get_viewport().size_changed.connect(_update_view)
	if ap_args != null:
		autoplay = AutoplayScript.new()
		autoplay.main = self
		add_child(autoplay)
		autoplay.configure(ap_args)
	_spawn_dino(view.x * 0.5)


func _autoplay_args():
	var args := OS.get_cmdline_user_args()
	var on := args.has("--autoplay")
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("window.location.search", true)
		if typeof(q) == TYPE_STRING and q.contains("autoplay"):
			on = true
			for part in q.trim_prefix("?").split("&"):
				if part != "autoplay" and part != "":
					args.append("--" + part)
	return args if on else null


func dlog(msg: String) -> void:
	print("[%7.2f] %s" % [time, msg])


func _setup_input() -> void:
	_add_action("left", [KEY_LEFT, KEY_A])
	_add_action("right", [KEY_RIGHT, KEY_D])
	_add_action("jump", [KEY_UP, KEY_W, KEY_SPACE])
	_add_action("bite", [KEY_J, KEY_Z, KEY_F])
	_add_action("roar", [KEY_K, KEY_X, KEY_E])


func _add_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _update_view() -> void:
	view = get_viewport_rect().size
	ground_y = view.y - 110.0
	if dino:
		dino.position.y = min(dino.position.y, ground_y)
		if dino.on_ground:
			dino.position.y = ground_y
	for t in tanks:
		t.position.y = ground_y


func is_portrait() -> bool:
	return view.y > view.x * 1.05


func _spawn_dino(x: float) -> void:
	for d in dinos:
		if is_instance_valid(d) and d != dino:
			d.queue_free()
	dinos.clear()
	if dino:
		dino.queue_free()
	dino = DinoScript.new()
	dino.main = self
	dino.position = Vector2(x, ground_y)
	dino.setup_meta(meta)
	if autoplay and autoplay.god:
		dino.god = true
	world.add_child(dino)
	dinos.append(dino)
	if mode != "solo":
		coop.spawn_remote_dinos()


## 가장 가까운 살아있는 공룡 (적들이 노리는 대상). 모두 쓰러졌으면 내 공룡.
func target_for(p: Vector2):
	var best = null
	var bd := INF
	for d in dinos:
		if d.dead:
			continue
		var dd: float = abs(d.position.x - p.x)
		if dd < bd:
			bd = dd
			best = d
	return best if best else dino


func any_alive() -> bool:
	for d in dinos:
		if not d.dead:
			return true
	return false


func _clear_world() -> void:
	for arr in [tanks, helis, shells]:
		for n in arr:
			n.queue_free()
		arr.clear()
	boss = null
	fx.clear()
	hazards.clear()
	touch.release_all()


# ------------------------------------------------------------------ 화면 전환

func goto_lobby() -> void:
	_clear_world()
	state = State.LOBBY
	selected_stage = clampi(selected_stage, 1, unlocked)
	bg.theme = Stages.theme(selected_stage)
	_spawn_dino(170.0)
	menu.open()
	dlog("lobby: gold=%d unlocked=%d" % [gold, unlocked])


func set_state(s: State) -> void:
	state = s
	menu.open()


func open_shop() -> void:
	state = State.SHOP
	menu.open()


func change_stage(d: int) -> void:
	selected_stage = clampi(selected_stage + d, 1, unlocked)
	bg.theme = Stages.theme(selected_stage)


func buy_meta(id: String) -> bool:
	var u := Meta.find(id)
	var lvl: int = meta.get(id, 0)
	if u.is_empty() or lvl >= u.max:
		return false
	var c := Meta.cost(u, lvl)
	if gold < c:
		return false
	gold -= c
	meta[id] = lvl + 1
	_save()
	dino.setup_meta(meta)
	sfx.play("reflect", -4.0, 1.2)
	dlog("meta bought: %s -> Lv%d (cost %d, gold left %d)" % [id, lvl + 1, c, gold])
	return true


func start_stage(s: int) -> void:
	_clear_world()
	stage = s
	selected_stage = s
	bg.theme = Stages.theme(s)
	_spawn_dino(view.x * 0.5)
	score = 0
	kills = 0
	run_gold = 0
	wave = 0
	combo = 0
	to_spawn = 0
	gameover_t = 0.0
	next_wave_t = 1.4
	boss_spawn_t = -1.0
	stage_clear_t = -1.0
	revive_used = false
	upgrade_pending = false
	state = State.PLAYING
	show_banner("스테이지 %d" % s)
	sfx.play("roar", -4.0)
	dino.roar_t = 0.6
	dlog("stage %d start (hp x%.2f dmg x%.2f)" % [s, Stages.hp_mult(s), Stages.dmg_mult(s)])


# ------------------------------------------------------------------ 입력

func _input(event: InputEvent) -> void:
	if state == State.UPGRADE:
		_upgrade_input(event)
		return
	if state != State.TITLE or is_portrait():
		return
	var pressed := false
	if event is InputEventScreenTouch and event.pressed:
		pressed = true
	elif event is InputEventMouseButton and event.pressed:
		pressed = true
	elif event is InputEventKey and event.pressed and not event.echo:
		pressed = true
	if pressed:
		_try_fullscreen(event is InputEventScreenTouch)
		goto_lobby()
		get_viewport().set_input_as_handled()


func _try_fullscreen(is_touch: bool) -> void:
	if not is_touch or not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""
		(function(){
			var d = document.documentElement;
			var p = d.requestFullscreen ? d.requestFullscreen() : null;
			if (p && p.then) { p.then(function(){
				if (screen.orientation && screen.orientation.lock) screen.orientation.lock('landscape').catch(function(){});
			}).catch(function(){}); }
		})();
	""", true)


# ------------------------------------------------------------------ 루프

func _process(delta: float) -> void:
	delta = min(delta, 0.05)
	time += delta
	if is_portrait():
		hud.queue_redraw()
		menu.queue_redraw()
		return
	bg.update(delta)
	if mode == "host":
		coop.host_update(delta)
	elif mode == "guest":
		coop.guest_update(delta)
	if state == State.UPGRADE:
		upgrade_t += delta
	else:
		for d in dinos:
			d.update(delta)
		for t in tanks:
			t.update(delta)
		for h in helis:
			h.update(delta)
		for s in shells:
			s.update(delta)
		hazards.update(delta)
	if state == State.PLAYING and mode == "guest":
		_guest_local_rules(delta)
	elif state == State.PLAYING:
		_collisions()
		if stage_clear_t > 0.0:
			stage_clear_t -= delta
			if stage_clear_t <= 0.0:
				_stage_clear()
		else:
			_waves(delta)
		if dino.dead:
			gameover_t += delta
			var can_revive: bool = meta.get("revive", 0) > 0 and not revive_used
			if can_revive and gameover_t > 1.2:
				_revive()
			elif not can_revive and gameover_t > 1.8 and not any_alive():
				_game_over()
		elif mode == "host" and not any_alive():
			gameover_t += delta
			if gameover_t > 2.5:
				_game_over()
	elif state == State.GAMEOVER or state == State.STAGE_CLEAR:
		gameover_t += delta
		_shell_collisions()
	_cleanup()
	fx.update(delta)
	combo_t -= delta
	if combo_t <= 0.0:
		combo = 0
	banner_t = max(banner_t - delta, 0.0)
	shake = max(shake * exp(-7.0 * delta) - delta, 0.0)
	world.position = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * shake
	bg.position = world.position * 0.4
	hud.queue_redraw()
	menu.queue_redraw()
	touch.queue_redraw()


## 참가자: 내 공룡의 부활(불사조 심장)만 직접 처리한다. 나머지 규칙은 방장이 판정.
func _guest_local_rules(delta: float) -> void:
	if dino.dead:
		gameover_t += delta
		if meta.get("revive", 0) > 0 and not revive_used and gameover_t > 1.2:
			_revive()
	else:
		gameover_t = 0.0


func _alive_enemies() -> int:
	return tanks.size() + helis.size() - (1 if boss else 0)


func _waves(delta: float) -> void:
	if upgrade_pending:
		if not any_alive():
			upgrade_pending = false
			return
		upgrade_wait -= delta
		if upgrade_wait <= 0.0:
			upgrade_pending = false
			_open_upgrade()
		return
	if next_wave_t > 0.0:
		next_wave_t -= delta
		if next_wave_t <= 0.0:
			_start_wave(wave + 1)
		return
	if boss_spawn_t > 0.0:
		boss_spawn_t -= delta
		if boss_spawn_t <= 0.0:
			_spawn_boss()
	if to_spawn > 0:
		spawn_timer -= delta
		if spawn_timer <= 0.0 and _alive_enemies() < Stages.max_alive(stage):
			_spawn_enemy(Stages.pick(stage, rng))
			to_spawn -= 1
			spawn_timer = Stages.spawn_interval(stage)
	elif wave < Stages.WAVES_PER_STAGE and tanks.is_empty() and helis.is_empty() and any_alive():
		upgrade_pending = true
		upgrade_wait = 1.6
		for d in dinos:
			if d.dead and mode == "host":
				if d.is_remote:
					coop.send_rpc(d.net_id, {"k": "revive"})
				else:
					d.revive()
					d.hp = d.max_hp * 0.5
			else:
				d.heal(25)
		show_banner("웨이브 클리어!  체력 +25")
		sfx.play("reflect", -6.0, 0.7)


func _start_wave(n: int) -> void:
	wave = n
	spawn_timer = 0.4
	if n < Stages.WAVES_PER_STAGE:
		to_spawn = Stages.wave_count(stage, n)
		show_banner("웨이브 %d / %d" % [n, Stages.WAVES_PER_STAGE])
	else:
		to_spawn = Stages.escort_count(stage)
		boss_spawn_t = 2.2
		spawn_timer = 3.5
		show_banner("경고! 보스 접근 중")
		sfx.play("roar", -2.0, 0.5)
	dlog("wave %d start (enemies=%d)" % [n, to_spawn])


func show_banner(text: String) -> void:
	banner_text = text
	banner_t = 2.2


func _spawn_enemy(kind: String) -> void:
	var from_left := rng.randf() < 0.5
	var sx: float = -150.0 if from_left else view.x + 150.0
	if kind in AIR_KINDS:
		var y := ground_y - 360.0 + rng.randf_range(-25, 25)
		if kind == "drone":
			y = ground_y - 300.0
		elif kind == "bomber":
			y = ground_y - 480.0  # HUD와 겹치지 않는 높이
		spawn_air(kind, Vector2(sx, y))
		return
	var t = TankScript.new()
	t.main = self
	t.setup(kind)
	t.position = Vector2(-t.half_w - 40.0 if from_left else view.x + t.half_w + 40.0, ground_y)
	world.add_child(t)
	tanks.append(t)
	coop.tag(t, "tank")


func spawn_air(kind: String, pos: Vector2) -> void:
	var a
	match kind:
		"drone":
			a = DroneScript.new()
		"bomber":
			a = BomberScript.new()
		_:
			a = HeliScript.new()
	a.main = self
	a.position = pos
	world.add_child(a)
	helis.append(a)
	coop.tag(a, kind)


func _spawn_boss() -> void:
	var b = BossScript.new()
	b.main = self
	b.setup(Stages.boss_kind(stage), stage)
	var right: bool = dino.position.x < view.x * 0.5
	var x: float = view.x + b.half_w + 60.0 if right else -b.half_w - 60.0
	b.position = Vector2(x, ground_y - 400.0 if b.is_air else ground_y)
	world.add_child(b)
	coop.tag(b, "boss")
	if b.is_air:
		helis.append(b)
	else:
		tanks.append(b)
	boss = b
	show_banner("보스 등장!  " + b.boss_name)
	add_shake(14.0)
	sfx.play("roar", 2.0, 0.4)
	dlog("boss spawn: %s hp=%.0f" % [b.boss_name, b.max_hp])


# ------------------------------------------------------------------ 강화 카드

func _open_upgrade() -> void:
	if mode == "host":
		coop.begin_upgrade()
	open_upgrade_local()


func open_upgrade_local() -> void:
	hud.waiting_others = false
	upgrade_choices = Upgrades.roll(dino.levels, 3 + int(meta.get("luck", 0)), rng)
	if upgrade_choices.is_empty():
		next_wave_t = 1.0
		return
	state = State.UPGRADE
	upgrade_t = 0.0
	upgrade_sel = 0
	touch.release_all()
	sfx.play("reflect", -4.0, 0.5)
	dlog("upgrade offer: %s" % ", ".join(upgrade_choices.map(func(u): return u.id)))


func card_rects() -> Array:
	var n := upgrade_choices.size()
	var w: float = min(300.0, (view.x - 80.0) / n - 30.0)
	var h: float = min(380.0, view.y - 230.0)
	var gap := 30.0
	var total := n * w + (n - 1) * gap
	var x0 := (view.x - total) * 0.5
	var y0 := view.y * 0.5 - h * 0.5 + 50.0
	var out: Array = []
	for i in n:
		out.append(Rect2(x0 + i * (w + gap), y0, w, h))
	return out


func _upgrade_input(event: InputEvent) -> void:
	if upgrade_t < 0.5:  # 웨이브 끝 연타로 잘못 고르는 것 방지
		return
	var pos = null
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
	if pos != null:
		var rects := card_rects()
		for i in rects.size():
			if rects[i].grow(10).has_point(pos):
				choose_upgrade(i)
				get_viewport().set_input_as_handled()
				return
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1, KEY_2, KEY_3, KEY_4:
				var i: int = event.physical_keycode - KEY_1
				if i < upgrade_choices.size():
					choose_upgrade(i)
				return
		if event.is_action("left"):
			upgrade_sel = posmod(upgrade_sel - 1, upgrade_choices.size())
			sfx.play("jump", -10.0)
		elif event.is_action("right"):
			upgrade_sel = posmod(upgrade_sel + 1, upgrade_choices.size())
			sfx.play("jump", -10.0)
		elif event.is_action("bite") or event.is_action("jump") or event.physical_keycode == KEY_ENTER:
			choose_upgrade(upgrade_sel)


func choose_upgrade(i: int) -> void:
	if state != State.UPGRADE or i < 0 or i >= upgrade_choices.size() or hud.waiting_others:
		return
	var u: Dictionary = upgrade_choices[i]
	dino.apply_upgrade(u.id)
	dlog("upgrade chosen: %s -> Lv%d" % [u.id, dino.lv(u.id)])
	fx.text(dino.position + Vector2(0, -210), "%s Lv%d" % [u.name, dino.lv(u.id)], u.col)
	fx.ring(dino.position + Vector2(0, -90), 220.0, u.col)
	sfx.play("roar", -6.0, 1.3)
	if mode != "solo":
		coop.on_local_picked()
		hud.waiting_others = true  # 다른 사람이 다 고를 때까지 대기
		return
	state = State.PLAYING
	next_wave_t = 1.4


# ------------------------------------------------------------------ 충돌

func _collisions() -> void:
	for dn in dinos:
		if dn.dead or dn.stagger_t > 0.0:
			continue
		var dr: Rect2 = dn.get_rect()
		for t in tanks:
			if t.dead:
				continue
			var tr: Rect2 = t.get_rect()
			if not dr.intersects(tr):
				continue
			if dn.vel.y > 0.0 and dn.prev_y <= tr.position.y + 14.0:
				_stomp(t, dn)
			elif not dn.is_remote:
				var s: float = sign(t.position.x - dn.position.x)
				if s == 0.0:
					s = 1.0
				dn.position.x = t.position.x - s * (t.half_w + dn.HALF_W)
				dn.vel.x = 0.0
				if t != boss:
					t.knock = s * 60.0
	# 지상 적끼리 겹침 방지 (보스는 밀리지 않는다)
	for i in tanks.size():
		for j in range(i + 1, tanks.size()):
			var a = tanks[i]
			var b = tanks[j]
			var min_d: float = (a.half_w + b.half_w) * 0.85
			var d: float = b.position.x - a.position.x
			if abs(d) < min_d:
				var push: float = (min_d - abs(d)) * 0.5 * (1.0 if d >= 0.0 else -1.0)
				if a != boss:
					a.position.x -= push * (2.0 if b == boss else 1.0)
				if b != boss:
					b.position.x += push * (2.0 if a == boss else 1.0)
	_shell_collisions()


func _shell_collisions() -> void:
	for s in shells:
		if s.dead:
			continue
		if s.reflected:
			for arr in [tanks, helis]:
				for e in arr:
					if not e.dead and e.get_rect().grow(8).has_point(s.position):
						var m := 3.0 if arr == tanks else 4.0
						actor = s.get_meta("owner") if s.has_meta("owner") else dino
						var rm: float = s.get_meta("rmult") if s.has_meta("rmult") else dino.reflect_mult()
						e.hit(s.damage * m * rm, sign(s.vel.x), "reflect")
						explode_shell(s)
						break
				if s.dead:
					break
		elif _shell_hits_dino(s):
			explode_shell(s)
			continue
		if s.dead:
			continue
		if s.position.y >= ground_y:
			s.position.y = ground_y
			explode_shell(s)
		elif s.position.x < -400 or s.position.x > view.x + 400 or s.position.y < -1500:
			s.dead = true


func _shell_hits_dino(s) -> bool:
	for dn in dinos:
		if not dn.dead and dn.get_rect().grow(-8).has_point(s.position):
			return true
	return false


func explode_shell(s) -> void:
	s.dead = true
	var bullet: bool = s.style == ShellScript.BULLET
	fx.explosion(s.position, 0.25 if bullet else 0.55)
	sfx.play("small_boom", -12.0 if bullet else -5.0)
	add_shake(1.0 if bullet else 4.0)
	if not s.reflected:
		for dn in dinos:
			if dn.dead:
				continue
			var c: Vector2 = dn.position + Vector2(0, -70)
			if c.distance_to(s.position) < (70.0 if bullet else 105.0):
				dn.hurt(s.damage)


func _stomp(t, who = null) -> void:
	if who == null:
		who = dino
	var dino_bak = dino
	dino = who
	actor = who
	if who.is_remote:
		coop.send_rpc(who.net_id, {"k": "bounce", "v": t.get_rect().position.y})
	dino.vel.y = -880.0
	dino.position.y = t.get_rect().position.y
	_stomp_body(t)
	dino = dino_bak


func _stomp_body(t) -> void:
	var cd = t.get("stomp_cd")
	if cd != null and cd > 0.0:
		return  # 보스: 연속 밟기 방지 (튕기기만 한다)
	if cd != null:
		t.stomp_cd = 0.6
	dlog("stomp")
	var sd: float = dino.stomp_damage() if not dino.is_remote else 45.0 * (1.0 + 0.5 * 0)
	t.hit(sd, dino.facing, "stomp")
	t.stun = max(t.stun, 0.8)
	fx.dust(Vector2(dino.position.x, dino.position.y), 1.2)
	fx.text(dino.position + Vector2(0, -170), "밟기!", Color(1, 0.9, 0.3))
	sfx.play("stomp")
	add_shake(9.0)
	dino.add_roar(10.0)


func on_bite(rect: Rect2, who = null, dmg := -1.0) -> void:
	if mode == "guest":
		coop.send_bite(rect, dino.bite_damage(), dino.facing)
		return
	if who == null:
		who = dino
	var dino_bak = dino
	dino = who
	actor = who
	_bite_body(rect, dmg if dmg > 0.0 else who.bite_damage())
	dino = dino_bak


func _bite_body(rect: Rect2, bdmg: float) -> void:
	var hit_any := false
	for t in tanks:
		if not t.dead and rect.intersects(t.get_rect()):
			t.hit(bdmg, dino.facing, "bite")
			hit_any = true
			fx.sparks(Vector2(clamp(t.position.x, rect.position.x, rect.end.x), t.get_rect().position.y + 20.0))
	for h in helis:
		if not h.dead and rect.intersects(h.get_rect()):
			h.hit(bdmg * 1.25, dino.facing, "bite")
			hit_any = true
			fx.sparks(h.position)
	for s in shells:
		if not s.dead and not s.reflected and rect.grow(25).has_point(s.position):
			_reflect(s)
	if hit_any:
		sfx.play("crunch")
		add_shake(6.0)
		dino.add_roar(8.0)


func _reflect(s) -> void:
	s.reflected = true
	s.set_meta("owner", dino)
	s.set_meta("rmult", dino.reflect_mult() if not dino.is_remote else 1.0)
	s.grav = 1.0
	var target = null
	var best_d := INF
	for arr in [tanks, helis]:
		for e in arr:
			if e.dead or e.get("escaped") == true:
				continue
			var d: float = s.position.distance_to(e.position)
			if d < best_d:
				best_d = d
				target = e
	if target:
		var aim: Vector2 = target.position
		if tanks.has(target):
			aim += Vector2(0, -target.height * 0.6)
		s.vel = ballistic(s.position, aim, ShellScript.GRAVITY, clamp(best_d / 900.0, 0.35, 1.0))
	else:
		s.vel = Vector2(-s.vel.x * 1.3, -500.0)
	score += 25
	fx.text(s.position + Vector2(0, -30), "반사!", Color(0.5, 1, 1))
	sfx.play("reflect")
	dino.add_roar(6.0)


func do_roar(who = null, dmg := -1.0) -> void:
	if mode == "guest":
		coop.send_roar(dino.roar_damage())
		return
	if who == null:
		who = dino
	var dino_bak = dino
	dino = who
	actor = who
	_roar_body(dmg if dmg > 0.0 else who.roar_damage())
	dino = dino_bak


func _roar_body(rdmg: float) -> void:
	dlog("ROAR")
	var c: Vector2 = dino.position + Vector2(dino.facing * 60.0, -110.0)
	fx.ring(c, 900.0, Color(1, 0.8, 0.3, 0.9))
	fx.ring(c, 600.0, Color(1, 1, 1, 0.7))
	sfx.play("roar", 2.0, 0.85)
	add_shake(22.0)
	# 포효로 준 피해/처치로는 포효 게이지가 차지 않는다 (src = "roar")
	for t in tanks:
		if not t.dead:
			t.stun = 1.8
			t.hit(rdmg, sign(t.position.x - dino.position.x), "roar")
	for h in helis:
		if not h.dead:
			h.hit(rdmg * 1.3, 0.0, "roar")
	for s in shells:
		if not s.dead and not s.reflected:
			s.dead = true
			fx.explosion(s.position, 0.35)


func add_shell(pos: Vector2, vel: Vector2, damage: float, big := false):
	var s = ShellScript.new()
	s.main = self
	s.position = pos
	s.vel = vel
	s.damage = damage
	s.big = big
	world.add_child(s)
	shells.append(s)
	coop.tag(s, "shell")
	return s


func ballistic(from: Vector2, to: Vector2, g: float, t: float) -> Vector2:
	var d := to - from
	return Vector2(d.x / t, (d.y - 0.5 * g * t * t) / t)


func _gain_gold(amount: int, pos: Vector2) -> void:
	var g := int(round(amount * Meta.gold_mult(meta)))
	run_gold += g
	fx.text(pos + Vector2(0, -50), "+%d G" % g, Color(1, 0.85, 0.2))


func on_enemy_destroyed(pos: Vector2, base_points: int, size: float, gold_amt := 0, src := "") -> void:
	kills += 1
	combo += 1
	dlog("enemy destroyed at %s base=%d combo=%d src=%s" % [pos.round(), base_points, combo, src])
	combo_t = 2.5
	var mult: int = min(combo, 5)
	var pts := base_points * mult
	score += pts
	fx.explosion(pos, size)
	fx.text(pos + Vector2(0, -90), "+%d" % pts, Color(1, 1, 0.4))
	if combo >= 2:
		fx.text(pos + Vector2(0, -130), "콤보 x%d" % combo, Color(1, 0.5, 0.2))
	_gain_gold(gold_amt, pos)
	sfx.play("boom")
	add_shake(13.0 * size)
	var who = actor if actor != null and is_instance_valid(actor) else dino
	if src != "roar":
		who.add_roar(14.0)
	who.on_kill()


func on_boss_defeated(b) -> void:
	dlog("BOSS DEFEATED: %s" % b.boss_name)
	kills += 1
	score += b.points
	_gain_gold(b.gold, b.position + Vector2(0, -150))
	for i in 8:
		var p: Vector2 = b.position + Vector2(rng.randf_range(-b.half_w, b.half_w), rng.randf_range(-b.height, 0.0))
		fx.explosion(p, rng.randf_range(0.8, 1.6))
	fx.debris(b.position + Vector2(0, -b.height * 0.5), Color("4a4f5a"), 24)
	fx.text(b.position + Vector2(0, -b.height - 60.0), "보스 격파!", Color(1, 0.9, 0.3))
	sfx.play("boom", 4.0, 0.6)
	add_shake(26.0)
	# 남은 적과 포탄은 함께 정리 (보상 없음)
	for arr in [tanks, helis]:
		for e in arr:
			if not e.dead:
				e.dead = true
				fx.explosion(e.position + Vector2(0, -30), 0.8)
	for s in shells:
		s.dead = true
	hazards.clear()
	to_spawn = 0
	boss = null
	for dn in dinos:
		if dn.is_remote:
			coop.send_rpc(dn.net_id, {"k": "invuln", "v": 6.0})
		else:
			dn.invuln = 6.0
	stage_clear_t = 2.8


func add_shake(amount: float) -> void:
	coop.rec(["shake", amount])
	shake = min(max(shake, amount), 26.0)


func _cleanup() -> void:
	for arr in [tanks, helis, shells]:
		for i in range(arr.size() - 1, -1, -1):
			var n = arr[i]
			if n.dead:
				if n == boss:
					boss = null
				n.queue_free()
				arr.remove_at(i)


func _revive() -> void:
	revive_used = true
	gameover_t = 0.0
	dino.revive()
	dlog("revive")
	fx.ring(dino.position + Vector2(0, -90), 700.0, Color(1, 0.55, 0.3))
	fx.text(dino.position + Vector2(0, -220), "불사조 부활!", Color(1, 0.6, 0.3))
	sfx.play("roar", 2.0, 1.2)
	for s in shells:
		if not s.reflected:
			s.dead = true


func _stage_clear() -> void:
	if mode == "host":
		coop.send_end(true)
	state = State.STAGE_CLEAR
	gameover_t = 0.0
	var bonus := int(round(Stages.clear_gold(stage) * Meta.gold_mult(meta)))
	gold += run_gold + bonus
	var first_clear := unlocked <= stage
	unlocked = max(unlocked, stage + 1)
	best[str(stage)] = max(int(best.get(str(stage), 0)), score)
	high_score = max(high_score, score)
	result = {"cleared": true, "stage": stage, "score": score, "kills": kills, "run_gold": run_gold, "bonus": bonus, "first": first_clear}
	_save()
	touch.release_all()
	menu.open()
	dlog("STAGE CLEAR stage=%d score=%d gold=+%d(+%d bonus) total=%d" % [stage, score, run_gold, bonus, gold])


func _game_over() -> void:
	if mode == "host":
		coop.send_end(false)
	state = State.GAMEOVER
	gameover_t = 0.0
	gold += run_gold
	best[str(stage)] = max(int(best.get(str(stage), 0)), score)
	high_score = max(high_score, score)
	result = {"cleared": false, "stage": stage, "wave": wave, "score": score, "kills": kills, "run_gold": run_gold}
	_save()
	touch.release_all()
	menu.open()
	dlog("GAME OVER stage=%d wave=%d score=%d gold=+%d total=%d" % [stage, wave, score, run_gold, gold])


# ------------------------------------------------------------------ 저장

func _load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) == OK:
		high_score = int(cfg.get_value("game", "high_score", 0))
		gold = int(cfg.get_value("game", "gold", 0))
		unlocked = int(cfg.get_value("game", "unlocked", 1))
		meta = cfg.get_value("game", "meta", {})
		best = cfg.get_value("game", "best", {})
	selected_stage = unlocked


func save_now() -> void:
	_save()


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "high_score", high_score)
	cfg.set_value("game", "gold", gold)
	cfg.set_value("game", "unlocked", unlocked)
	cfg.set_value("game", "meta", meta)
	cfg.set_value("game", "best", best)
	cfg.save(save_path)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and touch:
		touch.release_all()
