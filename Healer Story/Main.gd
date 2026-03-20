extends Node2D

const SCREEN_W: float = 1280.0
const SCREEN_H: float = 720.0
const KILLS_TO_BOSS_OR_CLEAR: int = 10
const FINAL_STAGE: int = 15

const TOP_PANEL_H: float = 104.0
const BOTTOM_PANEL_Y: float = 500.0
const BOTTOM_PANEL_H: float = 220.0
const COMBAT_TOP: float = TOP_PANEL_H + 14.0
const COMBAT_BOTTOM: float = BOTTOM_PANEL_Y - 14.0

const WARRIOR_START_POS: Vector2 = Vector2(250, 320)
const FIGHTER_START_POS: Vector2 = Vector2(285, 355)
const ARCHER_START_POS: Vector2 = Vector2(320, 320)
const ASSASSIN_START_POS: Vector2 = Vector2(355, 355)

const INTRO_TITLE: String = "INTRO"
const INTRO_TEXT_EN: String = "A guild request arrives: rescue a child kidnapped by monsters.\nA squad of Warrior, Fighter, Assassin, Archer, and Healer sets out on the mission.\nWhy did the monsters kidnap the child instead of killing the child?\nEven so, the reward is rich enough to live on for a lifetime.\nNow, the hunt begins."
const VICTORY_TITLE: String = "VICTORY"
const VICTORY_TEXT_EN: String = "The squad stops the Demon King's revival and rescues the child.\nThe client turns out to be the king.\nWith a generous reward, each member goes on to live a happy life."
const DEFEAT_TITLE: String = "DEFEAT"
const DEFEAT_TEXT_EN: String = "The rescue has failed.\nDarkness begins to swallow the world."

const BEGIN_PROMPT: String = "Press Enter / Space / Left Click to begin"
const RESTART_PROMPT: String = "Press Enter / Space / Left Click to restart"

enum ScreenState { INTRO, COMBAT, VICTORY, DEFEAT }

var screen_state: int = ScreenState.INTRO

var stage: int = 1
var healer_level: int = 1
var divine_power: int = 1
var regular_kills_this_stage: int = 0
var spawned_regular_this_stage: int = 0
var boss_spawned: bool = false
var boss_defeated: bool = false

var skill_cd := {"single_heal": 0.0, "buff": 0.0, "sacred": 0.0}
var exorcism_used: bool = false
var resurrection_used: bool = false
var corruption_used: bool = false

var battle_root: Node2D
var background_canvas: CanvasLayer
var battle_canvas: CanvasLayer
var screen_canvas: CanvasLayer

var background_sky_rect: ColorRect
var background_mid_rect: ColorRect
var background_ground_rect: ColorRect
var top_panel_rect: ColorRect

var status_label: Label
var cooldown_label: Label
var help_label: Label
var message_label: Label
var healer_stats_label: Label
var squad_left_label: Label
var squad_right_label: Label
var screen_title_label: Label
var screen_body_label: Label
var screen_prompt_label: Label

var _message_ticket: int = 0

var warrior_ref: Unit = null
var fighter_ref: Unit = null
var archer_ref: Unit = null
var assassin_ref: Unit = null
var current_boss: Unit = null
var dead_allies: Array = []

func _ready() -> void:
	randomize()
	_create_roots()
	_create_background_ui()
	_create_battle_ui()
	_create_screen_ui()
	_reset_run_state()
	_show_intro_screen()

func get_combat_bounds() -> Rect2:
	return Rect2(16.0, COMBAT_TOP, SCREEN_W - 32.0, COMBAT_BOTTOM - COMBAT_TOP)

func _process(delta: float) -> void:
	if screen_state != ScreenState.COMBAT:
		return
	for key in skill_cd.keys():
		skill_cd[key] = max(0.0, float(skill_cd[key]) - delta)
	_maybe_spawn_boss()
	_check_stage_clear()
	_check_game_over()
	_update_ui()

func _unhandled_input(event: InputEvent) -> void:
	if screen_state == ScreenState.INTRO:
		if _is_confirm_input(event):
			_start_game()
		return
	if screen_state == ScreenState.VICTORY or screen_state == ScreenState.DEFEAT:
		if _is_confirm_input(event):
			get_tree().reload_current_scene()
		return
	if screen_state != ScreenState.COMBAT:
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_cast_buff()
			KEY_2:
				_cast_sacred()
			KEY_3:
				_cast_exorcism()
			KEY_4:
				_cast_resurrection()
			KEY_5:
				_cast_corruption()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_single_heal_at(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_try_single_heal_at(event.position)

func _is_confirm_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed:
		return event.keycode == KEY_ENTER or event.keycode == KEY_SPACE
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		return true
	if event is InputEventScreenTouch and event.pressed:
		return true
	return false

func _create_roots() -> void:
	battle_root = Node2D.new()
	battle_root.visible = false
	add_child(battle_root)

func _create_background_ui() -> void:
	background_canvas = CanvasLayer.new()
	background_canvas.layer = -5
	background_canvas.visible = false
	add_child(background_canvas)

	background_sky_rect = ColorRect.new()
	background_sky_rect.position = Vector2.ZERO
	background_sky_rect.size = Vector2(SCREEN_W, SCREEN_H)
	background_canvas.add_child(background_sky_rect)

	background_mid_rect = ColorRect.new()
	background_mid_rect.position = Vector2(0, 140)
	background_mid_rect.size = Vector2(SCREEN_W, 220)
	background_canvas.add_child(background_mid_rect)

	background_ground_rect = ColorRect.new()
	background_ground_rect.position = Vector2(0, 360)
	background_ground_rect.size = Vector2(SCREEN_W, 360)
	background_canvas.add_child(background_ground_rect)

func _create_battle_ui() -> void:
	battle_canvas = CanvasLayer.new()
	battle_canvas.visible = false
	add_child(battle_canvas)

	top_panel_rect = ColorRect.new()
	top_panel_rect.position = Vector2.ZERO
	top_panel_rect.size = Vector2(SCREEN_W, TOP_PANEL_H)
	top_panel_rect.color = Color(0.08, 0.10, 0.16, 0.82)
	battle_canvas.add_child(top_panel_rect)

	status_label = Label.new()
	status_label.position = Vector2(16, 6)
	status_label.size = Vector2(1248, 22)
	battle_canvas.add_child(status_label)

	cooldown_label = Label.new()
	cooldown_label.position = Vector2(16, 30)
	cooldown_label.size = Vector2(1248, 22)
	battle_canvas.add_child(cooldown_label)

	help_label = Label.new()
	help_label.position = Vector2(16, 56)
	help_label.size = Vector2(1248, 34)
	battle_canvas.add_child(help_label)

	message_label = Label.new()
	message_label.position = Vector2(900, 8)
	message_label.size = Vector2(340, 26)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	message_label.scale = Vector2(1.05, 1.05)
	battle_canvas.add_child(message_label)

	var bottom_bg := ColorRect.new()
	bottom_bg.position = Vector2(0, BOTTOM_PANEL_Y)
	bottom_bg.size = Vector2(SCREEN_W, BOTTOM_PANEL_H)
	bottom_bg.color = Color(0.02, 0.02, 0.02, 0.72)
	battle_canvas.add_child(bottom_bg)

	healer_stats_label = Label.new()
	healer_stats_label.position = Vector2(16, BOTTOM_PANEL_Y + 10)
	healer_stats_label.size = Vector2(1248, 28)
	battle_canvas.add_child(healer_stats_label)

	squad_left_label = Label.new()
	squad_left_label.position = Vector2(16, BOTTOM_PANEL_Y + 48)
	squad_left_label.size = Vector2(600, 150)
	battle_canvas.add_child(squad_left_label)

	squad_right_label = Label.new()
	squad_right_label.position = Vector2(646, BOTTOM_PANEL_Y + 48)
	squad_right_label.size = Vector2(618, 150)
	battle_canvas.add_child(squad_right_label)

	_update_help_text()

func _create_screen_ui() -> void:
	screen_canvas = CanvasLayer.new()
	add_child(screen_canvas)
	var back := ColorRect.new()
	back.position = Vector2.ZERO
	back.size = Vector2(SCREEN_W, SCREEN_H)
	back.color = Color(0.02, 0.02, 0.04, 1.0)
	screen_canvas.add_child(back)

	screen_title_label = Label.new()
	screen_title_label.position = Vector2(0, 80)
	screen_title_label.size = Vector2(SCREEN_W, 60)
	screen_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_title_label.scale = Vector2(1.8, 1.8)
	screen_canvas.add_child(screen_title_label)

	screen_body_label = Label.new()
	screen_body_label.position = Vector2(170, 190)
	screen_body_label.size = Vector2(940, 250)
	screen_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	screen_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen_canvas.add_child(screen_body_label)

	screen_prompt_label = Label.new()
	screen_prompt_label.position = Vector2(0, 560)
	screen_prompt_label.size = Vector2(SCREEN_W, 40)
	screen_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_canvas.add_child(screen_prompt_label)

func _reset_run_state() -> void:
	stage = 1
	healer_level = 1
	divine_power = 1
	regular_kills_this_stage = 0
	spawned_regular_this_stage = 0
	boss_spawned = false
	boss_defeated = false
	skill_cd = {"single_heal": 0.0, "buff": 0.0, "sacred": 0.0}
	exorcism_used = false
	resurrection_used = false
	corruption_used = false
	dead_allies.clear()
	warrior_ref = null
	fighter_ref = null
	archer_ref = null
	assassin_ref = null
	current_boss = null

func _clear_battle_root() -> void:
	for child in battle_root.get_children():
		child.queue_free()
	warrior_ref = null
	fighter_ref = null
	archer_ref = null
	assassin_ref = null
	current_boss = null
	dead_allies.clear()

func _show_intro_screen() -> void:
	screen_state = ScreenState.INTRO
	background_canvas.visible = false
	battle_root.visible = false
	battle_canvas.visible = false
	screen_canvas.visible = true
	screen_title_label.text = INTRO_TITLE
	screen_body_label.text = INTRO_TEXT_EN
	screen_prompt_label.text = BEGIN_PROMPT

func _show_end_screen(is_victory: bool) -> void:
	background_canvas.visible = false
	battle_root.visible = false
	battle_canvas.visible = false
	screen_canvas.visible = true
	if is_victory:
		screen_state = ScreenState.VICTORY
		screen_title_label.text = VICTORY_TITLE
		screen_body_label.text = VICTORY_TEXT_EN
	else:
		screen_state = ScreenState.DEFEAT
		screen_title_label.text = DEFEAT_TITLE
		screen_body_label.text = DEFEAT_TEXT_EN
	screen_prompt_label.text = RESTART_PROMPT

func _start_game() -> void:
	_clear_battle_root()
	_reset_run_state()
	_refresh_stage_background()
	_spawn_allies()
	_spawn_stage_regular_enemies()
	background_canvas.visible = true
	battle_root.visible = true
	battle_canvas.visible = true
	screen_canvas.visible = false
	screen_state = ScreenState.COMBAT
	_update_help_text()
	_show_message("Mission Start! Stage 1")
	_update_ui()

func _update_help_text() -> void:
	help_label.text = "Click ally = Heal | 1=BUFF | 2=SACRED | 3=EXORCISM(once) | 4=RESURRECTION(once) | 5=CORRUPTION(once)"

func _spawn_allies() -> void:
	warrior_ref = _spawn_ally("warrior", WARRIOR_START_POS, 180.0, 12.0, 6.0, 66.0, 28.0, 0.78)
	fighter_ref = _spawn_ally("fighter", FIGHTER_START_POS, 120.0, 16.0, 4.0, 84.0, 30.0, 0.62)
	archer_ref = _spawn_ally("archer", ARCHER_START_POS, 110.0, 15.0, 3.0, 62.0, 170.0, 0.88)
	assassin_ref = _spawn_ally("assassin", ASSASSIN_START_POS, 90.0, 20.0, 2.0, 78.0, 210.0, 0.58)

func _spawn_ally(role: String, pos: Vector2, hp: float, atk: float, defense_value: float, speed: float, attack_range_value: float, cooldown: float) -> Unit:
	var u := Unit.new()
	u.team = "ally"
	u.role = role
	u.base_role = role
	u.global_position = pos
	u.max_hp = hp
	u.attack_power = atk
	u.defense = defense_value
	u.move_speed = speed
	u.attack_range = attack_range_value
	u.attack_cooldown = cooldown
	u.body_radius = 16.0
	u.setup_role_stats()
	battle_root.add_child(u)
	u.died.connect(_on_unit_died)
	return u

func _spawn_stage_regular_enemies() -> void:
	spawned_regular_this_stage = 0
	for i in range(KILLS_TO_BOSS_OR_CLEAR):
		_spawn_regular_enemy(i)

func _spawn_regular_enemy(enemy_index: int) -> void:
	if spawned_regular_this_stage >= KILLS_TO_BOSS_OR_CLEAR:
		return
	var row: int = enemy_index % 5
	var col: int = int(enemy_index / 5)
	var e := Unit.new()
	e.team = "enemy"
	e.role = "monster"
	e.base_role = "monster"
	e.global_position = Vector2(850.0 + col * 120.0 + randf_range(-18.0, 18.0), 180.0 + row * 66.0 + randf_range(-10.0, 10.0))
	e.max_hp = 55.0 + stage * 18.0
	e.attack_power = 7.0 + stage * 2.2
	e.defense = 1.0 + stage * 0.65
	e.move_speed = 48.0 + stage * 2.5
	e.attack_range = 24.0
	e.attack_cooldown = max(0.38, 0.95 - stage * 0.03)
	e.body_radius = 14.0
	e.counts_for_stage_progress = true
	battle_root.add_child(e)
	e.died.connect(_on_unit_died)
	spawned_regular_this_stage += 1

func _maybe_spawn_boss() -> void:
	if not _is_boss_stage() or boss_spawned or regular_kills_this_stage < KILLS_TO_BOSS_OR_CLEAR:
		return
	if get_tree().get_nodes_in_group("enemies").size() > 0:
		return
	boss_spawned = true
	boss_defeated = false
	current_boss = Unit.new()
	current_boss.team = "enemy"
	current_boss.global_position = Vector2(1035, 330)
	current_boss.body_radius = 26.0
	current_boss.is_boss = true
	match stage:
		5:
			current_boss.role = "boss_necromancer"
			current_boss.base_role = "boss_necromancer"
			current_boss.max_hp = 640.0
			current_boss.attack_power = 22.0
			current_boss.defense = 5.0
			current_boss.move_speed = 42.0
			current_boss.attack_range = 95.0
			current_boss.attack_cooldown = 1.20
			current_boss.boss_special_interval = 1.0
			_show_message("Boss Appears: Necromancer")
		10:
			current_boss.role = "boss_vampire"
			current_boss.base_role = "boss_vampire"
			current_boss.max_hp = 980.0
			current_boss.attack_power = 38.0
			current_boss.defense = 8.0
			current_boss.move_speed = 78.0
			current_boss.attack_range = 28.0
			current_boss.attack_cooldown = 0.55
			_show_message("Boss Appears: Vampire")
		15:
			current_boss.role = "boss_lucifer"
			current_boss.base_role = "boss_lucifer"
			current_boss.max_hp = 1800.0
			current_boss.attack_power = 68.0
			current_boss.defense = 14.0
			current_boss.move_speed = 95.0
			current_boss.attack_range = 90.0
			current_boss.attack_cooldown = 0.28
			_show_message("Final Boss Appears: Lucifer")
	battle_root.add_child(current_boss)
	current_boss.died.connect(_on_unit_died)

func spawn_boss_skeleton_wave(origin: Vector2) -> void:
	for i in range(3):
		var s := Unit.new()
		s.team = "enemy"
		s.role = "skeleton"
		s.base_role = "skeleton"
		s.global_position = origin + Vector2(randf_range(-40.0, 40.0), randf_range(-44.0, 44.0))
		s.max_hp = 16.0 + stage * 3.0
		s.attack_power = 3.0 + stage * 0.8
		s.defense = stage * 0.08
		s.move_speed = 64.0 + stage
		s.attack_range = 20.0
		s.attack_cooldown = 1.15
		s.body_radius = 10.0
		s.is_summon = true
		battle_root.add_child(s)
		s.died.connect(_on_unit_died)

func _on_unit_died(unit: Unit) -> void:
	if screen_state != ScreenState.COMBAT:
		return
	if unit.team == "enemy":
		if unit == current_boss:
			current_boss = null
			boss_defeated = true
			_show_message("Boss Defeated!")
		elif unit.counts_for_stage_progress:
			regular_kills_this_stage += 1
		return
	dead_allies.append(unit.export_snapshot())
	match unit.role:
		"warrior": warrior_ref = null
		"fighter": fighter_ref = null
		"archer": archer_ref = null
		"assassin": assassin_ref = null

func _check_stage_clear() -> void:
	var no_enemies_left: bool = get_tree().get_nodes_in_group("enemies").size() == 0
	if _is_boss_stage():
		if boss_defeated and no_enemies_left:
			if stage >= FINAL_STAGE:
				_end_game(true)
			else:
				_prepare_next_stage()
	else:
		if regular_kills_this_stage >= KILLS_TO_BOSS_OR_CLEAR and no_enemies_left:
			_prepare_next_stage()

func _prepare_next_stage() -> void:
	stage += 1
	healer_level += 1
	divine_power += 1
	regular_kills_this_stage = 0
	spawned_regular_this_stage = 0
	boss_spawned = false
	boss_defeated = false
	current_boss = null
	dead_allies.clear()
	for unit_ref in [warrior_ref, fighter_ref, archer_ref, assassin_ref]:
		if unit_ref != null and is_instance_valid(unit_ref) and not unit_ref.is_dead():
			unit_ref.level_up_role()
			unit_ref.clear_stage_only_buffs()
	_reset_allies_for_next_stage()
	_spawn_stage_regular_enemies()
	_refresh_stage_background()
	_show_message("Stage %d Start!" % stage)

func _reset_allies_for_next_stage() -> void:
	for pair in [[warrior_ref, WARRIOR_START_POS], [fighter_ref, FIGHTER_START_POS], [archer_ref, ARCHER_START_POS], [assassin_ref, ASSASSIN_START_POS]]:
		var u: Unit = pair[0]
		if u != null and is_instance_valid(u) and not u.is_dead():
			u.global_position = pair[1]
			u.heal(u.max_hp)

func _check_game_over() -> void:
	for unit_ref in [warrior_ref, fighter_ref, archer_ref, assassin_ref]:
		if unit_ref != null and is_instance_valid(unit_ref) and not unit_ref.is_dead():
			return
	_end_game(false)

func _end_game(is_victory: bool) -> void:
	_show_end_screen(is_victory)

func _is_boss_stage() -> bool:
	return stage == 5 or stage == 10 or stage == 15

func _refresh_stage_background() -> void:
	if stage <= 5:
		background_sky_rect.color = Color(0.72, 0.88, 0.98, 1.0)
		background_mid_rect.color = Color(0.56, 0.78, 0.42, 1.0)
		background_ground_rect.color = Color(0.39, 0.63, 0.28, 1.0)
	elif stage <= 10:
		background_sky_rect.color = Color(0.93, 0.76, 0.48, 1.0)
		background_mid_rect.color = Color(0.84, 0.64, 0.32, 1.0)
		background_ground_rect.color = Color(0.72, 0.55, 0.24, 1.0)
	else:
		background_sky_rect.color = Color(0.30, 0.08, 0.06, 1.0)
		background_mid_rect.color = Color(0.46, 0.13, 0.08, 1.0)
		background_ground_rect.color = Color(0.18, 0.05, 0.04, 1.0)

func _try_single_heal_at(pos: Vector2) -> void:
	if skill_cd["single_heal"] > 0.0:
		return
	for ally in [warrior_ref, fighter_ref, archer_ref, assassin_ref]:
		if ally == null or not is_instance_valid(ally) or ally.is_dead():
			continue
		if ally.global_position.distance_to(pos) <= ally.body_radius + 12.0:
			ally.heal(28.0 + healer_level * 12.0)
			skill_cd["single_heal"] = 1.0
			_show_message("Heal")
			return

func _cast_buff() -> void:
	if skill_cd["buff"] > 0.0:
		return
	for ally in [warrior_ref, fighter_ref, archer_ref, assassin_ref]:
		if ally != null and is_instance_valid(ally) and not ally.is_dead():
			ally.apply_attack_buff(healer_level, 3.0)
			ally.apply_defense_buff(healer_level, 3.0)
			ally.apply_dex_buff(healer_level, 3.0)
	skill_cd["buff"] = 5.0
	_show_message("BUFF")

func _cast_sacred() -> void:
	if skill_cd["sacred"] > 0.0:
		return
	for ally in [warrior_ref, fighter_ref, archer_ref, assassin_ref]:
		if ally != null and is_instance_valid(ally) and not ally.is_dead():
			ally.apply_sacred(2.0)
	skill_cd["sacred"] = 10.0
	_show_message("SACRED")

func _cast_exorcism() -> void:
	if exorcism_used:
		return
	if current_boss == null or not is_instance_valid(current_boss) or current_boss.is_dead():
		return
	current_boss.apply_exorcism(3.0)
	exorcism_used = true
	_show_message("EXORCISM")

func _cast_resurrection() -> void:
	if resurrection_used or dead_allies.is_empty():
		return
	var snap: Dictionary = dead_allies.pop_back()
	var pos := ASSASSIN_START_POS
	match String(snap.get("base_role", "")):
		"warrior": pos = WARRIOR_START_POS
		"fighter": pos = FIGHTER_START_POS
		"archer": pos = ARCHER_START_POS
		"assassin": pos = ASSASSIN_START_POS
	var u := Unit.new()
	u.team = "ally"
	u.global_position = pos
	u.apply_snapshot(snap)
	battle_root.add_child(u)
	u.died.connect(_on_unit_died)
	match u.role:
		"warrior": warrior_ref = u
		"fighter": fighter_ref = u
		"archer": archer_ref = u
		"assassin": assassin_ref = u
	resurrection_used = true
	u.show_spell_effect("RESURRECTION", Color(0.75, 1.0, 0.75, 1.0), 3)
	_show_message("RESURRECTION")

func _cast_corruption() -> void:
	if corruption_used:
		return
	for ally in [warrior_ref, fighter_ref, archer_ref, assassin_ref]:
		if ally != null and is_instance_valid(ally) and not ally.is_dead():
			ally.apply_corruption_boost(healer_level)
	corruption_used = true
	_show_message("CORRUPTION")

func _show_message(text: String) -> void:
	_message_ticket += 1
	var ticket := _message_ticket
	message_label.text = text
	var tween := create_tween()
	tween.tween_interval(1.2)
	tween.finished.connect(func() -> void:
		if ticket == _message_ticket:
			message_label.text = ""
	)

func _update_ui() -> void:
	var boss_text: String = ""
	if current_boss != null and is_instance_valid(current_boss) and not current_boss.is_dead():
		boss_text = " | Boss: %s HP %.0f/%.0f" % [current_boss.get_role_display_name(), current_boss.hp, current_boss.max_hp]
	status_label.text = "Stage %d/15 | Kills %d/10 | Healer Lv %d | Divine %d%s" % [
		stage, regular_kills_this_stage, healer_level, divine_power, boss_text
	]
	cooldown_label.text = "CD Heal %.1f | 1:BUFF %.1f | 2:SACRED %.1f | 3:%s | 4:%s | 5:%s" % [
		skill_cd["single_heal"], skill_cd["buff"], skill_cd["sacred"],
		("Used" if exorcism_used else "Ready"), ("Used" if resurrection_used else "Ready"), ("Used" if corruption_used else "Ready")
	]
	healer_stats_label.text = "Healer | Lv %d | Divine %d | Heal %.0f | 1=BUFF 2=SACRED 3=EXORCISM 4=RESURRECTION 5=CORRUPTION" % [healer_level, divine_power, 28.0 + healer_level * 12.0]
	squad_left_label.text = _ally_line(warrior_ref, "warrior") + "\n\n" + _ally_line(fighter_ref, "fighter")
	squad_right_label.text = _ally_line(archer_ref, "archer") + "\n\n" + _ally_line(assassin_ref, "assassin")

func _ally_line(u: Unit, fallback_role: String) -> String:
	if u == null or not is_instance_valid(u) or u.is_dead():
		return "%s | DEAD" % fallback_role
	return u.describe_short()
