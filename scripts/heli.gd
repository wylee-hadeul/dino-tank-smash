extends Node2D
## 공격 헬기. 공룡 위에서 폭탄을 떨어뜨린다. 점프해서 물어야 한다.

const Stages = preload("res://scripts/stages.gd")
const ShellScript = preload("res://scripts/shell.gd")

var main
var hp := 60.0
var max_hp := 60.0
var dir := 1.0
var vel_x := 0.0
var hover_y := 0.0
var side := 1.0
var flash := 0.0
var drop_cd := 2.0
var dead := false
var t := 0.0
var points := 200


var gold := 8
var bomb_dmg := 10.0


func _ready() -> void:
	hp *= Stages.hp_mult(main.stage)
	max_hp = hp
	bomb_dmg *= Stages.dmg_mult(main.stage)
	hover_y = position.y
	side = 1.0 if main.rng.randf() < 0.5 else -1.0
	drop_cd = main.rng.randf_range(1.5, 2.5)


func get_rect() -> Rect2:
	return Rect2(position.x - 62.0, position.y - 28.0, 124.0, 56.0)


func update(delta: float) -> void:
	if has_meta("puppet"):
		# 같이 하기 참가자 화면: 방장이 보낸 위치로 따라가기만 한다
		position = position.lerp(get_meta("net_pos", position), min(1.0, delta * 12.0))
		t += delta
		queue_redraw()
		return
	t += delta
	flash = max(flash - delta, 0.0)
	var d = main.target_for(position)
	var target_x: float = clamp(d.position.x + side * 140.0, 90.0, main.view.x - 90.0)
	if fmod(t, 6.0) < delta:
		side = -side
	var dx: float = target_x - position.x
	vel_x = move_toward(vel_x, clamp(dx * 1.5, -230.0, 230.0), 300.0 * delta)
	position.x += vel_x * delta
	position.y = hover_y + sin(t * 2.2) * 14.0
	if abs(vel_x) > 10.0:
		dir = sign(vel_x)
	var on_screen: bool = position.x > 20.0 and position.x < main.view.x - 20.0
	if main.state == main.State.PLAYING and not d.dead and on_screen:
		drop_cd -= delta
		if drop_cd <= 0.0 and abs(d.position.x - position.x) < 260.0:
			drop_cd = 2.6 * Stages.fire_mult(main.stage)
			var b = main.add_shell(position + Vector2(0, 26), Vector2(vel_x * 0.6, 60.0), bomb_dmg)
			b.style = ShellScript.BOMB
			main.sfx.play("jump", -10.0, 0.6)
	queue_redraw()


func hit(dmg: float, _kdir := 0.0, src := "") -> void:
	if dead:
		return
	hp -= dmg
	flash = 0.12
	if hp <= 0.0:
		dead = true
		main.on_enemy_destroyed(position, points, 1.0, gold, src)
		main.fx.debris(position, Color("566b7a"), 12)


func _c(col: Color) -> Color:
	return col.lerp(Color.WHITE, 0.75) if flash > 0.0 else col


func _draw() -> void:
	var tilt: float = clamp(vel_x / 230.0, -1.0, 1.0) * 0.18
	draw_set_transform(Vector2.ZERO, tilt, Vector2(dir, 1.0))
	var body := Color("566b7a")
	var outline := Color("1c252c")
	# 꼬리
	draw_colored_polygon(PackedVector2Array([Vector2(-30, -10), Vector2(-100, -6), Vector2(-104, 2), Vector2(-30, 10)]), _c(body))
	var tr := Vector2(-100, -4)
	var spin := sin(t * 40.0)
	draw_line(tr + Vector2(0, -16 * spin), tr + Vector2(0, 16 * spin), outline, 4.0)
	# 동체
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(Vector2(cos(a) * 52.0, sin(a) * 26.0))
	draw_colored_polygon(pts, _c(body))
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, outline, 3.0, true)
	# 조종석
	draw_colored_polygon(PackedVector2Array([Vector2(14, -20), Vector2(44, -12), Vector2(50, 4), Vector2(14, 4)]), Color("9fd8ff"))
	# 스키드
	draw_line(Vector2(-30, 26), Vector2(-24, 36), outline, 3.0)
	draw_line(Vector2(24, 26), Vector2(18, 36), outline, 3.0)
	draw_line(Vector2(-44, 36), Vector2(40, 36), outline, 4.0)
	# 메인 로터
	draw_line(Vector2(0, -26), Vector2(0, -36), outline, 5.0)
	var rl: float = 90.0 * abs(cos(t * 30.0)) + 20.0
	draw_line(Vector2(-rl, -38), Vector2(rl, -38), Color(0.1, 0.1, 0.1, 0.8), 4.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if hp < max_hp:
		draw_rect(Rect2(-40, -56, 80, 6), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-39, -55, 78 * max(hp, 0.0) / max_hp, 4), Color("ff5252"))
