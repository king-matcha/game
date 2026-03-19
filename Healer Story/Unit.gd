extends Node2D
class_name Unit

signal died(unit)

@export_enum("ally", "enemy") var team: String = "ally"
@export var role: String = "warrior"

@export var max_hp: float = 100.0
@export var attack_power: float = 10.0
@export var defense: float = 2.0
@export var move_speed: float = 70.0
@export var attack_range: float = 26.0
@export var attack_cooldown: float = 0.8
@export var body_radius: float = 14.0

# 같은 팀끼리 너무 겹치지 않도록 하는 간격 유지
@export var spacing_distance: float = 10.0
@export var spacing_strength: float = 0.65

var hp: float = 0.0
var _attack_cd_left: float = 0.0

var _attack_buff_mult: float = 1.0
var _defense_buff_mult: float = 1.0
var _move_speed_mult: float = 1.0
var _attack_speed_mult: float = 1.0

var _attack_buff_left: float = 0.0
var _defense_buff_left: float = 0.0
var _move_speed_buff_left: float = 0.0
var _attack_speed_buff_left: float = 0.0

var _dead: bool = false

func _ready() -> void:
	hp = max_hp

	add_to_group("units")

	if team == "ally":
		add_to_group("allies")
	else:
		add_to_group("enemies")

	queue_redraw()

func _process(delta: float) -> void:
	if _dead:
		return

	_update_buffs(delta)

	_attack_cd_left = max(0.0, _attack_cd_left - delta)

	var target: Unit = _find_target()
	var spacing_vector: Vector2 = _get_spacing_vector()

	if target == null:
		_move_with_bounds(spacing_vector, delta)
		queue_redraw()
		return

	var to_target: Vector2 = target.global_position - global_position
	var distance: float = to_target.length()
	var move_dir: Vector2 = Vector2.ZERO

	if distance > attack_range:
		if distance > 0.0:
			move_dir = to_target.normalized()
	else:
		_try_attack(target)

	move_dir += spacing_vector * spacing_strength
	_move_with_bounds(move_dir, delta)

	queue_redraw()

func _update_buffs(delta: float) -> void:
	if _attack_buff_left > 0.0:
		_attack_buff_left -= delta
		if _attack_buff_left <= 0.0:
			_attack_buff_left = 0.0
			_attack_buff_mult = 1.0

	if _defense_buff_left > 0.0:
		_defense_buff_left -= delta
		if _defense_buff_left <= 0.0:
			_defense_buff_left = 0.0
			_defense_buff_mult = 1.0

	if _move_speed_buff_left > 0.0:
		_move_speed_buff_left -= delta
		if _move_speed_buff_left <= 0.0:
			_move_speed_buff_left = 0.0
			_move_speed_mult = 1.0

	if _attack_speed_buff_left > 0.0:
		_attack_speed_buff_left -= delta
		if _attack_speed_buff_left <= 0.0:
			_attack_speed_buff_left = 0.0
			_attack_speed_mult = 1.0

func _find_target() -> Unit:
	var group_name: String = "enemies" if team == "ally" else "allies"
	var candidates: Array = get_tree().get_nodes_in_group(group_name)
	var best: Unit = null
	var best_dist: float = INF

	for c in candidates:
		if c is Unit and not c.is_dead():
			var d: float = global_position.distance_to(c.global_position)
			if d < best_dist:
				best_dist = d
				best = c

	return best

func _get_spacing_vector() -> Vector2:
	var group_name: String = "allies" if team == "ally" else "enemies"
	var units: Array = get_tree().get_nodes_in_group(group_name)
	var push: Vector2 = Vector2.ZERO

	for other in units:
		if other == self:
			continue
		if not (other is Unit):
			continue
		if other.is_dead():
			continue

		var offset: Vector2 = global_position - other.global_position
		var dist: float = offset.length()
		var min_dist: float = body_radius + other.body_radius + spacing_distance

		if dist > 0.0 and dist < min_dist:
			var ratio: float = (min_dist - dist) / min_dist
			push += offset.normalized() * ratio

	return push

func _move_with_bounds(direction: Vector2, delta: float) -> void:
	if direction.length() <= 0.0:
		return

	var velocity: Vector2 = direction.normalized() * move_speed * _move_speed_mult
	var next_pos: Vector2 = global_position + velocity * delta
	var rect: Rect2 = get_viewport_rect()

	next_pos.x = clamp(next_pos.x, body_radius, rect.size.x - body_radius)
	next_pos.y = clamp(next_pos.y, body_radius, rect.size.y - body_radius)

	global_position = next_pos

func _try_attack(target: Unit) -> void:
	if _attack_cd_left > 0.0:
		return

	_attack_cd_left = attack_cooldown / _attack_speed_mult
	target.take_damage(attack_power * _attack_buff_mult)

func take_damage(raw_damage: float) -> void:
	if _dead:
		return

	var reduced: float = max(1.0, raw_damage - defense * _defense_buff_mult)
	hp = clamp(hp - reduced, 0.0, max_hp)

	if hp <= 0.0:
		_die()

	queue_redraw()

func heal(amount: float) -> void:
	if _dead:
		return

	hp = clamp(hp + amount, 0.0, max_hp)
	queue_redraw()

func apply_attack_buff(multiplier: float, duration: float) -> void:
	if _dead:
		return

	_attack_buff_mult = max(_attack_buff_mult, multiplier)
	_attack_buff_left = max(_attack_buff_left, duration)

func apply_defense_buff(multiplier: float, duration: float) -> void:
	if _dead:
		return

	_defense_buff_mult = max(_defense_buff_mult, multiplier)
	_defense_buff_left = max(_defense_buff_left, duration)

func apply_move_speed_buff(multiplier: float, duration: float) -> void:
	if _dead:
		return

	_move_speed_mult = max(_move_speed_mult, multiplier)
	_move_speed_buff_left = max(_move_speed_buff_left, duration)

func apply_attack_speed_buff(multiplier: float, duration: float) -> void:
	if _dead:
		return

	_attack_speed_mult = max(_attack_speed_mult, multiplier)
	_attack_speed_buff_left = max(_attack_speed_buff_left, duration)

func is_dead() -> bool:
	return _dead

func _die() -> void:
	if _dead:
		return

	_dead = true
	emit_signal("died", self)
	queue_free()

func _draw() -> void:
	var color: Color = Color.WHITE

	if team == "enemy":
		if role == "boss":
			color = Color(0.55, 0.1, 0.1)
		else:
			color = Color(0.85, 0.2, 0.2)
	else:
		match role:
			"warrior":
				color = Color(0.3, 0.5, 1.0)
			"mage":
				color = Color(0.8, 0.4, 1.0)
			"archer":
				color = Color(0.3, 0.9, 0.4)
			"assassin":
				color = Color(1.0, 0.85, 0.25)
			_:
				color = Color(0.9, 0.9, 0.9)

	draw_circle(Vector2.ZERO, body_radius, color)

	var w: float = 34.0
	var ratio: float = hp / max_hp
	draw_rect(Rect2(Vector2(-w / 2.0, -26.0), Vector2(w, 4.0)), Color(0.2, 0.2, 0.2))
	draw_rect(Rect2(Vector2(-w / 2.0, -26.0), Vector2(w * ratio, 4.0)), Color(0.2, 1.0, 0.2))
