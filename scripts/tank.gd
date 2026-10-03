extends Node2D
## 적 탱크. 공룡과 일정 거리를 유지하며 포물선 포탄을 쏜다.

const KINDS := [
	{"hp": 55.0, "speed": 190.0, "w": 58.0, "h": 46.0, "rate": 2.6, "dmg": 8.0, "pts": 100, "col": Color("a3a94e"), "size": 0.9},
	{"hp": 100.0, "speed": 130.0, "w": 72.0, "h": 56.0, "rate": 3.0, "dmg": 12.0, "pts": 150, "col": Color("6f8a3c"), "size": 1.1},
	{"hp": 210.0, "speed": 80.0, "w": 92.0, "h": 70.0, "rate": 3.6, "dmg": 18.0, "pts": 300, "col": Color("57604a"), "size": 1.5},
]

const OUTLINE := Color("1e2414")
const TREAD := Color("3a3a3a")

var main
var kind := 0
var hp := 100.0
var max_hp := 100.0
var speed := 120.0
var half_w := 70.0
var height := 56.0
var fire_rate := 3.0
var damage := 10.0
var points := 100
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


func setup(k: int) -> void:
	kind = k
	var d: Dictionary = KINDS[k]
	hp = d.hp
	max_hp = d.hp
	speed = d.speed
	half_w = d.w
	height = d.h
	fire_rate = d.rate
	damage = d.dmg
	points = d.pts
	color = d.col
	boom_size = d.size


func _ready() -> void:
	desired = main.rng.randf_range(280.0, 560.0)
	fire_cd = main.rng.randf_range(1.2, 2.4)
	var scale_by_wave: float = max(0.55, 1.0 - main.wave * 0.04)
	fire_rate *= scale_by_wave


func get_rect() -> Rect2:
	var top := height + height * 0.42
	return Rect2(position.x - half_w, position.y - top, half_w * 2.0, top)


func _pivot() -> Vector2:
	return Vector2(-half_w * 0.05, -height * 1.02)


func _barrel_len() -> float:
	return half_w * 0.95


func update(delta: float) -> void:
	t += delta
	flash = max(flash - delta, 0.0)
	recoil = max(recoil - delta * 4.0, 0.0)
	var d = main.dino
	var playing: bool = main.state == main.State.PLAYING
	if stun > 0.0:
		stun -= delta
		vel_x = move_toward(vel_x, 0.0, 900.0 * delta)
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


func _muzzle() -> Vector2:
	var p := _pivot()
	var l := _barrel_len()
	return position + Vector2(dir * (p.x + cos(barrel_angle) * l), p.y - sin(barrel_angle) * l)


func _aim_and_fire(delta: float, can_fire: bool) -> void:
	var d = main.dino
	var target: Vector2 = d.position + Vector2(d.vel.x * 0.25, -70.0)
	var from := _muzzle()
	var flight: float = clamp(abs(target.x - from.x) / 560.0, 0.6, 1.7)
	var v: Vector2 = main.ballistic(from, target, preload("res://scripts/shell.gd").GRAVITY, flight)
	target_angle = clamp(atan2(-v.y, abs(v.x)), 0.05, 1.3)
	var on_screen: bool = position.x > 30.0 and position.x < main.view.x - 30.0
	if not can_fire or not on_screen:
		return
	fire_cd -= delta
	if fire_cd <= 0.0:
		fire_cd = fire_rate * main.rng.randf_range(0.8, 1.25)
		var aim := target + Vector2(main.rng.randf_range(-70.0, 70.0), 0.0)
		var vel: Vector2 = main.ballistic(from, aim, preload("res://scripts/shell.gd").GRAVITY, flight)
		main.add_shell(from, vel, damage, kind == 2)
		main.fx.muzzle(from, Vector2(dir * cos(barrel_angle), -sin(barrel_angle)))
		main.sfx.play("shoot", -6.0, 1.2 - kind * 0.15)
		recoil = 1.0
		knock -= dir * 40.0


func hit(dmg: float, kdir: float) -> void:
	if dead:
		return
	hp -= dmg
	flash = 0.12
	knock = kdir * 260.0
	if hp <= 0.0:
		dead = true
		main.on_enemy_destroyed(position + Vector2(0, -height * 0.6), points, boom_size)
		main.fx.debris(position + Vector2(0, -height * 0.7), color, 10 + kind * 4)


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
	var w := half_w
	var h := height
	var dark := color.darkened(0.3)

	# 그림자
	draw_colored_polygon(_shadow(w), Color(0, 0, 0, 0.18))
	# 포신
	var p := _pivot()
	var l := _barrel_len() * (1.0 - recoil * 0.18)
	var dv := Vector2(cos(barrel_angle), -sin(barrel_angle))
	var nv := Vector2(-dv.y, dv.x) * h * 0.075
	_poly(PackedVector2Array([p + nv, p + dv * l + nv, p + dv * l - nv, p - nv]), dark)
	var tip := p + dv * l
	_poly(PackedVector2Array([tip + nv * 1.6, tip + dv * h * 0.16 + nv * 1.6, tip + dv * h * 0.16 - nv * 1.6, tip - nv * 1.6]), dark)
	# 포탑
	var turret := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		turret.append(Vector2(-w * 0.12 + cos(a) * w * 0.48, -h * 0.84 + sin(a) * h * 0.42))
	_poly(turret, color)
	draw_circle(Vector2(-w * 0.15, -h * 1.0), h * 0.07, Color(1, 1, 1, 0.85))
	draw_line(Vector2(-w * 0.4, -h * 1.1), Vector2(-w * 0.55, -h * 1.65), OUTLINE, 2.0)
	# 차체
	_poly(PackedVector2Array([Vector2(-w * 0.92, -h * 0.42), Vector2(w * 0.98, -h * 0.42), Vector2(w * 0.78, -h * 0.86), Vector2(-w * 0.86, -h * 0.86)]), color)
	draw_line(Vector2(-w * 0.8, -h * 0.64), Vector2(w * 0.75, -h * 0.64), dark, 3.0)
	# 무한궤도
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
		var c := Vector2(wx, -tr)
		draw_circle(c, tr * 0.72, _c(Color("6b6b6b")))
		var sp := Vector2(cos(tread_phase), sin(tread_phase)) * tr * 0.6
		draw_line(c - sp, c + sp, Color("2a2a2a"), 2.0)
		draw_circle(c, tr * 0.22, Color("2a2a2a"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 체력바
	if hp < max_hp:
		var bw := w * 1.4
		var by := -h * 1.75
		draw_rect(Rect2(-bw * 0.5, by, bw, 7), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-bw * 0.5 + 1, by + 1, (bw - 2) * max(hp, 0.0) / max_hp, 5), Color("ff5252"))
	# 기절 별
	if stun > 0.0:
		for i in 3:
			var a := t * 5.0 + TAU * i / 3.0
			var sp := Vector2(cos(a) * w * 0.5, -h * 1.55 + sin(a) * 8.0)
			_star(sp, 7.0, Color(1, 0.9, 0.2))


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
