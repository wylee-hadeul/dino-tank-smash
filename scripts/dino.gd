extends Node2D
## 플레이어 티라노사우루스. 이동/점프/물기/포효, 그리고 절차적 드로잉.

const SPEED := 430.0
const GRAVITY := 2500.0
const JUMP_V := -1080.0
const HALF_W := 55.0
const HEIGHT := 140.0
const BITE_TIME := 0.24
const BITE_CD := 0.32

const BODY := Color("5cb85c")
const DARK := Color("2e7d32")
const BELLY := Color("d4edb0")
const OUTLINE := Color("163316")
const TOOTH := Color("fffbe8")

var main
var vel := Vector2.ZERO
var prev_y := 0.0
var facing := 1.0
var hp := 100.0
var max_hp := 100.0
var on_ground := true
var bite_cd := 0.0
var bite_t := 0.0
var hurt_t := 0.0
var invuln := 0.0
var roar_meter := 0.0
var roar_t := 0.0
var walk_phase := 0.0
var land_squash := 0.0
var dead := false
var death_t := 0.0
var anim_t := 0.0
var levels := {}  # 강화 id -> 레벨


func lv(id: String) -> int:
	return levels.get(id, 0)


func apply_upgrade(id: String) -> void:
	levels[id] = lv(id) + 1
	if id == "hp":
		max_hp = 100.0 + 25.0 * lv("hp")
		hp = max_hp


func speed() -> float:
	return SPEED * (1.0 + 0.15 * lv("speed"))


func bite_damage() -> float:
	return 28.0 * (1.0 + 0.35 * lv("bite"))


func stomp_damage() -> float:
	return 45.0 * (1.0 + 0.5 * lv("jump"))


func roar_damage() -> float:
	return 55.0 * (1.0 + 0.3 * lv("roar"))


func reflect_mult() -> float:
	return 1.0 + 0.6 * lv("reflect")


func on_kill() -> void:
	if lv("vamp") > 0 and not dead:
		heal(4.0 * lv("vamp"))


func get_rect() -> Rect2:
	return Rect2(position.x - HALF_W, position.y - HEIGHT, HALF_W * 2.0, HEIGHT)


func bite_rect() -> Rect2:
	var reach := 165.0 * (1.0 + 0.25 * lv("reach"))
	var top := 200.0 + 20.0 * lv("reach")
	if facing > 0.0:
		return Rect2(position.x + 15.0, position.y - top, reach, top - 15.0)
	return Rect2(position.x - 15.0 - reach, position.y - top, reach, top - 15.0)


func update(delta: float) -> void:
	anim_t += delta
	prev_y = position.y
	bite_cd -= delta
	bite_t -= delta
	hurt_t -= delta
	invuln -= delta
	roar_t -= delta
	land_squash = max(land_squash - delta * 4.0, 0.0)
	if dead:
		death_t += delta
		vel.y += GRAVITY * delta
		vel.x = move_toward(vel.x, 0.0, 600.0 * delta)
		position += vel * delta
		position.y = min(position.y, main.ground_y)
		queue_redraw()
		return

	var playing: bool = main.state == main.State.PLAYING
	if playing and lv("regen") > 0:
		heal(1.5 * lv("regen") * delta)
	var dir := 0.0
	if playing and roar_t <= 0.0:
		dir = Input.get_axis("left", "right")
	vel.x = move_toward(vel.x, dir * speed(), 3200.0 * delta)
	if dir != 0.0:
		facing = sign(dir)

	if playing:
		if on_ground and Input.is_action_just_pressed("jump"):
			vel.y = JUMP_V * (1.0 + 0.12 * lv("jump"))
			on_ground = false
			main.sfx.play("jump", -8.0)
		if not Input.is_action_pressed("jump") and vel.y < -300.0:
			vel.y += GRAVITY * 1.2 * delta  # 짧게 누르면 낮은 점프
		if Input.is_action_just_pressed("bite") and bite_cd <= 0.0:
			_bite()
		if Input.is_action_just_pressed("roar"):
			if roar_meter >= 100.0:
				roar_meter = 0.0
				roar_t = 0.9
				main.do_roar()

	vel.y += GRAVITY * delta
	position += vel * delta
	if position.y >= main.ground_y:
		if not on_ground and vel.y > 700.0:
			main.fx.dust(Vector2(position.x, main.ground_y), 0.8)
			land_squash = 1.0
		position.y = main.ground_y
		vel.y = 0.0
		on_ground = true
	else:
		on_ground = false
	position.x = clamp(position.x, 145.0, main.view.x - 145.0)  # 머리/꼬리가 잘리지 않게
	walk_phase += abs(vel.x) * delta * 0.028
	queue_redraw()


func _bite() -> void:
	bite_cd = BITE_CD * (1.0 - 0.18 * lv("frenzy"))
	bite_t = BITE_TIME
	main.sfx.play("bite", -2.0)
	main.on_bite(bite_rect())


func hurt(dmg: float) -> void:
	if dead or invuln > 0.0:
		return
	dmg *= 1.0 - 0.15 * lv("armor")
	hp -= dmg
	main.dlog("dino hurt -%.0f hp=%.0f" % [dmg, max(hp, 0.0)])
	hurt_t = 0.25
	invuln = 0.55
	main.sfx.play("hurt", -3.0)
	main.add_shake(8.0)
	if hp <= 0.0:
		hp = 0.0
		dead = true
		vel = Vector2(-facing * 200.0, -450.0)
		main.fx.explosion(position + Vector2(0, -80), 0.8)
		main.sfx.play("roar", 0.0, 0.6)


func heal(amount: float) -> void:
	hp = min(hp + amount, max_hp)


func add_roar(amount: float) -> void:
	var was_full := roar_meter >= 100.0
	roar_meter = min(roar_meter + amount * (1.0 + 0.4 * lv("roar")), 100.0)
	if not was_full and roar_meter >= 100.0:
		main.fx.text(position + Vector2(0, -200), "포효 준비!", Color(1, 0.6, 0.1))


# ------------------------------------------------------------------ 드로잉

func _c(col: Color) -> Color:
	if hurt_t > 0.0:
		return col.lerp(Color(1, 0.25, 0.2), 0.6)
	return col


func _poly(pts: PackedVector2Array, col: Color, outline := true) -> void:
	draw_colored_polygon(pts, _c(col))
	if outline:
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, OUTLINE, 3.0, true)


func _ellipse(center: Vector2, r: Vector2, rot := 0.0, seg := 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in seg:
		var a := TAU * i / seg
		pts.append(center + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot))
	return pts


func _leg(hip: Vector2, phase: float, col: Color) -> void:
	var swing := sin(phase) * 0.55 if on_ground else -0.35
	if dead:
		swing = sin(anim_t * 14.0 + phase) * 0.5
	var lift: float = max(0.0, cos(phase)) * 10.0 if on_ground and abs(vel.x) > 20.0 else 0.0
	var knee := hip + Vector2(sin(swing) * 30.0 + 12.0, 30.0 - lift * 0.5)
	var foot := Vector2(hip.x + sin(swing) * 38.0, -lift)
	if not on_ground:
		foot = knee + Vector2(-10.0, 26.0)
	draw_line(hip, knee, OUTLINE, 30.0)
	draw_line(knee, foot, OUTLINE, 22.0)
	draw_line(hip, knee, _c(col), 24.0)
	draw_line(knee, foot, _c(col), 16.0)
	draw_circle(knee, 12.0, _c(col))
	_poly(PackedVector2Array([foot + Vector2(-12, -8), foot + Vector2(22, -6), foot + Vector2(26, 2), foot + Vector2(-12, 2)]), col)


func _draw() -> void:
	if dead and int(death_t * 10.0) % 2 == 0 and death_t > 2.5:
		return
	if invuln > 0.0 and not dead and int(anim_t * 20.0) % 2 == 0:
		modulate.a = 0.55
	else:
		modulate.a = 1.0

	var rot := 0.0
	if dead:
		rot = PI * min(death_t * 2.5, 1.0)  # 몸 중심 기준으로 뒤집힌다
	var squash := 1.0 - land_squash * 0.12
	var shake_off := Vector2.ZERO
	if roar_t > 0.0:
		shake_off = Vector2(randf_range(-3, 3), randf_range(-2, 2))
	var pivot := Vector2(0, -90)
	var body_xf := Transform2D(0.0, shake_off + pivot) * Transform2D(rot * facing, Vector2.ZERO) \
		* Transform2D(0.0, -pivot) * Transform2D(0.0, Vector2(facing * (2.0 - squash), squash), 0.0, Vector2.ZERO)
	draw_set_transform_matrix(body_xf)

	var breathe := sin(anim_t * 3.0) * 2.0
	var sway := sin(anim_t * 4.0) * 7.0

	# 꼬리
	_poly(PackedVector2Array([Vector2(-30, -112 + breathe), Vector2(-120, -96 + sway), Vector2(-172, -82 + sway * 1.5), Vector2(-118, -78 + sway), Vector2(-34, -62)]), BODY)
	# 뒷다리
	_leg(Vector2(-22, -66), walk_phase + PI, DARK)
	# 몸통
	_poly(_ellipse(Vector2(0, -96 + breathe), Vector2(64, 46), -0.12), BODY)
	draw_colored_polygon(_ellipse(Vector2(16, -80 + breathe), Vector2(40, 26), -0.2), _c(BELLY))
	# 등 가시
	for i in 6:
		var x := -48.0 + i * 17.0
		var y := -96.0 + breathe - 46.0 * sqrt(max(0.0, 1.0 - pow(x / 66.0, 2))) + x * 0.12
		_poly(PackedVector2Array([Vector2(x - 8, y + 6), Vector2(x - 2, y - 16), Vector2(x + 8, y + 6)]), DARK)
	# 목
	_poly(PackedVector2Array([Vector2(22, -128 + breathe), Vector2(52, -168), Vector2(84, -156), Vector2(64, -96 + breathe)]), BODY, false)

	# 머리 (물기/포효 애니메이션)
	var jaw := 0.06 + sin(anim_t * 2.0) * 0.03
	var lunge := 0.0
	var tilt := 0.0
	if bite_t > 0.0:
		var k := 1.0 - bite_t / BITE_TIME
		jaw = sin(k * PI) * 0.75
		lunge = sin(k * PI) * 18.0
	if roar_t > 0.0:
		jaw = 0.85
		tilt = -0.25
	if dead:
		jaw = 0.45
	var hinge := Vector2(52 + lunge, -142)
	var head_xf := Transform2D(tilt, hinge)
	# 입 안
	var mouth := PackedVector2Array([Vector2(0, 0), Vector2(66, 2), Vector2(66, 2).rotated(jaw) + Vector2(0, 4), Vector2(0, 6)])
	draw_colored_polygon(head_xf * mouth, Color("7a1f1f"))
	# 아래턱
	var lower := PackedVector2Array()
	for p in [Vector2(-6, 2), Vector2(66, 4), Vector2(60, 18), Vector2(0, 20)]:
		lower.append(head_xf * (p.rotated(jaw)))
	for i in 5:
		var tx := 14.0 + i * 11.0
		var tooth := PackedVector2Array([Vector2(tx, 5), Vector2(tx + 4, -4), Vector2(tx + 8, 5)])
		var tt := PackedVector2Array()
		for p in tooth:
			tt.append(head_xf * p.rotated(jaw))
		draw_colored_polygon(tt, TOOTH)
	_poly(lower, BODY)
	# 위턱 + 이빨
	for i in 6:
		var tx := 10.0 + i * 11.0
		draw_colored_polygon(head_xf * PackedVector2Array([Vector2(tx, -1), Vector2(tx + 4, 9), Vector2(tx + 8, -1)]), TOOTH)
	_poly(head_xf * PackedVector2Array([Vector2(-14, -36), Vector2(40, -40), Vector2(64, -30), Vector2(74, -14), Vector2(72, 0), Vector2(-8, 2), Vector2(-20, -14)]), BODY)
	# 눈, 눈썹, 콧구멍
	if dead:
		var e := head_xf * Vector2(34, -22)
		draw_line(e + Vector2(-6, -6), e + Vector2(6, 6), OUTLINE, 3.0)
		draw_line(e + Vector2(-6, 6), e + Vector2(6, -6), OUTLINE, 3.0)
	else:
		draw_circle(head_xf * Vector2(34, -22), 8.0, Color.WHITE)
		draw_circle(head_xf * Vector2(37, -21), 4.0, Color.BLACK)
		draw_line(head_xf * Vector2(22, -33), head_xf * Vector2(46, -28), OUTLINE, 5.0)
	draw_circle(head_xf * Vector2(64, -26), 2.5, OUTLINE)

	# 짧은 팔
	var arm_a := sin(anim_t * 6.0) * 0.3
	var shoulder := Vector2(44, -100 + breathe)
	var elbow := shoulder + Vector2(14, 10).rotated(arm_a)
	draw_line(shoulder, elbow, OUTLINE, 11.0)
	draw_line(elbow, elbow + Vector2(10, -6), OUTLINE, 9.0)
	draw_line(shoulder, elbow, _c(BODY), 6.0)
	draw_line(elbow, elbow + Vector2(10, -6), _c(BODY), 4.0)
	# 앞다리
	_leg(Vector2(10, -60), walk_phase, BODY)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 포효 게이지가 가득 차면 오라
	if roar_meter >= 100.0 and not dead:
		var a := 0.25 + sin(anim_t * 8.0) * 0.12
		draw_arc(Vector2(0, -90), 110.0 + sin(anim_t * 8.0) * 6.0, 0.0, TAU, 40, Color(1, 0.6, 0.1, a), 5.0)
