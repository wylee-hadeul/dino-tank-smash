extends Node2D
## 보스 3종. 체력이 절반 이하가 되면 분노 상태로 패턴이 빨라진다.
##  - 기가 탱크: 산탄 포격 / 기관총 / 돌진 (벽에 부딪히면 기절 → 밟기 기회)
##  - 하늘 요새: 융단 폭격 / 미사일 / 드론 소환 / 저공 비행(물기 기회)
##  - 아이언 렉스: 레이저 / 지진파 / 미사일 / 근접 물기

const Stages = preload("res://scripts/stages.gd")
const ShellScript = preload("res://scripts/shell.gd")

enum { GIGA, FORTRESS, REX }

const OUTLINE := Color("15181c")

var main
var kind := GIGA
var boss_name := ""
var hp := 1000.0
var max_hp := 1000.0
var dead := false
var half_w := 150.0
var height := 110.0
var is_air := false
var stun := 0.0
var knock := 0.0
var flash := 0.0
var stomp_cd := 0.0
var dir := -1.0
var t := 0.0
var state := "enter"
var state_t := 0.0
var attack_i := 0
var vel := Vector2.ZERO
var dmg_mult := 1.0
var points := 3000
var gold := 100
var hover_y := 0.0
var shots_left := 0
var shot_t := 0.0
var barrel_angle := 0.4
var charge_dir := 0.0
var jaw := 0.0
var walk := 0.0
var enter_x := 0.0
var laser_from := Vector2.ZERO
var fresh := true  # 상태에 막 진입한 첫 프레임
var close_i := 0


func setup(k: int, stage: int) -> void:
	kind = k
	boss_name = Stages.BOSSES[k].name
	var m := Stages.boss_hp_mult(stage)
	dmg_mult = Stages.dmg_mult(stage)
	gold = Stages.boss_gold(stage)
	match k:
		GIGA:
			half_w = 150.0
			height = 110.0
			max_hp = 1400.0 * m
		FORTRESS:
			half_w = 140.0
			height = 60.0
			max_hp = 1100.0 * m
			is_air = true
		REX:
			half_w = 80.0
			height = 200.0
			max_hp = 1600.0 * m
	hp = max_hp


func _ready() -> void:
	var from_left: bool = position.x < main.view.x * 0.5
	enter_x = main.view.x * (0.25 if from_left else 0.75)
	dir = 1.0 if from_left else -1.0
	hover_y = main.ground_y - 400.0


func enraged() -> bool:
	return hp < max_hp * 0.5


func get_rect() -> Rect2:
	match kind:
		GIGA:
			return Rect2(position.x - half_w, position.y - height - 45.0, half_w * 2.0, height + 45.0)
		FORTRESS:
			return Rect2(position.x - half_w, position.y - 35.0, half_w * 2.0, 70.0)
	return Rect2(position.x - half_w, position.y - height, half_w * 2.0, height)


func _set_state(s: String) -> void:
	state = s
	state_t = 0.0
	fresh = true


func update(delta: float) -> void:
	t += delta
	flash = max(flash - delta, 0.0)
	stomp_cd -= delta
	knock = move_toward(knock, 0.0, 600.0 * delta)
	var rate := 1.35 if enraged() else 1.0
	if stun > 0.0:
		stun -= delta * 2.5  # 보스는 기절에서 빨리 회복한다
	else:
		state_t += delta * rate
		var was := state
		match kind:
			GIGA:
				_giga(delta * rate)
			FORTRESS:
				_fortress(delta * rate)
			REX:
				_rex(delta * rate)
		if state == was:
			fresh = false
	if not is_air:
		position.x += knock * delta
		if state != "enter":
			position.x = clamp(position.x, half_w, main.view.x - half_w)
	queue_redraw()


func _face_dino() -> void:
	dir = 1.0 if main.dino.position.x > position.x else -1.0


func _next_attack(list: Array) -> void:
	var a: String = list[attack_i % list.size()]
	attack_i += 1
	_set_state(a)


func _keep_distance(delta: float, want: float, spd: float) -> void:
	var dx: float = main.dino.position.x - position.x
	var v := 0.0
	if abs(dx) > want + 40.0:
		v = sign(dx) * spd
	elif abs(dx) < want - 80.0:
		v = -sign(dx) * spd
	position.x += v * delta
	position.x = clamp(position.x, half_w, main.view.x - half_w)
	walk += abs(v) * delta * 0.05


func _can_attack() -> bool:
	return main.state == main.State.PLAYING and not main.dino.dead


# ------------------------------------------------------------------ 기가 탱크

func _giga(delta: float) -> void:
	var d = main.dino
	position.y = main.ground_y
	match state:
		"enter":
			position.x = move_toward(position.x, enter_x, 140.0 * delta)
			walk += 140.0 * delta * 0.05
			if abs(position.x - enter_x) < 2.0:
				_set_state("idle")
		"idle":
			_face_dino()
			_keep_distance(delta, 430.0, 90.0)
			barrel_angle = lerp(barrel_angle, 0.45, delta * 3.0)
			if state_t > 1.4 and _can_attack():
				_next_attack(["spread", "mg", "charge_warn"])
		"spread":
			if fresh:
				shots_left = 1
			if state_t > 0.35 and shots_left == 1:
				shots_left = 0
				var from := _giga_muzzle()
				for off in [-220.0, -110.0, 0.0, 110.0, 220.0]:
					var aim: Vector2 = d.position + Vector2(off, -60.0)
					main.add_shell(from, main.ballistic(from, aim, ShellScript.GRAVITY, 1.2), 14.0 * dmg_mult, true)
				main.fx.muzzle(from, Vector2(dir, -0.5).normalized())
				main.sfx.play("shoot", 0.0, 0.7)
				main.add_shake(8.0)
			if state_t > 1.3:
				_set_state("idle")
		"mg":
			if fresh:
				shots_left = 12
				shot_t = 0.0
			shot_t -= delta
			if shots_left > 0 and shot_t <= 0.0:
				shots_left -= 1
				shot_t = 0.1
				var from := position + Vector2(dir * half_w * 0.95, -height * 0.55)
				var v: Vector2 = ((d.position + Vector2(0, -60)) - from).normalized() * 760.0 + Vector2(0, -60)
				var b = main.add_shell(from, v, 5.0 * dmg_mult)
				b.style = ShellScript.BULLET
				b.grav = 0.3
				main.sfx.play("shoot", -12.0, 2.0)
			if shots_left == 0 and state_t > 1.6:
				_set_state("idle")
		"charge_warn":
			if fresh:
				_face_dino()
				charge_dir = dir
				main.fx.text(position + Vector2(0, -height - 90.0), "돌진!", Color(1, 0.3, 0.2))
				main.sfx.play("roar", -4.0, 0.5)
			knock = sin(t * 60.0) * 40.0
			if fmod(t, 0.1) < delta:
				main.fx.puff(position + Vector2(-charge_dir * half_w, -height * 0.9), Color(0.3, 0.3, 0.3, 0.6), 14.0)
			if state_t > 0.9:
				_set_state("charge")
		"charge":
			position.x += charge_dir * 700.0 * delta
			walk += 700.0 * delta * 0.05
			if fmod(t, 0.06) < delta:
				main.fx.dust(Vector2(position.x - charge_dir * half_w, main.ground_y), 0.6)
			if not d.dead and d.stagger_t <= 0.0 and get_rect().intersects(d.get_rect()):
				d.hurt(20.0 * dmg_mult)
				d.knockback(Vector2(-charge_dir * 430.0, -1050.0), 0.7)  # 보스 머리 위로 튕겨낸다
			if (charge_dir > 0.0 and position.x >= main.view.x - half_w) or (charge_dir < 0.0 and position.x <= half_w):
				position.x = clamp(position.x, half_w, main.view.x - half_w)
				main.add_shake(18.0)
				main.sfx.play("boom", -2.0, 0.7)
				main.fx.dust(Vector2(position.x + charge_dir * half_w, main.ground_y), 2.0)
				_set_state("dazed")
		"dazed":
			if state_t > 2.0:
				_set_state("idle")


func _giga_muzzle() -> Vector2:
	var p := Vector2(-half_w * 0.1, -height - 20.0)
	var l := half_w * 0.95
	return position + Vector2(dir * (p.x + cos(barrel_angle) * l), p.y - sin(barrel_angle) * l)


# ------------------------------------------------------------------ 하늘 요새

func _fortress(delta: float) -> void:
	var d = main.dino
	match state:
		"enter":
			position.x = move_toward(position.x, enter_x, 200.0 * delta)
			position.y = move_toward(position.y, hover_y, 200.0 * delta)
			if abs(position.x - enter_x) < 2.0:
				_set_state("idle")
		"idle":
			var target_x: float = clamp(d.position.x + (200.0 if position.x > d.position.x else -200.0), half_w, main.view.x - half_w)
			position.x = move_toward(position.x, target_x, 120.0 * delta)
			position.y = move_toward(position.y, hover_y + sin(t * 1.5) * 15.0, 120.0 * delta)
			if state_t > 1.5 and _can_attack():
				_next_attack(["carpet", "missiles", "drones", "low"])
		"carpet":
			if fresh:
				charge_dir = 1.0 if d.position.x > position.x else -1.0
				shot_t = 0.0
			position.x += charge_dir * 380.0 * delta
			position.x = clamp(position.x, half_w * 0.5, main.view.x - half_w * 0.5)
			shot_t -= delta
			if shot_t <= 0.0:
				shot_t = 0.16
				var b = main.add_shell(position + Vector2(0, 30), Vector2(charge_dir * 120.0, 40.0), 10.0 * dmg_mult)
				b.style = ShellScript.BOMB
			if state_t > 1.6:
				_set_state("idle")
		"missiles":
			if fresh:
				shots_left = 6
				shot_t = 0.2
			shot_t -= delta
			if shots_left > 0 and shot_t <= 0.0:
				shot_t = 0.18
				shots_left -= 1
				var side := -1.0 if shots_left % 2 == 0 else 1.0
				var from := position + Vector2(side * half_w * 0.6, 20.0)
				var aim: Vector2 = d.position + Vector2(main.rng.randf_range(-160.0, 160.0), -40.0)
				var s = main.add_shell(from, main.ballistic(from, aim, ShellScript.GRAVITY, main.rng.randf_range(1.0, 1.4)), 10.0 * dmg_mult)
				s.style = ShellScript.ROCKET
				main.sfx.play("shoot", -8.0, 1.6)
			if shots_left == 0 and state_t > 1.6:
				_set_state("idle")
		"drones":
			if fresh:
				var alive := 0
				for h in main.helis:
					if h.get("mode") != null:
						alive += 1
				for i in min(2, 4 - alive):
					main.spawn_air("drone", position + Vector2(-40.0 + i * 80.0, 30.0))
				main.fx.text(position + Vector2(0, -80), "드론 출격!", Color(1, 0.4, 0.3))
			if state_t > 1.0:
				_set_state("idle")
		"low":
			var low_y: float = main.ground_y - 290.0
			if state_t < 0.7:
				position.y = move_toward(position.y, low_y, 250.0 * delta)
			elif state_t > 3.0:
				position.y = move_toward(position.y, hover_y, 250.0 * delta)
				if abs(position.y - hover_y) < 2.0:
					_set_state("idle")
			else:
				position.x = move_toward(position.x, d.position.x, 60.0 * delta)


# ------------------------------------------------------------------ 아이언 렉스

func _rex(delta: float) -> void:
	var d = main.dino
	match state:
		"enter":
			position.y = main.ground_y
			position.x = move_toward(position.x, enter_x, 150.0 * delta)
			walk += 150.0 * delta * 0.05
			if abs(position.x - enter_x) < 2.0:
				_set_state("idle")
		"idle":
			position.y = main.ground_y
			_face_dino()
			jaw = move_toward(jaw, 0.1, delta)
			_keep_distance(delta, 380.0, 100.0)
			if state_t > 1.3 and _can_attack():
				if abs(d.position.x - position.x) < 240.0:
					close_i += 1
					_set_state(["chomp", "quake", "laser"][close_i % 3])  # 붙어 있어도 패턴을 섞는다
				else:
					_next_attack(["laser", "quake", "missiles"])
		"laser":
			if fresh:
				_face_dino()
				laser_from = position + Vector2(dir * (half_w + 10.0), -45.0)
				var edge: float = main.view.x + 50.0 if dir > 0.0 else -50.0
				main.hazards.add_laser(laser_from.x, edge, laser_from.y, 22.0 * dmg_mult, 0.9, 0.6)
				main.sfx.play("reflect", -4.0, 0.3)
			jaw = 0.6
			if state_t > 1.8:
				_set_state("idle")
		"quake":
			if fresh:
				vel.y = -1000.0
				position.y = main.ground_y - 1.0
			vel.y += 2600.0 * delta
			position.y += vel.y * delta
			if position.y >= main.ground_y and vel.y > 0.0:
				position.y = main.ground_y
				vel.y = 0.0
				main.hazards.add_quake(position.x - half_w, -1.0, 16.0 * dmg_mult)
				main.hazards.add_quake(position.x + half_w, 1.0, 16.0 * dmg_mult)
				main.add_shake(18.0)
				main.sfx.play("stomp", 2.0, 0.6)
				main.fx.dust(Vector2(position.x, main.ground_y), 2.0)
				_set_state("land")
		"land":
			if state_t > 0.8:
				_set_state("idle")
		"missiles":
			if fresh:
				shots_left = 4
				shot_t = 0.3
			shot_t -= delta
			if shots_left > 0 and shot_t <= 0.0:
				shot_t = 0.22
				shots_left -= 1
				var from := position + Vector2(-dir * half_w * 0.6, -height * 0.85)
				var aim: Vector2 = d.position + Vector2(main.rng.randf_range(-150.0, 150.0), -40.0)
				var s = main.add_shell(from, main.ballistic(from, aim, ShellScript.GRAVITY, 1.5), 12.0 * dmg_mult)
				s.style = ShellScript.ROCKET
				main.sfx.play("shoot", -8.0, 1.4)
			if shots_left == 0 and state_t > 1.5:
				_set_state("idle")
		"chomp":
			jaw = min(1.0, state_t * 2.5)
			if state_t > 0.4 and state_t < 0.6:
				position.x += dir * 500.0 * delta
				position.x = clamp(position.x, half_w, main.view.x - half_w)
				var bite := Rect2(position.x + (half_w if dir > 0.0 else -half_w - 110.0), position.y - 200.0, 110.0, 120.0)
				if not d.dead and d.stagger_t <= 0.0 and bite.intersects(d.get_rect()):
					d.hurt(18.0 * dmg_mult)
					d.knockback(Vector2(dir * 600.0, -500.0), 0.45)
			if state_t > 0.6:
				jaw = 0.0
			if state_t > 1.1:
				_set_state("idle")


# ------------------------------------------------------------------ 피해

func hit(dmg: float, kdir := 0.0, src := "") -> void:
	if dead:
		return
	if kind == GIGA:
		if src == "stomp":
			dmg *= 1.5
		elif src == "bite":
			dmg *= 0.8
	if state == "dazed":
		dmg *= 1.5  # 기절 중 추가 피해
	hp -= dmg
	flash = 0.1
	if not is_air:
		knock = kdir * 60.0
	if hp <= 0.0:
		hp = 0.0
		dead = true
		main.on_boss_defeated(self)


# ------------------------------------------------------------------ 드로잉

func _c(col: Color) -> Color:
	if flash > 0.0:
		return col.lerp(Color.WHITE, 0.7)
	if enraged():
		return col.lerp(Color(1, 0.2, 0.1), 0.15 + 0.1 * sin(t * 8.0))
	return col


func _poly(pts: PackedVector2Array, col: Color, w := 3.0) -> void:
	draw_colored_polygon(pts, _c(col))
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, OUTLINE, w, true)


func _draw() -> void:
	match kind:
		GIGA:
			_draw_giga()
		FORTRESS:
			_draw_fortress()
		REX:
			_draw_rex()
	if state == "dazed" or stun > 0.0:
		var top: float = get_rect().position.y - position.y
		for i in 4:
			var a := t * 5.0 + TAU * i / 4.0
			_star(Vector2(cos(a) * half_w * 0.4, top - 15.0 + sin(a) * 8.0), 10.0, Color(1, 0.9, 0.2))


func _draw_giga() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(dir, 1.0))
	var w := half_w
	var h := height
	var col := Color("4a4f5a")
	var dark := Color("2d3138")
	# 그림자
	var sh := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		sh.append(Vector2(cos(a) * w * 1.05, sin(a) * 8.0 + 2.0))
	draw_colored_polygon(sh, Color(0, 0, 0, 0.2))
	# 주포 (2연장)
	var p := Vector2(-w * 0.1, -h - 20.0)
	var dv := Vector2(cos(barrel_angle), -sin(barrel_angle))
	var nv := Vector2(-dv.y, dv.x)
	for o in [-9.0, 9.0]:
		var base: Vector2 = p + nv * o
		_poly(PackedVector2Array([base + nv * 6.0, base + dv * w + nv * 6.0, base + dv * w - nv * 6.0, base - nv * 6.0]), dark)
	# 포탑
	_poly(PackedVector2Array([Vector2(-w * 0.6, -h * 0.85), Vector2(w * 0.35, -h * 0.85), Vector2(w * 0.25, -h - 45.0), Vector2(-w * 0.5, -h - 45.0)]), col)
	draw_rect(Rect2(-w * 0.45, -h - 30.0, w * 0.6, 8.0), _c(Color("c62828")))
	# 해골 엠블럼
	var e := Vector2(-w * 0.15, -h - 2.0)
	draw_circle(e, 14.0, Color("eeeeee"))
	draw_circle(e + Vector2(-5, -2), 4.0, Color.BLACK)
	draw_circle(e + Vector2(5, -2), 4.0, Color.BLACK)
	draw_rect(Rect2(e.x - 6, e.y + 6, 12, 5), Color("eeeeee"))
	# 기관총
	draw_line(Vector2(w * 0.7, -h * 0.55), Vector2(w * 1.0, -h * 0.6), dark, 7.0)
	# 차체
	_poly(PackedVector2Array([Vector2(-w * 0.98, -h * 0.4), Vector2(w * 1.02, -h * 0.4), Vector2(w * 0.85, -h * 0.88), Vector2(-w * 0.92, -h * 0.88)]), col)
	draw_line(Vector2(-w * 0.9, -h * 0.64), Vector2(w * 0.9, -h * 0.64), _c(Color("c62828")), 6.0)
	# 배기관
	for i in 2:
		draw_rect(Rect2(-w * 0.9 + i * 22.0, -h * 1.1, 12.0, h * 0.25), _c(dark))
	# 궤도
	var tr := h * 0.22
	var tread := PackedVector2Array()
	for i in 9:
		var a := -PI * 0.5 + PI * i / 8.0
		tread.append(Vector2(w - tr + cos(a) * tr, -tr + sin(a) * tr))
	for i in 9:
		var a := PI * 0.5 + PI * i / 8.0
		tread.append(Vector2(-w + tr + cos(a) * tr, -tr + sin(a) * tr))
	_poly(tread, Color("2b2b2b"))
	for i in 9:
		var c := Vector2(-w + tr + (2.0 * w - 2.0 * tr) * i / 8.0, -tr)
		draw_circle(c, tr * 0.7, _c(Color("616161")))
		var sp := Vector2(cos(walk), sin(walk)) * tr * 0.55
		draw_line(c - sp, c + sp, Color("212121"), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_fortress() -> void:
	draw_set_transform(Vector2.ZERO, sin(t * 1.2) * 0.03, Vector2.ONE)
	var w := half_w
	var col := Color("4f6475")
	var dark := Color("2f3d48")
	# 로터 마스트
	for x in [-w * 0.7, w * 0.7]:
		draw_line(Vector2(x, -30), Vector2(x, -48), OUTLINE, 6.0)
		var rl: float = 120.0 * abs(cos(t * 28.0 + x)) + 20.0
		draw_line(Vector2(x - rl, -50), Vector2(x + rl, -50), Color(0.08, 0.08, 0.08, 0.75), 5.0)
	# 동체
	var body := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		body.append(Vector2(cos(a) * w, sin(a) * 34.0))
	_poly(body, col)
	draw_line(Vector2(-w * 0.9, 6), Vector2(w * 0.9, 6), _c(dark), 4.0)
	# 조종석
	_poly(PackedVector2Array([Vector2(w * 0.6, -24), Vector2(w * 0.95, -8), Vector2(w * 0.98, 6), Vector2(w * 0.6, 6)]), Color("9fd8ff"), 2.0)
	# 미사일 포드
	for x in [-w * 0.6, w * 0.6]:
		_poly(PackedVector2Array([Vector2(x - 34, 26), Vector2(x + 34, 26), Vector2(x + 30, 44), Vector2(x - 30, 44)]), dark)
		for j in 3:
			draw_circle(Vector2(x - 20 + j * 20, 35), 5.0, Color("e53935"))
	# 해치/경고등
	var blink: float = 0.5 + 0.5 * sin(t * 6.0)
	draw_circle(Vector2(0, 30), 8.0, Color(1, 0.2, 0.1, blink))
	draw_circle(Vector2(-w * 0.95, 0), 5.0, Color(1, 0.2, 0.1, 1.0 - blink))
	if state == "low":
		draw_string(ThemeDB.fallback_font, Vector2(-60, -70), "지금이다!", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 1, 0.4, blink))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_rex() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(dir, 1.0))
	var metal := Color("8d99a6")
	var dark := Color("56616c")
	var moving := state == "idle" or state == "enter"
	var ph := walk
	# 그림자
	var sh := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		sh.append(Vector2(cos(a) * 100.0, sin(a) * 8.0 + 2.0))
	draw_colored_polygon(sh, Color(0, 0, 0, 0.2))
	# 꼬리
	_poly(PackedVector2Array([Vector2(-40, -150), Vector2(-150, -120 + sin(t * 3.0) * 6.0), Vector2(-210, -100 + sin(t * 3.0) * 10.0), Vector2(-150, -98), Vector2(-40, -105)]), dark)
	# 뒷다리
	_rex_leg(Vector2(-25, -95), ph + PI if moving else 0.0, dark)
	# 몸통
	_poly(PackedVector2Array([Vector2(-60, -170), Vector2(30, -185), Vector2(70, -150), Vector2(60, -95), Vector2(-50, -90)]), metal)
	for i in 4:
		draw_circle(Vector2(-40 + i * 25, -175 + i * 2), 3.0, Color("cfd8dc"))
	# 가슴 코어
	var core: float = 0.6 + 0.4 * sin(t * 6.0)
	draw_circle(Vector2(25, -130), 14.0, Color(1, 0.3, 0.1, core))
	draw_circle(Vector2(25, -130), 7.0, Color(1, 0.9, 0.6))
	# 목/머리
	var hinge := Vector2(70, -190)
	var hx := Transform2D(0.0, hinge)
	_poly(PackedVector2Array([Vector2(40, -175), Vector2(65, -205), Vector2(90, -195), Vector2(70, -150)]), dark)
	var lower := PackedVector2Array()
	for p in [Vector2(-4, 4), Vector2(78, 6), Vector2(72, 24), Vector2(0, 24)]:
		lower.append(hx * (p.rotated(jaw * 0.7)))
	_poly(lower, dark)
	_poly(hx * PackedVector2Array([Vector2(-10, -38), Vector2(60, -40), Vector2(84, -24), Vector2(84, 4), Vector2(-4, 6)]), metal)
	for i in 6:
		var tx := 12.0 + i * 11.0
		draw_colored_polygon(hx * PackedVector2Array([Vector2(tx, 5), Vector2(tx + 4, 13), Vector2(tx + 8, 5)]), Color("eceff1"))
	# 붉은 눈
	var eye_col := Color(1, 0.1, 0.05)
	if state == "laser" and state_t < 0.9:
		eye_col = Color(1, 1, 0.5)
		draw_circle(hx * Vector2(40, -22), 22.0 + sin(t * 40.0) * 4.0, Color(1, 0.2, 0.1, 0.35))
	draw_circle(hx * Vector2(40, -22), 8.0, eye_col)
	# 팔
	draw_line(Vector2(50, -125), Vector2(72, -110), OUTLINE, 11.0)
	draw_line(Vector2(50, -125), Vector2(72, -110), _c(dark), 6.0)
	# 앞다리
	_rex_leg(Vector2(15, -92), ph if moving else 0.0, metal)
	# 레이저 발사 중: 입에서 지면 높이로 내려가는 빔
	if state == "laser" and state_t >= 0.9 and state_t < 1.5:
		var to_local := Vector2((laser_from.x - position.x) * dir, laser_from.y - position.y)
		draw_line(hx * Vector2(80, -8), to_local, Color(1, 0.6, 0.3), 14.0)
		draw_line(hx * Vector2(80, -8), to_local, Color(1, 1, 0.9), 5.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _rex_leg(hip: Vector2, phase: float, col: Color) -> void:
	var swing := sin(phase) * 0.45
	var knee := hip + Vector2(sin(swing) * 30.0 + 18.0, 48.0)
	var foot := Vector2(hip.x + sin(swing) * 40.0, 0.0)
	draw_line(hip, knee, OUTLINE, 32.0)
	draw_line(knee, foot, OUTLINE, 24.0)
	draw_line(hip, knee, _c(col), 26.0)
	draw_line(knee, foot, _c(col), 18.0)
	draw_circle(knee, 10.0, Color("37474f"))
	_poly(PackedVector2Array([foot + Vector2(-16, -10), foot + Vector2(30, -8), foot + Vector2(34, 2), foot + Vector2(-16, 2)]), col)


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rr := r if i % 2 == 0 else r * 0.45
		var a := -PI * 0.5 + TAU * i / 10.0
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)
