extends Node2D
## 게임 전체 흐름(상태, 웨이브, 충돌, 점수)을 관리한다.

const DinoScript = preload("res://scripts/dino.gd")
const TankScript = preload("res://scripts/tank.gd")
const HeliScript = preload("res://scripts/heli.gd")
const ShellScript = preload("res://scripts/shell.gd")
const FxScript = preload("res://scripts/fx.gd")
const BgScript = preload("res://scripts/background.gd")
const HudScript = preload("res://scripts/hud.gd")
const TouchScript = preload("res://scripts/touch_controls.gd")
const SfxScript = preload("res://scripts/sfx.gd")
const AutoplayScript = preload("res://scripts/autoplay.gd")
const Upgrades = preload("res://scripts/upgrades.gd")

enum State { TITLE, PLAYING, UPGRADE, GAMEOVER }

const SAVE_PATH := "user://save.cfg"

var state := State.TITLE
var view := Vector2(1280, 720)
var ground_y := 610.0

var bg: Node2D
var world: Node2D
var fx: Node2D
var hud: Node2D
var touch: Node2D
var sfx: Node
var dino: Node2D
var tanks: Array = []
var helis: Array = []
var shells: Array = []

var score := 0
var high_score := 0
var kills := 0
var wave := 0
var to_spawn := 0
var spawn_timer := 0.0
var next_wave_t := 0.0
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
	rng.randomize()
	_setup_input()
	_load_save()
	bg = BgScript.new()
	bg.main = self
	add_child(bg)
	world = Node2D.new()
	add_child(world)
	fx = FxScript.new()
	fx.main = self
	fx.z_index = 10
	world.add_child(fx)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = HudScript.new()
	hud.main = self
	layer.add_child(hud)
	touch = TouchScript.new()
	touch.main = self
	layer.add_child(touch)
	sfx = SfxScript.new()
	add_child(sfx)
	_update_view()
	get_viewport().size_changed.connect(_update_view)
	_spawn_dino()
	_maybe_autoplay()


func _maybe_autoplay() -> void:
	var args := OS.get_cmdline_user_args()
	var on := args.has("--autoplay")
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("window.location.search", true)
		if typeof(q) == TYPE_STRING and q.contains("autoplay"):
			on = true
			if q.contains("manualpick"):
				args.append("--manualpick")
	if not on:
		return
	var ap = AutoplayScript.new()
	ap.main = self
	add_child(ap)
	ap.configure(args)


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


func _spawn_dino() -> void:
	dino = DinoScript.new()
	dino.main = self
	dino.position = Vector2(view.x * 0.5, ground_y)
	world.add_child(dino)


# ------------------------------------------------------------------ 입력

func _input(event: InputEvent) -> void:
	if state == State.PLAYING:
		return
	if state == State.UPGRADE:
		_upgrade_input(event)
		return
	var pressed := false
	if event is InputEventScreenTouch and event.pressed:
		pressed = true
	elif event is InputEventMouseButton and event.pressed:
		pressed = true
	elif event is InputEventKey and event.pressed and not event.echo:
		pressed = true
	if not pressed or is_portrait():
		return
	if state == State.TITLE or (state == State.GAMEOVER and gameover_t > 2.2):
		_try_fullscreen(event is InputEventScreenTouch)
		start_game()
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


func start_game() -> void:
	for arr in [tanks, helis, shells]:
		for n in arr:
			n.queue_free()
		arr.clear()
	dino.queue_free()
	_spawn_dino()
	fx.clear()
	score = 0
	kills = 0
	wave = 0
	combo = 0
	to_spawn = 0
	gameover_t = 0.0
	next_wave_t = 1.2
	upgrade_pending = false
	state = State.PLAYING
	sfx.play("roar", -4.0)
	dino.roar_t = 0.6


# ------------------------------------------------------------------ 루프

func _process(delta: float) -> void:
	delta = min(delta, 0.05)
	time += delta
	if is_portrait():
		hud.queue_redraw()
		return
	bg.update(delta)
	if state == State.UPGRADE:
		upgrade_t += delta
	else:
		dino.update(delta)
		for t in tanks:
			t.update(delta)
		for h in helis:
			h.update(delta)
		for s in shells:
			s.update(delta)
	if state == State.PLAYING:
		_collisions(delta)
		_waves(delta)
		if dino.dead:
			gameover_t += delta
			if gameover_t > 1.6:
				_game_over()
	elif state == State.GAMEOVER:
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
	touch.queue_redraw()


func _waves(delta: float) -> void:
	if upgrade_pending:
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
	if to_spawn > 0:
		spawn_timer -= delta
		var max_alive: int = min(2 + wave / 2, 6)
		if spawn_timer <= 0.0 and tanks.size() + helis.size() < max_alive:
			_spawn_enemy()
			to_spawn -= 1
			spawn_timer = max(0.7, 2.6 - wave * 0.15)
	elif tanks.is_empty() and helis.is_empty() and not dino.dead:
		upgrade_pending = true
		upgrade_wait = 1.6
		dino.heal(25)
		show_banner("WAVE CLEAR!  +25 HP")
		sfx.play("reflect", -6.0, 0.7)


# ------------------------------------------------------------------ 강화

func _open_upgrade() -> void:
	upgrade_choices = Upgrades.roll(dino.levels, 3, rng)
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
	var gap := 36.0
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
			KEY_1, KEY_2, KEY_3:
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
	if state != State.UPGRADE or i < 0 or i >= upgrade_choices.size():
		return
	var u: Dictionary = upgrade_choices[i]
	dino.apply_upgrade(u.id)
	dlog("upgrade chosen: %s -> Lv%d" % [u.id, dino.lv(u.id)])
	fx.text(dino.position + Vector2(0, -210), "%s Lv%d" % [u.name, dino.lv(u.id)], u.col)
	fx.ring(dino.position + Vector2(0, -90), 220.0, u.col)
	sfx.play("roar", -6.0, 1.3)
	state = State.PLAYING
	next_wave_t = 1.4


func _start_wave(n: int) -> void:
	wave = n
	to_spawn = 3 + n
	dlog("wave %d start (enemies=%d)" % [n, 3 + n])
	spawn_timer = 0.4
	show_banner("WAVE %d" % n)


func show_banner(text: String) -> void:
	banner_text = text
	banner_t = 2.2


func _spawn_enemy() -> void:
	var from_left := rng.randf() < 0.5
	var r := rng.randf()
	if wave >= 3 and r < 0.2:
		var h = HeliScript.new()
		h.main = self
		h.position = Vector2(-140.0 if from_left else view.x + 140.0, ground_y - 360.0 + rng.randf_range(-25, 25))
		world.add_child(h)
		helis.append(h)
		return
	var kind := 0
	r = rng.randf()
	if wave >= 4 and r < 0.3:
		kind = 2
	elif wave >= 2 and r < 0.7:
		kind = 1
	elif wave == 1 and r < 0.25:
		kind = 1
	var t = TankScript.new()
	t.main = self
	t.setup(kind)
	t.position = Vector2(-t.half_w - 40.0 if from_left else view.x + t.half_w + 40.0, ground_y)
	world.add_child(t)
	tanks.append(t)


# ------------------------------------------------------------------ 충돌

func _collisions(delta: float) -> void:
	if not dino.dead:
		var dr: Rect2 = dino.get_rect()
		for t in tanks:
			if t.dead:
				continue
			var tr: Rect2 = t.get_rect()
			if not dr.intersects(tr):
				continue
			if dino.vel.y > 0.0 and dino.prev_y <= tr.position.y + 14.0:
				_stomp(t)
			else:
				var s: float = sign(t.position.x - dino.position.x)
				if s == 0.0:
					s = 1.0
				dino.position.x = t.position.x - s * (t.half_w + dino.HALF_W)
				dino.vel.x = 0.0
				t.knock = s * 60.0
	# 탱크끼리 겹침 방지
	for i in tanks.size():
		for j in range(i + 1, tanks.size()):
			var a = tanks[i]
			var b = tanks[j]
			var min_d: float = (a.half_w + b.half_w) * 0.85
			var d: float = b.position.x - a.position.x
			if abs(d) < min_d:
				var push: float = (min_d - abs(d)) * 0.5 * (1.0 if d >= 0.0 else -1.0)
				a.position.x -= push
				b.position.x += push
	_shell_collisions()


func _shell_collisions() -> void:
	for s in shells:
		if s.dead:
			continue
		if s.reflected:
			for t in tanks:
				if not t.dead and t.get_rect().grow(6).has_point(s.position):
					t.hit(s.damage * 3.0 * dino.reflect_mult(), sign(s.vel.x))
					explode_shell(s)
					break
			if not s.dead:
				for h in helis:
					if not h.dead and h.get_rect().grow(10).has_point(s.position):
						h.hit(s.damage * 4.0 * dino.reflect_mult())
						explode_shell(s)
						break
		elif not dino.dead and dino.get_rect().grow(-8).has_point(s.position):
			explode_shell(s)
			continue
		if s.dead:
			continue
		if s.position.y >= ground_y:
			s.position.y = ground_y
			explode_shell(s)
		elif s.position.x < -400 or s.position.x > view.x + 400 or s.position.y < -1500:
			s.dead = true


func explode_shell(s) -> void:
	s.dead = true
	fx.explosion(s.position, 0.55)
	sfx.play("small_boom", -5.0)
	add_shake(4.0)
	if not s.reflected and not dino.dead:
		var c: Vector2 = dino.position + Vector2(0, -70)
		if c.distance_to(s.position) < 105.0:
			dino.hurt(s.damage)


func _stomp(t) -> void:
	dlog("stomp")
	dino.vel.y = -880.0
	dino.position.y = t.get_rect().position.y
	t.hit(dino.stomp_damage(), dino.facing)
	t.stun = max(t.stun, 0.8)
	fx.dust(Vector2(dino.position.x, dino.position.y), 1.2)
	fx.text(dino.position + Vector2(0, -170), "STOMP!", Color(1, 0.9, 0.3))
	sfx.play("stomp")
	add_shake(9.0)
	dino.add_roar(10.0)


func on_bite(rect: Rect2) -> void:
	var hit_any := false
	for t in tanks:
		if not t.dead and rect.intersects(t.get_rect()):
			t.hit(dino.bite_damage(), dino.facing)
			hit_any = true
			fx.sparks(Vector2(clamp(t.position.x, rect.position.x, rect.end.x), t.get_rect().position.y + 20.0))
	for h in helis:
		if not h.dead and rect.intersects(h.get_rect()):
			h.hit(dino.bite_damage() * 1.25)
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
	dlog("shell reflected")
	var target = null
	var best := INF
	for t in tanks:
		if t.dead:
			continue
		var d: float = abs(t.position.x - s.position.x)
		if d < best:
			best = d
			target = t
	if target:
		var aim: Vector2 = target.position + Vector2(0, -target.height * 0.6)
		s.vel = ballistic(s.position, aim, ShellScript.GRAVITY, clamp(best / 900.0, 0.35, 1.0))
	else:
		s.vel = Vector2(-s.vel.x * 1.3, -500.0)
	score += 25
	fx.text(s.position + Vector2(0, -30), "REFLECT!", Color(0.5, 1, 1))
	sfx.play("reflect")
	dino.add_roar(6.0)


func do_roar() -> void:
	dlog("ROAR")
	var c: Vector2 = dino.position + Vector2(dino.facing * 60.0, -110.0)
	fx.ring(c, 900.0, Color(1, 0.8, 0.3, 0.9))
	fx.ring(c, 600.0, Color(1, 1, 1, 0.7))
	sfx.play("roar", 2.0, 0.85)
	add_shake(22.0)
	for t in tanks:
		if not t.dead:
			t.stun = 1.8
			t.hit(dino.roar_damage(), sign(t.position.x - dino.position.x))
	for h in helis:
		if not h.dead:
			h.hit(dino.roar_damage() * 1.3)
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
	return s


func ballistic(from: Vector2, to: Vector2, g: float, t: float) -> Vector2:
	var d := to - from
	return Vector2(d.x / t, (d.y - 0.5 * g * t * t) / t)


func on_enemy_destroyed(pos: Vector2, base_points: int, size: float) -> void:
	kills += 1
	combo += 1
	dlog("enemy destroyed at %s base=%d combo=%d" % [pos.round(), base_points, combo])
	combo_t = 2.5
	var mult: int = min(combo, 5)
	var pts := base_points * mult
	score += pts
	fx.explosion(pos, size)
	fx.text(pos + Vector2(0, -90), "+%d" % pts, Color(1, 1, 0.4))
	if combo >= 2:
		fx.text(pos + Vector2(0, -130), "COMBO x%d" % combo, Color(1, 0.5, 0.2))
	sfx.play("boom")
	add_shake(13.0 * size)
	dino.add_roar(14.0)
	dino.on_kill()


func add_shake(amount: float) -> void:
	shake = min(max(shake, amount), 26.0)


func _cleanup() -> void:
	for arr in [tanks, helis, shells]:
		for i in range(arr.size() - 1, -1, -1):
			var n = arr[i]
			if n.dead:
				n.queue_free()
				arr.remove_at(i)


func _game_over() -> void:
	state = State.GAMEOVER
	gameover_t = 0.0
	dlog("GAME OVER score=%d wave=%d kills=%d" % [score, wave, kills])
	if score > high_score:
		high_score = score
		_save()
	touch.release_all()


# ------------------------------------------------------------------ 저장

func _load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		high_score = int(cfg.get_value("game", "high_score", 0))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "high_score", high_score)
	cfg.save(SAVE_PATH)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and touch:
		touch.release_all()
