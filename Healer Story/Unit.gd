extends Node2D
class_name Unit

signal died(unit)

@export_enum("ally", "enemy") var team: String = "ally"
@export var role: String = "warrior"

var base_role: String = "warrior"
var level: int = 1

@export var max_hp: float = 100.0
@export var attack_power: float = 10.0
@export var defense: float = 2.0
@export var move_speed: float = 70.0
@export var attack_range: float = 26.0
@export var attack_cooldown: float = 0.8
@export var body_radius: float = 14.0
@export var spacing_distance: float = 10.0
@export var spacing_strength: float = 0.65

var atk_stat: int = 0
var dex_stat: int = 0
var def_stat: int = 0
var hp_stat: int = 0

var hp: float = 0.0
var shield: float = 0.0
var counts_for_stage_progress: bool = false
var is_boss: bool = false
var is_summon: bool = false

var boss_special_interval: float = 0.0
var _boss_special_left: float = 0.0
var _attack_cd_left: float = 0.0

var _taunt_left: float = 0.0
var _guard_left: float = 0.0
var _reflect_left: float = 0.0
var _stun_left: float = 0.0
var _evade_left: float = 0.0
var _gunner_overdrive_left: float = 0.0
var _fighter_speed_left: float = 0.0
var _fighter_power_left: float = 0.0

var _attack_buff_flat: float = 0.0
var _attack_buff_left: float = 0.0
var _defense_buff_flat: float = 0.0
var _defense_buff_left: float = 0.0
var _dex_buff_flat: int = 0
var _dex_buff_left: float = 0.0
var _invulnerable_left: float = 0.0
var _exorcism_left: float = 0.0
var _corruption_attack_bonus: float = 0.0
var _corruption_dex_bonus: int = 0

var _hp_label_node: Label
var _attack_fx_left: float = 0.0
var _attack_fx_kind: String = ""
var _attack_fx_dir: Vector2 = Vector2.RIGHT
var _attack_fx_length: float = 28.0
var _hit_fx_left: float = 0.0
var _hit_fx_color: Color = Color.WHITE
var _skill_fx: Array = []
var _dead: bool = false

func _ready() -> void:
	hp = max_hp if hp <= 0.0 else hp
	_boss_special_left = boss_special_interval
	add_to_group("units")
	if team == "ally":
		add_to_group("allies")
	else:
		add_to_group("enemies")
	_create_overhead_hp_label()
	_update_overhead_hp_label()
	queue_redraw()

func setup_role_stats() -> void:
	level = 1
	atk_stat = 0
	dex_stat = 0
	def_stat = 0
	hp_stat = 0

func level_up_role() -> void:
	if _dead:
		return
	level += 1
	var ratio: float = hp / maxf(1.0, max_hp)
	match role:
		"warrior":
			atk_stat += 1
			def_stat += 3
			hp_stat += 2
			attack_power += 1.0
			defense += 3.0
			max_hp += 2.0
		"fighter":
			atk_stat += 2
			dex_stat += 2
			def_stat += 1
			hp_stat += 1
			attack_power += 2.0
			defense += 1.0
			max_hp += 1.0
		"assassin":
			atk_stat += 3
			dex_stat += 1
			hp_stat += 1
			attack_power += 3.0
			max_hp += 1.0
		"archer":
			atk_stat += 1
			dex_stat += 3
			hp_stat += 1
			attack_power += 1.0
			max_hp += 1.0
	hp = max_hp * ratio
	shield = 0.0
	_update_overhead_hp_label()

func clear_stage_only_buffs() -> void:
	_attack_buff_flat = 0.0
	_attack_buff_left = 0.0
	_defense_buff_flat = 0.0
	_defense_buff_left = 0.0
	_dex_buff_flat = 0
	_dex_buff_left = 0.0
	_invulnerable_left = 0.0
	_exorcism_left = 0.0
	_corruption_attack_bonus = 0.0
	_corruption_dex_bonus = 0
	_taunt_left = 0.0
	_guard_left = 0.0
	_reflect_left = 0.0
	_stun_left = 0.0
	_evade_left = 0.0
	_gunner_overdrive_left = 0.0
	_fighter_speed_left = 0.0
	_fighter_power_left = 0.0
	shield = 0.0
	_skill_fx.clear()

func _process(delta: float) -> void:
	if _dead:
		return
	_update_timers(delta)
	if _is_stunned():
		_update_overhead_hp_label()
		queue_redraw()
		return
	var target: Unit = _find_target()
	var spacing_vector: Vector2 = _get_spacing_vector()
	_attack_cd_left = maxf(0.0, _attack_cd_left - delta)
	if target == null:
		_move_with_bounds(spacing_vector, delta)
		_update_overhead_hp_label()
		queue_redraw()
		return
	var to_target: Vector2 = target.global_position - global_position
	var move_dir: Vector2 = Vector2.ZERO
	if to_target.length() > attack_range:
		move_dir = to_target.normalized()
	else:
		_try_attack(target)
	move_dir += spacing_vector * spacing_strength
	_move_with_bounds(move_dir, delta)
	_update_overhead_hp_label()
	queue_redraw()

func _update_timers(delta: float) -> void:
	for key in ["_attack_buff_left","_defense_buff_left","_dex_buff_left","_invulnerable_left","_exorcism_left","_taunt_left","_guard_left","_reflect_left","_stun_left","_evade_left","_gunner_overdrive_left","_fighter_speed_left","_fighter_power_left","_attack_fx_left","_hit_fx_left"]:
		set(key, maxf(0.0, float(get(key)) - delta))
	if _attack_buff_left <= 0.0:
		_attack_buff_flat = 0.0
	if _defense_buff_left <= 0.0:
		_defense_buff_flat = 0.0
	if _dex_buff_left <= 0.0:
		_dex_buff_flat = 0
	for i in range(_skill_fx.size() - 1, -1, -1):
		var fx: Dictionary = _skill_fx[i]
		fx["time_left"] = maxf(0.0, float(fx.get("time_left", 0.0)) - delta)
		if float(fx["time_left"]) <= 0.0:
			_skill_fx.remove_at(i)
		else:
			_skill_fx[i] = fx
	if is_boss and role == "boss_necromancer" and boss_special_interval > 0.0 and not _is_stunned():
		_boss_special_left -= delta
		if _boss_special_left <= 0.0:
			_boss_special_left = boss_special_interval
			_request_skeleton_summon(global_position)

func _request_skeleton_summon(origin: Vector2) -> void:
	var node: Node = self
	while node != null:
		if node.has_method("spawn_boss_skeleton_wave"):
			node.spawn_boss_skeleton_wave(origin)
			_trigger_skill_fx(1, "SUMMON", Color(0.72, 0.45, 1.0, 1.0))
			return
		node = node.get_parent()

func _create_overhead_hp_label() -> void:
	_hp_label_node = Label.new()
	_hp_label_node.size = Vector2(140, 20)
	_hp_label_node.position = Vector2(-70, -body_radius - 30.0)
	_hp_label_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hp_label_node)

func _update_overhead_hp_label() -> void:
	if _hp_label_node == null:
		return
	_hp_label_node.text = "HP %.0f/%.0f" % [hp, max_hp]
	_hp_label_node.position = Vector2(-70, -body_radius - 30.0)
	_hp_label_node.modulate = Color(1.0, 0.82, 0.82, 1.0) if team == "enemy" else Color(0.85, 1.0, 0.85, 1.0)

func _is_stunned() -> bool:
	return _stun_left > 0.0

func _find_target() -> Unit:
	var candidates: Array = get_tree().get_nodes_in_group("enemies" if team == "ally" else "allies")
	if team == "enemy":
		var taunt_target: Unit = _find_taunting_ally(candidates)
		if taunt_target != null:
			return taunt_target
	var best: Unit = null
	var best_dist: float = INF
	for c in candidates:
		if c is Unit and not c.is_dead():
			var d: float = global_position.distance_to(c.global_position)
			if d < best_dist:
				best_dist = d
				best = c
	return best

func _find_taunting_ally(candidates: Array) -> Unit:
	var best: Unit = null
	var best_dist: float = INF
	for c in candidates:
		if c is Unit and not c.is_dead() and c.role == "warrior" and c.is_taunting():
			var d: float = global_position.distance_to(c.global_position)
			if d <= 260.0 and d < best_dist:
				best_dist = d
				best = c
	return best

func _get_spacing_vector() -> Vector2:
	var units: Array = get_tree().get_nodes_in_group("allies" if team == "ally" else "enemies")
	var push: Vector2 = Vector2.ZERO
	for other in units:
		if other == self or not (other is Unit) or other.is_dead():
			continue
		var other_unit: Unit = other as Unit
		var offset: Vector2 = global_position - other_unit.global_position
		var dist: float = offset.length()
		var min_dist: float = body_radius + other_unit.body_radius + spacing_distance
		if dist > 0.0 and dist < min_dist:
			push += offset.normalized() * ((min_dist - dist) / min_dist)
	return push

func _move_with_bounds(direction: Vector2, delta: float) -> void:
	if direction.length() <= 0.0:
		return
	var next_pos: Vector2 = global_position + direction.normalized() * move_speed * delta
	var combat_rect: Rect2 = Rect2(16.0, 96.0, 1248.0, 450.0)
	var node: Node = self
	while node != null:
		if node.has_method("get_combat_bounds"):
			combat_rect = node.get_combat_bounds()
			break
		node = node.get_parent()
	next_pos.x = clampf(next_pos.x, combat_rect.position.x + body_radius, combat_rect.end.x - body_radius)
	next_pos.y = clampf(next_pos.y, combat_rect.position.y + body_radius, combat_rect.end.y - body_radius)
	global_position = next_pos

func _try_attack(target: Unit) -> void:
	if _attack_cd_left > 0.0:
		return
	if role == "warrior" and _taunt_left > 0.0:
		return
	_attack_cd_left = _get_attack_interval()
	_play_attack_effect(target)
	match role:
		"warrior": _warrior_attack(target)
		"fighter": _fighter_attack(target)
		"assassin": _assassin_attack(target)
		"archer": _archer_attack(target)
		"boss_lucifer": _lucifer_attack()
		"boss_vampire":
			target.take_damage(_get_current_attack_power(), self)
			heal(attack_power)
			show_heal_effect("DRAIN")
		_:
			target.take_damage(_get_current_attack_power(), self)

func _warrior_attack(target: Unit) -> void:
	if randf() <= 0.30:
		_taunt_left = 3.0
		_trigger_skill_fx(1, "TAUNT", Color(1.0, 0.55, 0.35, 1.0))
	if level >= 5 and randf() <= 0.30:
		_guard_left = 3.0
		_trigger_skill_fx(2, "GUARD", Color(0.45, 0.75, 1.0, 1.0))
	if level >= 10 and randf() <= 0.30:
		_reflect_left = 3.0
		_trigger_skill_fx(3, "REFLECT", Color(1.0, 0.30, 0.30, 1.0))
	target.take_damage(_get_current_attack_power(), self)

func _fighter_attack(target: Unit) -> void:
	var damage: float = _get_current_attack_power()
	if randf() <= 0.30:
		_fighter_speed_left = 3.0
		_trigger_skill_fx(1, "RUSH x2", Color(1.0, 0.85, 0.35, 1.0))
	if level >= 5 and randf() <= 0.30:
		_fighter_power_left = 3.0
		damage *= 2.0
		_trigger_skill_fx(2, "WILD x2", Color(1.0, 0.55, 0.22, 1.0))
	if level >= 10 and randf() <= 0.30:
		_trigger_skill_fx(3, "STUN WAVE", Color(1.0, 0.92, 0.45, 1.0))
		_stun_nearby_opponents(96.0, 1.0)
	target.take_damage(damage, self)

func _assassin_attack(target: Unit) -> void:
	if randf() <= 0.20:
		_evade_left = 3.0
		_trigger_skill_fx(1, "EVADE", Color(0.95, 0.95, 0.55, 1.0))
	if level >= 10 and randf() <= 0.20:
		if target.is_boss:
			target.take_true_damage(target.max_hp * 0.15, self)
		else:
			target.take_true_damage(target.hp + target.shield + 9999.0, self)
		_trigger_skill_fx(3, "EXECUTE", Color(0.95, 0.20, 0.75, 1.0))
		return
	var damage: float = _get_current_attack_power()
	if level >= 5 and randf() <= 0.20:
		damage *= 2.0
		_trigger_skill_fx(2, "SHADOW x2", Color(0.65, 0.55, 1.0, 1.0))
	target.take_damage(damage, self)

func _archer_attack(target: Unit) -> void:
	var hit_targets: Array = [target]
	if randf() <= 0.20:
		for enemy in _get_nearest_opponents(5, 240.0):
			if enemy not in hit_targets:
				hit_targets.append(enemy)
		_trigger_skill_fx(1, "MULTI SHOT", Color(0.55, 1.0, 0.55, 1.0))
	if level >= 5 and randf() <= 0.20:
		for enemy in _get_nearest_opponents(5, 280.0):
			if enemy not in hit_targets:
				hit_targets.append(enemy)
		_trigger_skill_fx(2, "PIERCE", Color(0.60, 1.0, 0.85, 1.0))
	if level >= 10 and randf() <= 0.20:
		_gunner_overdrive_left = 3.0
		_trigger_skill_fx(3, "OVERDRIVE", Color(0.45, 1.0, 0.65, 1.0))
	for enemy in hit_targets:
		if enemy != null and is_instance_valid(enemy) and not enemy.is_dead():
			enemy.take_damage(_get_current_attack_power(), self)

func _lucifer_attack() -> void:
	for enemy in _get_nearest_opponents(4, 260.0):
		enemy.take_damage(_get_current_attack_power(), self)

func _stun_nearby_opponents(radius: float, duration: float) -> void:
	for enemy in _get_opponents():
		if global_position.distance_to(enemy.global_position) <= radius:
			enemy.apply_stun(duration)

func _get_opponents() -> Array:
	var result: Array = []
	for c in get_tree().get_nodes_in_group("enemies" if team == "ally" else "allies"):
		if c is Unit and not c.is_dead():
			result.append(c)
	return result

func _get_nearest_opponents(max_count: int, max_distance: float = INF) -> Array:
	var entries: Array = []
	for enemy in _get_opponents():
		var d: float = global_position.distance_to(enemy.global_position)
		if d <= max_distance:
			entries.append({"unit": enemy, "dist": d})
	entries.sort_custom(func(a, b): return a["dist"] < b["dist"])
	var result: Array = []
	for entry in entries:
		result.append(entry["unit"])
		if result.size() >= max_count:
			break
	return result

func _get_current_attack_power() -> float:
	var value: float = attack_power + _attack_buff_flat + _corruption_attack_bonus
	if _fighter_power_left > 0.0:
		value *= 2.0
	return maxf(1.0, value)

func _get_total_defense() -> float:
	var value: float = defense + _defense_buff_flat
	if role == "warrior" and _taunt_left > 0.0:
		value += 1.0
	return maxf(0.0, value)

func _get_total_dex() -> int:
	return maxi(0, dex_stat + _dex_buff_flat + _corruption_dex_bonus)

func _get_attack_interval() -> float:
	var speed_factor: float = 1.0 + float(_get_total_dex()) * 0.08
	if _gunner_overdrive_left > 0.0:
		speed_factor *= 4.0
	if _fighter_speed_left > 0.0:
		speed_factor *= 2.0
	return maxf(0.10, attack_cooldown / speed_factor)

func take_damage(raw_damage: float, attacker: Unit = null) -> void:
	if _dead:
		return
	if _invulnerable_left > 0.0 or _guard_left > 0.0:
		_flash_hit(Color(1.0, 1.0, 0.65, 1.0))
		return
	if _evade_left > 0.0:
		_flash_hit(Color(1.0, 1.0, 0.65, 1.0))
		return
	var adjusted_damage: float = raw_damage * (2.0 if is_boss and _exorcism_left > 0.0 else 1.0)
	var reduced: float = maxf(1.0, adjusted_damage - _get_total_defense())
	if shield > 0.0:
		var absorbed: float = minf(shield, reduced)
		shield -= absorbed
		reduced -= absorbed
		if reduced <= 0.0:
			_flash_hit(Color(0.45, 0.90, 1.0, 1.0))
			return
	hp = clampf(hp - reduced, 0.0, max_hp)
	_flash_hit(Color(1.0, 0.45, 0.45, 1.0))
	if _reflect_left > 0.0 and attacker != null and is_instance_valid(attacker) and not attacker.is_dead():
		attacker.take_true_damage(reduced, self)
		_trigger_skill_fx(3, "REFLECT", Color(1.0, 0.30, 0.30, 1.0))
	if hp <= 0.0:
		_die()
	_update_overhead_hp_label()

func take_true_damage(amount: float, attacker: Unit = null) -> void:
	if _dead:
		return
	if _invulnerable_left > 0.0 or _guard_left > 0.0 or _evade_left > 0.0:
		_flash_hit(Color(1.0, 1.0, 0.65, 1.0))
		return
	var final_damage: float = maxf(1.0, amount * (2.0 if is_boss and _exorcism_left > 0.0 else 1.0))
	hp = clampf(hp - final_damage, 0.0, max_hp)
	_flash_hit(Color(1.0, 0.30, 0.30, 1.0))
	if _reflect_left > 0.0 and attacker != null and is_instance_valid(attacker) and not attacker.is_dead():
		attacker.take_true_damage(final_damage, self)
		_trigger_skill_fx(3, "REFLECT", Color(1.0, 0.30, 0.30, 1.0))
	if hp <= 0.0:
		_die()
	_update_overhead_hp_label()

func heal(amount: float) -> void:
	if _dead or amount <= 0.0:
		return
	hp = clampf(hp + amount, 0.0, max_hp)
	show_heal_effect("HEAL")
	_update_overhead_hp_label()

func apply_attack_buff(amount: float, duration: float) -> void:
	if _dead:
		return
	_attack_buff_flat = maxf(_attack_buff_flat, amount)
	_attack_buff_left = maxf(_attack_buff_left, duration)
	show_spell_effect("ATK UP", Color(1.0, 0.55, 0.30, 1.0), 1)

func apply_defense_buff(amount: float, duration: float) -> void:
	if _dead:
		return
	_defense_buff_flat = maxf(_defense_buff_flat, amount)
	_defense_buff_left = maxf(_defense_buff_left, duration)
	show_spell_effect("DEF UP", Color(0.45, 0.80, 1.0, 1.0), 2)

func apply_dex_buff(amount: int, duration: float) -> void:
	if _dead:
		return
	_dex_buff_flat = maxi(_dex_buff_flat, amount)
	_dex_buff_left = maxf(_dex_buff_left, duration)
	show_spell_effect("DEX UP", Color(0.45, 1.0, 0.60, 1.0), 3)

func apply_sacred(duration: float) -> void:
	if _dead:
		return
	_invulnerable_left = maxf(_invulnerable_left, duration)
	show_spell_effect("SACRED", Color(1.0, 1.0, 0.70, 1.0), 3)

func apply_stun(duration: float, show_popup_label: bool = true) -> void:
	if _dead:
		return
	_stun_left = maxf(_stun_left, duration)
	if show_popup_label:
		show_spell_effect("STUN", Color(0.95, 0.95, 0.55, 1.0), 1)

func apply_exorcism(duration: float) -> void:
	if _dead or not is_boss:
		return
	_exorcism_left = maxf(_exorcism_left, duration)
	apply_stun(duration, false)
	show_spell_effect("EXORCISM", Color(0.70, 1.0, 1.0, 1.0), 3)

func apply_corruption_boost(amount: int) -> void:
	if _dead:
		return
	_corruption_attack_bonus = maxf(_corruption_attack_bonus, float(amount))
	_corruption_dex_bonus = maxi(_corruption_dex_bonus, amount)
	show_spell_effect("CORRUPTION", Color(0.70, 0.35, 1.0, 1.0), 3)

func export_snapshot() -> Dictionary:
	return {
		"role": role, "base_role": base_role, "level": level, "max_hp": max_hp,
		"attack_power": attack_power, "defense": defense, "move_speed": move_speed,
		"attack_range": attack_range, "attack_cooldown": attack_cooldown, "body_radius": body_radius,
		"atk_stat": atk_stat, "dex_stat": dex_stat, "def_stat": def_stat, "hp_stat": hp_stat,
		"counts_for_stage_progress": counts_for_stage_progress, "is_boss": is_boss, "is_summon": is_summon
	}

func apply_snapshot(data: Dictionary) -> void:
	role = data.get("role", role)
	base_role = data.get("base_role", role)
	level = int(data.get("level", 1))
	max_hp = float(data.get("max_hp", max_hp))
	attack_power = float(data.get("attack_power", attack_power))
	defense = float(data.get("defense", defense))
	move_speed = float(data.get("move_speed", move_speed))
	attack_range = float(data.get("attack_range", attack_range))
	attack_cooldown = float(data.get("attack_cooldown", attack_cooldown))
	body_radius = float(data.get("body_radius", body_radius))
	atk_stat = int(data.get("atk_stat", atk_stat))
	dex_stat = int(data.get("dex_stat", dex_stat))
	def_stat = int(data.get("def_stat", def_stat))
	hp_stat = int(data.get("hp_stat", hp_stat))
	counts_for_stage_progress = bool(data.get("counts_for_stage_progress", false))
	is_boss = bool(data.get("is_boss", false))
	is_summon = bool(data.get("is_summon", false))
	hp = max_hp
	_dead = false
	_create_overhead_hp_label()
	_update_overhead_hp_label()

func is_dead() -> bool:
	return _dead

func is_taunting() -> bool:
	return _taunt_left > 0.0

func get_role_display_name() -> String:
	match role:
		"warrior":
			if level >= 10: return "crusader"
			if level >= 5: return "knight"
			return "warrior"
		"fighter":
			if level >= 10: return "untouchable"
			if level >= 5: return "wild beast"
			return "fighter"
		"assassin":
			if level >= 10: return "abyss"
			if level >= 5: return "shadow"
			return "assassin"
		"archer":
			if level >= 10: return "gunner"
			if level >= 5: return "hunter"
			return "archer"
		"monster": return "monster"
		"skeleton": return "skeleton"
		"boss_necromancer": return "Necromancer"
		"boss_vampire": return "Vampire"
		"boss_lucifer": return "Lucifer"
		_: return role

func describe_short() -> String:
	var tags: Array[String] = []
	if _taunt_left > 0.0: tags.append("Taunt")
	if _guard_left > 0.0: tags.append("Guard")
	if _reflect_left > 0.0: tags.append("Reflect")
	if _fighter_speed_left > 0.0: tags.append("ASPDx2")
	if _fighter_power_left > 0.0: tags.append("ATKx2")
	if _gunner_overdrive_left > 0.0: tags.append("ASPDx4")
	if _evade_left > 0.0: tags.append("Evade")
	if _invulnerable_left > 0.0: tags.append("Invuln")
	if _stun_left > 0.0: tags.append("Stunned")
	if _attack_buff_left > 0.0 or _defense_buff_left > 0.0 or _dex_buff_left > 0.0: tags.append("Buff")
	var suffix: String = ""
	if tags.size() > 0:
		suffix = " [" + ", ".join(tags) + "]"
	var attack_type: String = "Ranged" if _is_ranged_attacker() else "Melee"
	return "%s | Lv %d | %s | HP %.0f/%.0f | ATK %.0f DEX %d DEF %.0f%s" % [get_role_display_name(), level, attack_type, hp, max_hp, _get_current_attack_power(), _get_total_dex(), _get_total_defense(), suffix]

func _die() -> void:
	if _dead:
		return
	_dead = true
	emit_signal("died", self)
	queue_free()

func show_heal_effect(label_text: String = "HEAL") -> void:
	show_spell_effect(label_text, Color(0.45, 1.0, 0.60, 1.0), 1)

func show_spell_effect(label_text: String, color: Color, tier: int = 1) -> void:
	_trigger_skill_fx(tier, label_text, color)

func _flash_hit(color: Color) -> void:
	_hit_fx_left = 0.12
	_hit_fx_color = color
	queue_redraw()

func _play_attack_effect(target: Unit) -> void:
	_attack_fx_left = 0.14
	_attack_fx_kind = "ranged" if _is_ranged_attacker() else "melee"
	_attack_fx_dir = Vector2.RIGHT if team == "ally" else Vector2.LEFT
	_attack_fx_length = body_radius + 26.0
	if target != null and is_instance_valid(target):
		var delta_pos: Vector2 = target.global_position - global_position
		if delta_pos.length() > 0.0:
			_attack_fx_dir = delta_pos.normalized()
			_attack_fx_length = minf(maxf(26.0, delta_pos.length()), attack_range + 70.0)
	queue_redraw()

func _trigger_skill_fx(tier: int, label_text: String, color: Color) -> void:
	_skill_fx.append({"tier": tier, "label": label_text, "color": color, "duration": 0.52, "time_left": 0.52})
	_spawn_popup(label_text, color)
	queue_redraw()

func _spawn_popup(label_text: String, color: Color) -> void:
	var pop: Label = Label.new()
	pop.text = label_text
	pop.modulate = color
	pop.position = Vector2(-42.0, -body_radius - 34.0)
	add_child(pop)
	var tween: Tween = create_tween()
	tween.tween_property(pop, "position:y", pop.position.y - 22.0, 0.55)
	tween.parallel().tween_property(pop, "modulate:a", 0.0, 0.55)
	tween.finished.connect(func() -> void:
		if is_instance_valid(pop):
			pop.queue_free()
	)

func _is_ranged_attacker() -> bool:
	return role == "archer" or role == "assassin" or role == "boss_necromancer"

func _draw() -> void:
	var color: Color = Color.WHITE
	if team == "enemy":
		match role:
			"boss_necromancer": color = Color(0.55, 0.15, 0.70)
			"boss_vampire": color = Color(0.70, 0.08, 0.08)
			"boss_lucifer": color = Color(0.95, 0.45, 0.10)
			"skeleton": color = Color(0.85, 0.85, 0.85)
			_: color = Color(0.85, 0.2, 0.2)
	else:
		match role:
			"warrior": color = Color(0.30, 0.50, 1.00)
			"fighter": color = Color(1.00, 0.45, 0.20)
			"archer": color = Color(0.30, 0.90, 0.40)
			"assassin": color = Color(1.00, 0.85, 0.25)
	draw_circle(Vector2.ZERO, body_radius, color)
	if _attack_fx_left > 0.0:
		var a: float = clampf(_attack_fx_left / 0.14, 0.0, 1.0)
		if _attack_fx_kind == "melee":
			var ang: float = _attack_fx_dir.angle()
			draw_arc(Vector2.ZERO, body_radius + 10.0, ang - 0.65, ang + 0.65, 18, Color(1,1,1,a), 3.0)
			draw_line(_attack_fx_dir * (body_radius * 0.5), _attack_fx_dir * (body_radius + 18.0), Color(1.0, 0.9, 0.9, a), 2.5)
		else:
			draw_line(_attack_fx_dir * body_radius * 0.4, _attack_fx_dir * _attack_fx_length, Color(1.0, 0.95, 0.60, a), 3.0)
			draw_circle(_attack_fx_dir * _attack_fx_length, 4.0, Color(1.0, 0.95, 0.60, a))
	if _hit_fx_left > 0.0:
		var h: float = clampf(_hit_fx_left / 0.12, 0.0, 1.0)
		draw_arc(Vector2.ZERO, body_radius + 6.0, 0.0, TAU, 24, Color(_hit_fx_color.r, _hit_fx_color.g, _hit_fx_color.b, h), 2.0)
	for fx in _skill_fx:
		var left: float = float(fx.get("time_left", 0.0))
		var total: float = maxf(0.01, float(fx.get("duration", 0.52)))
		var ratio: float = clampf(left / total, 0.0, 1.0)
		var fx_color: Color = fx.get("color", Color.WHITE) as Color
		var c: Color = Color(fx_color.r, fx_color.g, fx_color.b, ratio)
		match int(fx.get("tier", 1)):
			1:
				draw_arc(Vector2.ZERO, body_radius + 12.0, 0.0, TAU, 24, c, 2.5)
			2:
				draw_arc(Vector2.ZERO, body_radius + 10.0, 0.0, TAU, 24, c, 2.0)
				draw_arc(Vector2.ZERO, body_radius + 17.0, 0.0, TAU, 24, c, 1.5)
			3:
				draw_arc(Vector2.ZERO, body_radius + 9.0, 0.0, TAU, 24, c, 2.0)
				draw_arc(Vector2.ZERO, body_radius + 16.0, 0.0, TAU, 24, c, 1.6)
				for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
					draw_line(dir * (body_radius + 4.0), dir * (body_radius + 18.0), c, 2.0)
	if _taunt_left > 0.0: draw_arc(Vector2.ZERO, body_radius + 7.0, 0.0, TAU, 32, Color(1.0, 0.3, 0.3), 2.0)
	if _guard_left > 0.0: draw_arc(Vector2.ZERO, body_radius + 9.0, 0.0, TAU, 32, Color(0.45, 0.75, 1.0), 2.0)
	if _reflect_left > 0.0: draw_arc(Vector2.ZERO, body_radius + 11.0, 0.0, TAU, 32, Color(1.0, 0.35, 0.35), 2.0)
	if _fighter_speed_left > 0.0: draw_arc(Vector2.ZERO, body_radius + 5.0, 0.0, TAU, 24, Color(1.0, 0.85, 0.35), 2.0)
	if _fighter_power_left > 0.0: draw_arc(Vector2.ZERO, body_radius + 8.0, 0.0, TAU, 24, Color(1.0, 0.55, 0.22), 2.0)
	if _gunner_overdrive_left > 0.0: draw_arc(Vector2.ZERO, body_radius + 5.0, 0.0, TAU, 24, Color(0.6, 1.0, 0.6), 2.0)
	if _invulnerable_left > 0.0: draw_arc(Vector2.ZERO, body_radius + 8.0, 0.0, TAU, 32, Color(1.0, 1.0, 0.7), 2.0)
	if _stun_left > 0.0: draw_arc(Vector2.ZERO, body_radius + 11.0, 0.0, TAU, 24, Color(1.0, 1.0, 0.5), 1.8)
