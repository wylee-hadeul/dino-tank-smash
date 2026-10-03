extends Node2D
## 폭격기. 경고 후 화면 위를 가로지르며 폭탄을 떨어뜨리고 반대편으로 빠져나간다.
## 높이 날아 보통은 물 수 없다 — 포효, 반사한 포탄, 또는 물기 범위 강화 후 점프 물기로 격추한다.

const Stages = preload("res://scripts/stages.gd")
const ShellScript = preload("res://scripts/shell.gd")

var main
var hp := 80.0
var max_hp := 80.0
var damage := 12.0
var points := 500
var gold := 15
var dead := false
var escaped := false
var flash := 0.0
var t := 0.0
var dir := 1.0
var speed := 330.0
var warn_t := 1.2
var drop_cd := 0.0


func _ready() -> void:
	hp *= Stages.hp_mult(main.stage)
	max_hp = hp
	damage *= Stages.dmg_mult(main.stage)
	dir = 1.0 if position.x < main.view.x * 0.5 else -1.0
	main.sfx.play("reflect", -6.0, 0.4)


func get_rect() -> Rect2:
	return Rect2(position.x - 70.0, position.y - 20.0, 140.0, 40.0)


func update(delta: float) -> void:
	if has_meta("puppet"):
		# 같이 하기 참가자 화면: 방장이 보낸 위치로 따라가기만 한다
		position = position.lerp(get_meta("net_pos", position), min(1.0, delta * 12.0))
		t += delta
		queue_redraw()
		return
	t += delta
	flash = max(flash - delta, 0.0)
	if warn_t > 0.0:
		warn_t -= delta
		queue_redraw()
		return
	position.x += dir * speed * delta
	drop_cd -= delta
	var d = main.target_for(position)
	var over_screen: bool = position.x > 0.0 and position.x < main.view.x
	if over_screen and drop_cd <= 0.0 and abs(d.position.x - position.x) < 380.0 and main.state == main.State.PLAYING:
		drop_cd = 0.3
		var b = main.add_shell(position + Vector2(0, 18), Vector2(dir * speed * 0.35, 0.0), damage)
		b.style = ShellScript.BOMB
	if (dir > 0.0 and position.x > main.view.x + 200.0) or (dir < 0.0 and position.x < -200.0):
		dead = true
		escaped = true
	queue_redraw()


func hit(dmg: float, _kdir := 0.0, src := "") -> void:
	if dead or warn_t > 0.0:
		return
	hp -= dmg
	flash = 0.12
	if hp <= 0.0:
		dead = true
		main.on_enemy_destroyed(position, points, 1.3, gold, src)


func _draw() -> void:
	if warn_t > 0.0:
		# 화면 가장자리 경고 표시
		var ex: float = 40.0 if dir > 0.0 else main.view.x - 40.0
		var lp := Vector2(ex - position.x, 0)
		var a: float = 0.5 + 0.5 * sin(t * 20.0)
		draw_circle(lp, 28.0, Color(1, 0.2, 0.1, 0.35 * a + 0.2))
		draw_string(ThemeDB.fallback_font, lp + Vector2(-8, 13), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1, 1, 1, a))
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(dir, 1.0))
	var body := Color("607d8b").lerp(Color.WHITE, 0.75 if flash > 0.0 else 0.0)
	var outline := Color("1c252c")
	var wing := PackedVector2Array([Vector2(10, 0), Vector2(-30, 34), Vector2(-48, 34), Vector2(-24, 0)])
	draw_colored_polygon(wing, body.darkened(0.2))
	var fus := PackedVector2Array([Vector2(-72, -6), Vector2(50, -10), Vector2(72, 0), Vector2(50, 10), Vector2(-72, 6)])
	draw_colored_polygon(fus, body)
	var closed := fus.duplicate()
	closed.append(fus[0])
	draw_polyline(closed, outline, 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-60, -6), Vector2(-74, -28), Vector2(-62, -28), Vector2(-44, -6)]), body.darkened(0.1))
	draw_colored_polygon(PackedVector2Array([Vector2(40, -8), Vector2(56, -6), Vector2(50, -1), Vector2(36, -2)]), Color("9fd8ff"))
	draw_colored_polygon(PackedVector2Array([Vector2(10, 0), Vector2(-24, -26), Vector2(-38, -26), Vector2(-24, 0)]), body.darkened(0.3))
	draw_circle(Vector2(-78, 0), 7.0 + sin(t * 40.0) * 2.0, Color(1, 0.6, 0.2, 0.7))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if hp < max_hp:
		draw_rect(Rect2(-40, -40, 80, 6), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-39, -39, 78 * max(hp, 0.0) / max_hp, 4), Color("ff5252"))
