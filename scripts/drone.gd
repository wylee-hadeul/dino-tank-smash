extends Node2D
## 자폭 드론. 공룡 위로 날아와 잠시 조준한 뒤 급강하해 자폭한다.

const Stages = preload("res://scripts/stages.gd")

enum { APPROACH, AIM, DIVE }

var main
var hp := 20.0
var max_hp := 20.0
var damage := 14.0
var points := 80
var gold := 2
var dead := false
var flash := 0.0
var t := 0.0
var mode := APPROACH
var mode_t := 0.0
var vel := Vector2.ZERO
var offset_x := 0.0


func _ready() -> void:
	hp *= Stages.hp_mult(main.stage)
	max_hp = hp
	damage *= Stages.dmg_mult(main.stage)
	offset_x = main.rng.randf_range(-160.0, 160.0)


func get_rect() -> Rect2:
	return Rect2(position.x - 39.0, position.y - 24.0, 78.0, 48.0)


func update(delta: float) -> void:
	if has_meta("puppet"):
		# 같이 하기 참가자 화면: 방장이 보낸 위치로 따라가기만 한다
		position = position.lerp(get_meta("net_pos", position), min(1.0, delta * 12.0))
		t += delta
		queue_redraw()
		return
	t += delta
	mode_t += delta
	flash = max(flash - delta, 0.0)
	var d = main.target_for(position)
	match mode:
		APPROACH:
			var target := Vector2(clamp(d.position.x + offset_x, 60.0, main.view.x - 60.0), main.ground_y - 330.0)
			vel = vel.move_toward((target - position).limit_length(1.0) * 260.0, 600.0 * delta)
			position += vel * delta
			if position.distance_to(target) < 30.0 or mode_t > 5.0:
				mode = AIM
				mode_t = 0.0
		AIM:
			position += Vector2(0, sin(t * 10.0) * 20.0 * delta)
			if mode_t > 0.9 and main.state == main.State.PLAYING:
				mode = DIVE
				mode_t = 0.0
				vel = ((d.position + Vector2(0, -60)) - position).normalized() * 680.0
				main.sfx.play("reflect", -10.0, 0.6)
		DIVE:
			position += vel * delta
			if not d.dead and get_rect().grow(10).intersects(d.get_rect()):
				_explode(true)
			elif position.y >= main.ground_y - 10.0 or position.x < -80.0 or position.x > main.view.x + 80.0:
				_explode(false)
	queue_redraw()


## 자폭 (점수/골드 없음)
func _explode(direct: bool) -> void:
	dead = true
	main.fx.explosion(position, 0.6)
	main.sfx.play("small_boom", -4.0)
	main.add_shake(5.0)
	var d = main.target_for(position)
	if direct or (d.position + Vector2(0, -70)).distance_to(position) < 100.0:
		d.hurt(damage)


func hit(dmg: float, _kdir := 0.0, src := "") -> void:
	if dead:
		return
	hp -= dmg
	flash = 0.12
	if hp <= 0.0:
		dead = true
		main.on_enemy_destroyed(position, points, 0.6, gold, src)


func _draw() -> void:
	var body := Color("455a64").lerp(Color.WHITE, 0.75 if flash > 0.0 else 0.0)
	var outline := Color("1c252c")
	var sc := Vector2(1.5, 1.5)  # 모바일에서도 잘 보이도록 확대
	draw_set_transform(Vector2.ZERO, vel.angle() - PI * 0.5 if mode == DIVE else 0.0, sc)
	draw_line(Vector2(-26, -6), Vector2(26, -6), outline, 4.0)
	for x in [-26.0, 26.0]:
		var rl: float = 14.0 * abs(cos(t * 35.0 + x)) + 3.0
		draw_line(Vector2(x - rl, -12), Vector2(x + rl, -12), Color(0.1, 0.1, 0.1, 0.7), 3.0)
		draw_line(Vector2(x, -6), Vector2(x, -12), outline, 3.0)
	var pts := PackedVector2Array([Vector2(-16, -8), Vector2(16, -8), Vector2(12, 10), Vector2(-12, 10)])
	draw_colored_polygon(pts, body)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, outline, 2.5)
	var blink := mode == AIM and int(t * 12.0) % 2 == 0
	draw_circle(Vector2(0, 2), 5.0, Color(1, 0.1, 0.1) if blink or mode == DIVE else Color(0.6, 0.1, 0.1))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if mode == AIM:
		var d = main.target_for(position)
		var tgt: Vector2 = d.position + Vector2(0, -60) - position
		draw_dashed_line(Vector2.ZERO, tgt, Color(1, 0.2, 0.2, 0.35), 2.0, 10.0)
