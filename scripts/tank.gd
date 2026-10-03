extends Node2D
## 지상 적: 경/중/중전차, 돌격 지프(들이받기), 로켓 트럭(곡사 연발), 장갑 전차(물기에 강함).

const Stages = preload("res://scripts/stages.gd")
const ShellScript = preload("res://scripts/shell.gd")

const KINDS := {
	"light": {"hp": 55.0, "speed": 190.0, "w": 58.0, "h": 46.0, "rate": 2.6, "dmg": 8.0, "pts": 100, "col": Color("a3a94e"), "size": 0.9, "dist": [280.0, 520.0]},
	"medium": {"hp": 100.0, "speed": 130.0, "w": 72.0, "h": 56.0, "rate": 3.0, "dmg": 12.0, "pts": 150, "col": Color("6f8a3c"), "size": 1.1, "dist": [300.0, 560.0]},
	"heavy": {"hp": 210.0, "speed": 80.0, "w": 92.0, "h": 70.0, "rate": 3.6, "dmg": 18.0, "pts": 300, "col": Color("57604a"), "size": 1.5, "dist": [320.0, 560.0]},
	"jeep": {"hp": 40.0, "speed": 340.0, "w": 55.0, "h": 40.0, "rate": 0.0, "dmg": 12.0, "pts": 120, "col": Color("c2a46b"), "size": 0.9, "dist": [0.0, 0.0]},
	"rocket": {"hp": 80.0, "speed": 110.0, "w": 80.0, "h": 55.0, "rate": 4.6, "dmg": 9.0, "pts": 200, "col": Color("8a7650"), "size": 1.2, "dist": [600.0, 780.0]},
	"armored": {"hp": 260.0, "speed": 70.0, "w": 95.0, "h": 72.0, "rate": 3.3, "dmg": 16.0, "pts": 400, "col": Color("78838c"), "size": 1.6, "dist": [300.0, 460.0]},
}

const OUTLINE := Color("1e2414")
const TREAD := Color("3a3a3a")

var main
var kind := "light"
var hp := 100.0
var max_hp := 100.0
var speed := 120.0
var half_w := 70.0
var height := 56.0
var fire_rate := 3.0
var damage := 10.0
var points := 100
var gold := 3
var color := Color.OLIVE
var boom_size := 1.0

var dir := -1.0
var vel_x := 0.0
var knock := 0.0
var flash := 0.0
var stun := 0.0
var recoil := 0.0
var barrel_angle := 0.3
var target_angle := 0.3
var fire_cd := 2.0
var tread_phase := 0.0
var desired := 400.0
var dead := false
var t := 0.0
var ram_cd := 0.0      # 지프: 들이받은 뒤 후퇴 시간
var volley_left := 0   # 로켓 트럭: 남은 연발 수
var volley_t := 0.0
var block_text_t := 0.0


func setup(k: String) -> void:
	kind = k
	var d: Dictionary = KINDS[k]
	hp = d.hp
	speed = d.speed
	half_w = d.w
	height = d.h
	fire_rate = d.rate
	damage = d.dmg
	points = d.pts
	color = d.col
	boom_size = d.size
	gold = Stages.ENEMIES[k].gold


func _ready() -> void:
	var s: int = main.stage
	hp *= Stages.hp_mult(s)
	max_hp = hp
	damage *= Stages.dmg_mult(s)
	fire_rate *= Stages.fire_mult(s)
	var dist: Array = KINDS[kind].dist
	desired = main.rng.randf_range(dist[0], dist[1])
	fire_cd = main.rng.randf_range(1.2, 2.4)


func get_rect() -> Rect2:
	var top := height * 1.42
	if kind == "jeep":
		top = height * 1.3
	return Rect2(position.x - half_w, position.y - top, half_w * 2.0, top)


func _pivot() -> Vector2:
	if kind == "rocket":
		return Vector2(-half_w * 0.35, -height * 0.95)
	return Vector2(-half_w * 0.05, -height * 1.02)


func _barrel_len() -> float:
	return half_w * 0.95


func update(delta: float) -> void:
	t += delta
	flash = max(flash - delta, 0.0)
	recoil = max(recoil - delta * 4.0, 0.0)
	ram_cd -= delta
	block_text_t -= delta
	var d = main.dino
	var playing: bool = main.state == main.State.PLAYING
	if stun > 0.0:
		stun -= delta
		vel_x = move_toward(vel_x, 0.0, 900.0 * delta)
	elif kind == "jeep":
		_jeep_ai(delta, playing and not d.dead)
	else:
		var dx: float = d.position.x - position.x
		dir = 1.0 if dx > 0.0 else -1.0
		var dist: float = abs(dx)
		var target_v := 0.0
		if dist > desired + 40.0:
			target_v = dir * speed
		elif dist < desired - 140.0:
			target_v = -dir * speed * 0.6
		if position.x < half_w + 20.0:
			target_v = max(target_v, speed)
		elif position.x > main.view.x - half_w - 20.0:
			target_v = min(target_v, -speed)
		vel_x = move_toward(vel_x, target_v, 420.0 * delta)
		_aim_and_fire(delta, playing and not d.dead)
	knock = move_toward(knock, 0.0, 900.0 * delta)
	position.x += (vel_x + knock) * delta
	position.y = main.ground_y
	tread_phase += (vel_x + knock) * delta / 14.0
	barrel_angle = lerp_angle(barrel_angle, target_angle, min(1.0, delta * 4.0))
	queue_redraw()


func _jeep_ai(delta: float, active: bool) -> void:
	var d = main.dino
	var dx: float = d.position.x - position.x
	var target_v := 0.0
	if ram_cd > 0.0:
		target_v = -dir * speed * 0.7  # 후퇴
	else:
		dir = 1.0 if dx > 0.0 else -1.0
		target_v = dir * speed
	if position.x < half_w + 10.0:
		target_v = max(target_v, speed * 0.5)
	elif position.x > main.view.x - half_w - 10.0:
		target_v = min(target_v, -speed * 0.5)
	vel_x = move_toward(vel_x, target_v, 700.0 * delta)
	if abs(vel_x) > 200.0 and fmod(t, 0.08) < delta:
		main.fx.dust(position + Vector2(-sign(vel_x) * half_w, 0), 0.3)
	if active and ram_cd <= 0.0 and get_rect().intersects(d.get_rect()) and d.position.y > position.y - height * 1.2:
		ram_cd = 1.4
		d.hurt(damage)
		d.knockback(Vector2(dir * 520.0, -420.0), 0.35)
		knock = -dir * 250.0
		main.fx.sparks(position + Vector2(dir * half_w, -height * 0.6))
		main.sfx.play("stomp", -4.0, 1.4)


func _muzzle() -> Vector2:
	var p := _pivot()
	var l := _barrel_len()
	return position + Vector2(dir * (p.x + cos(barrel_angle) * l), p.y - sin(barrel_angle) * l)


func _aim_and_fire(delta: float, can_fire: bool) -> void:
	var d = main.dino
	var target: Vector2 = d.position + Vector2(d.vel.x * 0.25, -70.0)
	var from := _muzzle()
	var flight: float = clamp(abs(target.x - from.x) / 560.0, 0.6, 1.7)
	if kind == "rocket":
		flight = clamp(abs(target.x - from.x) / 420.0, 1.3, 2.2)
	var v: Vector2 = main.ballistic(from, target, ShellScript.GRAVITY, flight)
	target_angle = clamp(atan2(-v.y, abs(v.x)), 0.05, 1.3)
	var on_screen: bool = position.x > 30.0 and position.x < main.view.x - 30.0
	if not can_fire or not on_screen:
		return
	if volley_left > 0:
		volley_t -= delta
		if volley_t <= 0.0:
			volley_left -= 1
			volley_t = 0.28
			var aim := target + Vector2(main.rng.randf_range(-130.0, 130.0), 0.0)
			var s = main.add_shell(from, main.ballistic(from, aim, ShellScript.GRAVITY, flight), damage)
			s.style = ShellScript.ROCKET
			main.fx.muzzle(from, Vector2(dir * cos(barrel_angle), -sin(barrel_angle)))
			main.sfx.play("shoot", -9.0, 1.5)
		return
	fire_cd -= delta
	if fire_cd <= 0.0:
		fire_cd = fire_rate * main.rng.randf_range(0.8, 1.25)
		if kind == "rocket":
			volley_left = 3
			volley_t = 0.0
			return
		var aim := target + Vector2(main.rng.randf_range(-70.0, 70.0), 0.0)
		var vel: Vector2 = main.ballistic(from, aim, ShellScript.GRAVITY, flight)
		main.add_shell(from, vel, damage, kind == "heavy" or kind == "armored")
		main.fx.muzzle(from, Vector2(dir * cos(barrel_angle), -sin(barrel_angle)))
		main.sfx.play("shoot", -6.0, 1.2 - boom_size * 0.15)
		recoil = 1.0
		knock -= dir * 40.0


## src: "bite" / "stomp" / "reflect" / "roar"
func hit(dmg: float, kdir := 0.0, src := "") -> void:
	if dead:
		return
	if kind == "armored":
		if src == "bite":
			dmg *= 0.35
			if block_text_t <= 0.0:
				block_text_t = 0.6
				main.fx.text(position + Vector2(0, -height * 1.8), "단단하다! 밟아라!", Color(0.8, 0.85, 0.9))
		elif src == "stomp":
			dmg *= 2.0
	hp -= dmg
	flash = 0.12
	knock = kdir * 260.0
	if hp <= 0.0:
		dead = true
		main.on_enemy_destroyed(position + Vector2(0, -height * 0.6), points, boom_size, gold, src)
		main.fx.debris(position + Vector2(0, -height * 0.7), color, 10 + int(boom_size * 4))


# ------------------------------------------------------------------ 드로잉

func _c(col: Color) -> Color:
	if flash > 0.0:
		return col.lerp(Color.WHITE, 0.75)
	return col


func _poly(pts: PackedVector2Array, col: Color) -> void:
	draw_colored_polygon(pts, _c(col))
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, OUTLINE, 3.0, true)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(dir, 1.0))
	draw_colored_polygon(_shadow(half_w), Color(0, 0, 0, 0.18))
	match kind:
		"jeep":
			_draw_jeep()
		"rocket":
			_draw_rocket()
		_:
			_draw_tank()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var h := height
	var w := half_w
	if hp < max_hp:
		var bw := w * 1.4
		var by := -h * 1.75
		draw_rect(Rect2(-bw * 0.5, by, bw, 7), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-bw * 0.5 + 1, by + 1, (bw - 2) * max(hp, 0.0) / max_hp, 5), Color("ff5252"))
	if stun > 0.0:
		for i in 3:
			var a := t * 5.0 + TAU * i / 3.0
			_star(Vector2(cos(a) * w * 0.5, -h * 1.55 + sin(a) * 8.0), 7.0, Color(1, 0.9, 0.2))


func _draw_barrel(col: Color, thick := 0.075) -> void:
	var h := height
	var p := _pivot()
	var l := _barrel_len() * (1.0 - recoil * 0.18)
	var dv := Vector2(cos(barrel_angle), -sin(barrel_angle))
	var nv := Vector2(-dv.y, dv.x) * h * thick
	_poly(PackedVector2Array([p + nv, p + dv * l + nv, p + dv * l - nv, p - nv]), col)
	var tip := p + dv * l
	_poly(PackedVector2Array([tip + nv * 1.6, tip + dv * h * 0.16 + nv * 1.6, tip + dv * h * 0.16 - nv * 1.6, tip - nv * 1.6]), col)


func _draw_treads(w: float, h: float) -> void:
	var tr := h * 0.22
	var tread := PackedVector2Array()
	for i in 9:
		var a := -PI * 0.5 + PI * i / 8.0
		tread.append(Vector2(w - tr + cos(a) * tr, -tr + sin(a) * tr))
	for i in 9:
		var a := PI * 0.5 + PI * i / 8.0
		tread.append(Vector2(-w + tr + cos(a) * tr, -tr + sin(a) * tr))
	_poly(tread, TREAD)
	var n_wheels := int(w / 22.0) + 2
	for i in n_wheels:
		var wx := -w + tr + (2.0 * w - 2.0 * tr) * i / float(n_wheels - 1)
		_wheel(Vector2(wx, -tr), tr * 0.72)


func _wheel(c: Vector2, r: float) -> void:
	draw_circle(c, r, _c(Color("6b6b6b")))
	var sp := Vector2(cos(tread_phase), sin(tread_phase)) * r * 0.8
	draw_line(c - sp, c + sp, Color("2a2a2a"), 2.0)
	draw_circle(c, r * 0.3, Color("2a2a2a"))


func _draw_tank() -> void:
	var w := half_w
	var h := height
	var dark := color.darkened(0.3)
	_draw_barrel(dark, 0.09 if kind == "armored" else 0.075)
	var turret := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		turret.append(Vector2(-w * 0.12 + cos(a) * w * 0.48, -h * 0.84 + sin(a) * h * 0.42))
	_poly(turret, color)
	draw_circle(Vector2(-w * 0.15, -h * 1.0), h * 0.07, Color(1, 1, 1, 0.85))
	draw_line(Vector2(-w * 0.4, -h * 1.1), Vector2(-w * 0.55, -h * 1.65), OUTLINE, 2.0)
	_poly(PackedVector2Array([Vector2(-w * 0.92, -h * 0.42), Vector2(w * 0.98, -h * 0.42), Vector2(w * 0.78, -h * 0.86), Vector2(-w * 0.86, -h * 0.86)]), color)
	draw_line(Vector2(-w * 0.8, -h * 0.64), Vector2(w * 0.75, -h * 0.64), dark, 3.0)
	_draw_treads(w, h)
	if kind == "armored":
		# 측면 장갑판 + 리벳
		_poly(PackedVector2Array([Vector2(-w * 0.98, -h * 0.5), Vector2(w * 1.0, -h * 0.5), Vector2(w * 0.94, -h * 0.18), Vector2(-w * 0.94, -h * 0.18)]), color.darkened(0.15))
		for i in 7:
			draw_circle(Vector2(-w * 0.8 + i * w * 0.27, -h * 0.34), 3.0, Color("cfd8dc"))
		# 전면 스파이크
		for i in 3:
			var y := -h * (0.3 + i * 0.12)
			_poly(PackedVector2Array([Vector2(w * 0.94, y - 5), Vector2(w * 1.18, y), Vector2(w * 0.94, y + 5)]), Color("b0bec5"))


func _draw_jeep() -> void:
	var w := half_w
	var h := height
	var r := h * 0.3
	# 차체
	_poly(PackedVector2Array([Vector2(-w, -h * 0.35), Vector2(w * 0.95, -h * 0.35), Vector2(w, -h * 0.7), Vector2(w * 0.45, -h * 0.78), Vector2(-w * 0.9, -h * 0.8)]), color)
	# 앞유리
	_poly(PackedVector2Array([Vector2(w * 0.3, -h * 0.78), Vector2(w * 0.42, -h * 1.15), Vector2(w * 0.5, -h * 1.15), Vector2(w * 0.45, -h * 0.78)]), Color("9fd8ff"))
	# 운전병 헬멧
	draw_circle(Vector2(w * 0.05, -h * 1.0), h * 0.18, _c(Color("556b2f")))
	# 범퍼/충각
	_poly(PackedVector2Array([Vector2(w * 0.95, -h * 0.65), Vector2(w * 1.2, -h * 0.55), Vector2(w * 1.2, -h * 0.35), Vector2(w * 0.95, -h * 0.3)]), Color("616161"))
	_wheel(Vector2(-w * 0.6, -r), r)
	_wheel(Vector2(w * 0.6, -r), r)


func _draw_rocket() -> void:
	var w := half_w
	var h := height
	var r := h * 0.24
	# 적재함 + 캐빈
	_poly(PackedVector2Array([Vector2(-w, -h * 0.3), Vector2(w * 0.95, -h * 0.3), Vector2(w * 0.95, -h * 0.62), Vector2(-w, -h * 0.62)]), color)
	_poly(PackedVector2Array([Vector2(w * 0.35, -h * 0.62), Vector2(w * 0.95, -h * 0.62), Vector2(w * 0.95, -h * 1.0), Vector2(w * 0.5, -h * 1.05), Vector2(w * 0.35, -h * 0.95)]), color.lightened(0.1))
	_poly(PackedVector2Array([Vector2(w * 0.6, -h * 0.95), Vector2(w * 0.9, -h * 0.95), Vector2(w * 0.9, -h * 0.75), Vector2(w * 0.6, -h * 0.75)]), Color("9fd8ff"))
	# 발사대 (barrel_angle 방향으로 기울어짐)
	var p := _pivot()
	var dv := Vector2(cos(barrel_angle), -sin(barrel_angle))
	var nv := Vector2(-dv.y, dv.x)
	var l := w * 1.0
	_poly(PackedVector2Array([p + nv * 16.0, p + dv * l + nv * 16.0, p + dv * l - nv * 16.0, p - nv * 16.0]), color.darkened(0.35))
	for i in 3:
		var o := nv * (-10.0 + i * 10.0)
		draw_circle(p + dv * l + o, 4.5, Color("e53935") if volley_left <= i else Color("424242"))
	_wheel(Vector2(-w * 0.65, -r), r)
	_wheel(Vector2(-w * 0.2, -r), r)
	_wheel(Vector2(w * 0.65, -r), r)


func _shadow(w: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(Vector2(cos(a) * w * 1.05, sin(a) * 6.0 + 2.0))
	return pts


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rr := r if i % 2 == 0 else r * 0.45
		var a := -PI * 0.5 + TAU * i / 10.0
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)
