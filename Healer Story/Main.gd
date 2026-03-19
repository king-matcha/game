extends Node2D

const SCREEN_W: float = 1280.0
const SCREEN_H: float = 720.0
const KILLS_TO_CLEAR: int = 10

const WARRIOR_START_POS: Vector2 = Vector2(180, 180)
const MAGE_START_POS: Vector2 = Vector2(140, 300)
const ARCHER_START_POS: Vector2 = Vector2(180, 430)
const ASSASSIN_START_POS: Vector2 = Vector2(240, 560)

var stage: int = 1
var healer_level: int = 1
var squad_level: int = 1

var kills_this_stage: int = 0
var spawned_this_stage: int = 0
var boss_spawned_this_stage: bool = false
var boss_killed_this_stage: bool = false
var game_over: bool = false

var divine_power: int = 3
var agility: int = 3

var heal_cd_left: float = 0.0
var atk_buff_cd_left: float = 0.0
var def_buff_cd_left: float = 0.0
var move_buff_cd_left: float = 0.0
var atk_speed_buff_cd_left: float = 0.0

var spawn_interval: float = 1.0
var spawn_left: float = 1.0

var hud_label: Label
var help_label: Label
var message_label: Label

var warrior_ref: Unit = null
var mage_ref: Unit = null
var archer_ref: Unit = null
var assassin_ref: Unit = null

func _ready() -> void:
	randomize()
	_setup_window()
	_create_ui()
	_spawn_allies()
	_show_message("Stage 1 Start!")

func _process(delta: float) -> void:
	if game_over:
		return

	heal_cd_left = max(0.0, heal_cd_left - delta)
	atk_buff_cd_left = max(0.0, atk_buff_cd_left - delta)
	def_buff_cd_left = max(0.0, def_buff_cd_left - delta)
	move_buff_cd_left = max(0.0, move_buff_cd_left - delta)
	atk_speed_buff_cd_left = max(0.0, atk_speed_buff_cd_left - delta)

	_spawn_loop(delta)
	_check_stage_clear()
	_check_game_over()
	_update_ui()

func _unhandled_input(event: InputEvent) -> void:
	if game_over:
		if event is InputEventMouseButton and event.pressed:
			get_tree().reload_current_scene()
		elif event is InputEventScreenTouch and event.pressed:
			get_tree().reload_current_scene()
		return

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			_cast_attack_buff()
		elif event.keycode == KEY_2:
			_cast_defense_buff()
		elif event.keycode == KEY_3:
			_cast_move_speed_buff()
		elif event.keycode == KEY_4:
			_cast_attack_speed_buff()

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_heal_at(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_try_heal_at(event.position)

func _setup_window() -> void:
	if ProjectSettings.has_setting("display/window/size/viewport_width"):
		ProjectSettings.set_setting("display/window/size/viewport_width", int(SCREEN_W))
		ProjectSettings.set_setting("display/window/size/viewport_height", int(SCREEN_H))

func _create_ui() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	add_child(canvas)

	hud_label = Label.new()
	hud_label.position = Vector2(16, 12)
	hud_label.size = Vector2(1100, 160)
	canvas.add_child(hud_label)

	help_label = Label.new()
	help_label.position = Vector2(16, 126)
	help_label.text = "Controls: Click/Tap=Heal | 1=ATK | 2=DEF | 3=Move Speed | 4=Attack Speed"
	canvas.add_child(help_label)

	message_label = Label.new()
	message_label.position = Vector2(430, 18)
	message_label.scale = Vector2(1.4, 1.4)
	canvas.add_child(message_label)

func _spawn_allies() -> void:
	warrior_ref = _spawn_ally("warrior", WARRIOR_START_POS, 180.0, 12.0, 5.0, 65.0, 28.0, 0.7)
	mage_ref = _spawn_ally("mage", MAGE_START_POS, 100.0, 18.0, 2.0, 55.0, 120.0, 1.2)
	archer_ref = _spawn_ally("archer", ARCHER_START_POS, 110.0, 15.0, 3.0, 60.0, 150.0, 0.9)
	assassin_ref = _spawn_ally("assassin", ASSASSIN_START_POS, 90.0, 20.0, 2.0, 95.0, 24.0, 0.5)

func _spawn_ally(role: String, pos: Vector2, hp: float, atk: float, defense_value: float, speed: float, attack_range_value: float, cooldown: float) -> Unit:
	var u: Unit = Unit.new()
	u.team = "ally"
	u.role = role
	u.global_position = pos
	u.max_hp = hp
	u.attack_power = atk
	u.defense = defense_value
	u.move_speed = speed
	u.attack_range = attack_range_value
	u.attack_cooldown = cooldown
	u.body_radius = 16.0
	add_child(u)
	u.died.connect(_on_unit_died)
	return u

func _spawn_enemy() -> void:
	if spawned_this_stage >= KILLS_TO_CLEAR:
		return

	var e: Unit = Unit.new()
	e.team = "enemy"
	e.role = "monster"
	e.global_position = Vector2(
		randf_range(920.0, 1180.0),
		randf_range(120.0, 620.0)
	)

	e.max_hp = 55.0 + stage * 18.0
	e.attack_power = 7.0 + stage * 2.2
	e.defense = 1.0 + stage * 0.7
	e.move_speed = 48.0 + stage * 2.0
	e.attack_range = 24.0
	e.attack_cooldown = max(0.45, 0.95 - stage * 0.03)
	e.body_radius = 14.0

	add_child(e)
	e.died.connect(_on_unit_died)

	spawned_this_stage += 1

func _spawn_boss() -> void:
	if boss_spawned_this_stage:
		return

	var boss: Unit = Unit.new()
	boss.team = "enemy"
	boss.role = "boss"
	boss.global_position = Vector2(1080.0, 360.0)

	boss.max_hp = 250.0 + stage * 80.0
	boss.attack_power = 18.0 + stage * 4.0
	boss.defense = 4.0 + stage * 1.2
	boss.move_speed = 42.0 + stage * 1.5
	boss.attack_range = 32.0
	boss.attack_cooldown = max(0.55, 1.1 - stage * 0.03)
	boss.body_radius = 24.0

	add_child(boss)
	boss.died.connect(_on_unit_died)

	boss_spawned_this_stage = true
	_show_message("Boss Appears!")

func _spawn_loop(delta: float) -> void:
	spawn_left -= delta
	if spawn_left <= 0.0:
		spawn_left = spawn_interval
		_spawn_enemy()

	if spawned_this_stage >= KILLS_TO_CLEAR and not boss_spawned_this_stage:
		_spawn_boss()

func _on_unit_died(unit: Unit) -> void:
	if unit.team == "enemy":
		if unit.role == "boss":
			boss_killed_this_stage = true
		else:
			kills_this_stage += 1
	else:
		if unit == warrior_ref:
			warrior_ref = null
		elif unit == mage_ref:
			mage_ref = null
		elif unit == archer_ref:
			archer_ref = null
		elif unit == assassin_ref:
			assassin_ref = null

func _check_stage_clear() -> void:
	var no_enemies_left: bool = get_tree().get_nodes_in_group("enemies").size() == 0
	var normal_clear: bool = kills_this_stage >= KILLS_TO_CLEAR
	var boss_clear: bool = boss_killed_this_stage

	if normal_clear and boss_clear and no_enemies_left:
		_prepare_next_stage()

func _prepare_next_stage() -> void:
	stage += 1
	_level_up_healer()
	_level_up_squad()

	kills_this_stage = 0
	spawned_this_stage = 0
	boss_spawned_this_stage = false
	boss_killed_this_stage = false
	spawn_interval = max(0.35, 1.0 - stage * 0.05)
	spawn_left = 1.0

	_reset_allies_for_next_stage()

	_show_message("Level Up! Stage %d Start!" % stage)

func _level_up_healer() -> void:
	healer_level += 1
	divine_power += 1
	agility += 1

func _level_up_squad() -> void:
	squad_level += 1

	_level_up_unit(warrior_ref, 22.0, 2.5, 0.8)
	_level_up_unit(mage_ref, 14.0, 3.0, 0.5)
	_level_up_unit(archer_ref, 16.0, 2.4, 0.6)
	_level_up_unit(assassin_ref, 12.0, 3.2, 0.4)

func _level_up_unit(unit_ref, hp_gain: float, atk_gain: float, defense_gain: float) -> void:
	if unit_ref == null:
		return
	if not is_instance_valid(unit_ref):
		return
	if not (unit_ref is Unit):
		return
	if unit_ref.is_dead():
		return

	unit_ref.max_hp += hp_gain
	unit_ref.attack_power += atk_gain
	unit_ref.defense += defense_gain
	unit_ref.hp = unit_ref.max_hp

func _reset_allies_for_next_stage() -> void:
	if warrior_ref != null and is_instance_valid(warrior_ref) and not warrior_ref.is_dead():
		warrior_ref.global_position = WARRIOR_START_POS
		warrior_ref.hp = warrior_ref.max_hp

	if mage_ref != null and is_instance_valid(mage_ref) and not mage_ref.is_dead():
		mage_ref.global_position = MAGE_START_POS
		mage_ref.hp = mage_ref.max_hp

	if archer_ref != null and is_instance_valid(archer_ref) and not archer_ref.is_dead():
		archer_ref.global_position = ARCHER_START_POS
		archer_ref.hp = archer_ref.max_hp

	if assassin_ref != null and is_instance_valid(assassin_ref) and not assassin_ref.is_dead():
		assassin_ref.global_position = ASSASSIN_START_POS
		assassin_ref.hp = assassin_ref.max_hp

func _check_game_over() -> void:
	var alive_allies: int = 0
	var allies: Array = get_tree().get_nodes_in_group("allies")

	for ally_node in allies:
		if ally_node is Unit and not ally_node.is_dead():
			alive_allies += 1

	if alive_allies <= 0:
		game_over = true
		_show_message("Game Over - Click/Tap to Restart")

func _update_ui() -> void:
	var alive_allies: int = 0
	var allies: Array = get_tree().get_nodes_in_group("allies")

	for ally_node in allies:
		if ally_node is Unit and not ally_node.is_dead():
			alive_allies += 1

	var boss_text: String = "Not Spawned"
	if boss_spawned_this_stage and not boss_killed_this_stage:
		boss_text = "Fighting"
	elif boss_killed_this_stage:
		boss_text = "Defeated"

	hud_label.text = "Stage: %d   Healer Lv: %d   Squad Lv: %d   Kill: %d/%d   Boss: %s   Allies: %d\nDivine Power: %d   Agility: %d   Heal CD: %.1f\nATK Buff: %.1f   DEF Buff: %.1f   Move Buff: %.1f   ATK Speed Buff: %.1f" % [
		stage, healer_level, squad_level, kills_this_stage, KILLS_TO_CLEAR, boss_text, alive_allies,
		divine_power, agility, heal_cd_left,
		atk_buff_cd_left, def_buff_cd_left, move_buff_cd_left, atk_speed_buff_cd_left
	]

func _try_heal_at(screen_pos: Vector2) -> void:
	if heal_cd_left > 0.0:
		return

	var ally: Unit = _find_clicked_ally(screen_pos)
	if ally == null:
		return

	ally.heal(_heal_amount())
	heal_cd_left = _heal_cooldown()
	_show_message("%s Healed!" % ally.role)

func _find_clicked_ally(screen_pos: Vector2) -> Unit:
	var best: Unit = null
	var best_dist: float = 999999.0
	var allies: Array = get_tree().get_nodes_in_group("allies")

	for ally_node in allies:
		if ally_node is Unit and not ally_node.is_dead():
			var d: float = ally_node.global_position.distance_to(screen_pos)
			if d < 42.0 and d < best_dist:
				best_dist = d
				best = ally_node

	return best

func _cast_attack_buff() -> void:
	if atk_buff_cd_left > 0.0:
		return

	for ally_node in get_tree().get_nodes_in_group("allies"):
		if ally_node is Unit and not ally_node.is_dead():
			ally_node.apply_attack_buff(1.45, 5.0)

	atk_buff_cd_left = 8.0
	_show_message("Attack Buff!")

func _cast_defense_buff() -> void:
	if def_buff_cd_left > 0.0:
		return

	for ally_node in get_tree().get_nodes_in_group("allies"):
		if ally_node is Unit and not ally_node.is_dead():
			ally_node.apply_defense_buff(2.0, 5.0)

	def_buff_cd_left = 10.0
	_show_message("Defense Buff!")

func _cast_move_speed_buff() -> void:
	if move_buff_cd_left > 0.0:
		return

	for ally_node in get_tree().get_nodes_in_group("allies"):
		if ally_node is Unit and not ally_node.is_dead():
			ally_node.apply_move_speed_buff(1.5, 5.0)

	move_buff_cd_left = 9.0
	_show_message("Move Speed Buff!")

func _cast_attack_speed_buff() -> void:
	if atk_speed_buff_cd_left > 0.0:
		return

	for ally_node in get_tree().get_nodes_in_group("allies"):
		if ally_node is Unit and not ally_node.is_dead():
			ally_node.apply_attack_speed_buff(1.6, 5.0)

	atk_speed_buff_cd_left = 9.0
	_show_message("Attack Speed Buff!")

func _heal_amount() -> float:
	return 24.0 + divine_power * 10.0

func _heal_cooldown() -> float:
	return max(0.22, 1.2 - agility * 0.12)

func _show_message(text: String) -> void:
	message_label.text = text

	var timer: SceneTreeTimer = get_tree().create_timer(1.5)
	timer.timeout.connect(_clear_message)

func _clear_message() -> void:
	if is_instance_valid(message_label):
		message_label.text = ""
