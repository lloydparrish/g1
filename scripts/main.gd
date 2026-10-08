extends Control

const SimScript = preload("res://scripts/game_sim.gd")
const UIStateScript = preload("res://scripts/ui_state.gd")
const LowerDockScript = preload("res://scripts/lower_dock.gd")
const LOGICAL_SIZE := Vector2(1440, 810)
const BASE_BOARD_ORIGIN := Vector2(250, 62)
const BASE_TILE := 36.0
const WIDE_TILE := 36.0
const WIDE_LAYOUT_MIN_WIDTH := 1550.0
const TOUCH_TARGET := 54.0
const POINTER_DRAG_SLOP := 18.0

var sim: ArcanistSim
var ui_state
var lower_dock
var portrait_texture_cache: Dictionary = {}
var page := "title"
var overlay := ""
var selected_character := "jim"
var reveal_character_id := ""
var selected_enemy := ""

var selected_object_index := -1
var selected_ability := ""
var target_mode := ""
var selected_book_abilities: Array = []
var codex_book_id := ""
var selected_ward := ""

var ability_filter := "All"
var ability_filter_page := 0
var palette_filter := "All"
var palette_page := 0
var quickbar_page := 0
var quickbar_assign_mode := false
var quickbar_pending := {"type": "", "id": ""}
var quickbar_pending_slot := -1
var playback_mode := "Normal"
var playback_active := false
var playback_events: Array = []
var playback_index := 0
var playback_timer := 0.0
var playback_elapsed := 0.0
var presentation_state: Dictionary = {}
var presentation_history: Array = []
var combat_history_page := 0
var current_presentation_event: Dictionary = {}
var acting_actor_id := ""
var acting_target_id := ""
var floating_events: Array = []
var pending_outcome_page := ""
var pending_outcome_overlay := ""
var run_summary_page := 0
var web_pan := Vector2.ZERO
var capture_web_pan := Vector2.ZERO
var capture_web_pan_provided := false
var web_zoom := 1.0
var web_pan_active := false
var web_last_pointer := Vector2.ZERO
var press_position := Vector2.ZERO
var press_current_position := Vector2.ZERO
var press_started := 0
var touch_index := -1
var mouse_press_active := false
var press_dragged := false
var active_hits: Array = []
var active_hit_clip_rect := Rect2()
var overlay_hit_start := 0
var last_android_back_msec := -500
var notice := ""
var notice_until := 0
var capture_path := ""
var capture_requested := false
var capture_size := Vector2i.ZERO
var capture_directory := "res://screenshots"
var capture_overlay := ""
var capture_target := ""
var capture_book := ""
var capture_scenario := ""
var capture_page := "battle"
var capture_fresh_profile := false
var capture_full_web := false
var screen_size := LOGICAL_SIZE
var draw_scale := 1.0
var draw_offset := Vector2.ZERO
var draw_label_content_offset := Vector2.ZERO
var hover_position := Vector2(-1, -1)
var mobile_layout_override := false

const COLORS := {
	"ink": Color("#071018"), "panel": Color("#0d1722"), "panel_2": Color("#111f2c"),
	"line": Color("#3d586b"), "line_soft": Color("#233746"), "text": Color("#edf3f5"),
	"muted": Color("#91a6b4"), "gold": Color("#e8c96f"), "cyan": Color("#5fdcff"),
	"green": Color("#74dc89"), "red": Color("#ef5c64"), "blue": Color("#488ef0"),
	"purple": Color("#c078ed"), "orange": Color("#ff984c"), "blood": Color("#b94753")
}

const UI_GLYPHS := {
	"move": "✥", "attack": "⚔", "fire": "✹", "frost": "❄", "storm": "ϟ",
	"arcane": "◈", "blood": "†", "necromancy": "☠", "nature": "♣", "demonology": "♨",
	"swordsmanship": "⚔", "heavy weapons": "⚒", "defense": "⛨", "mobility": "⇢", "archery": "➶",
	"pack": "▦", "web": "⌘", "map": "⌖", "codex": "▤", "wait": "Ⅱ", "cancel": "×",
	"previous": "‹", "next": "›", "more": "⋯", "neutral": "◇"
}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)
	get_tree().quit_on_go_back = false
	sim = SimScript.new()
	ui_state = UIStateScript.new()
	lower_dock = LowerDockScript.new()
	lower_dock.host = self
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--capture-dir="):
			capture_directory = arg.trim_prefix("--capture-dir=")
		elif arg.begins_with("--capture-overlay="):
			capture_overlay = arg.trim_prefix("--capture-overlay=")
		elif arg.begins_with("--capture-target="):
			capture_target = arg.trim_prefix("--capture-target=")
		elif arg.begins_with("--capture-book="):
			capture_book = arg.trim_prefix("--capture-book=")
		elif arg.begins_with("--capture-scenario="):
			capture_scenario = arg.trim_prefix("--capture-scenario=")
		elif arg == "--capture-fresh-profile":
			capture_fresh_profile = true
		elif arg.begins_with("--capture-page="):
			capture_page = arg.trim_prefix("--capture-page=")
		elif arg == "--capture-mobile":
			mobile_layout_override = true
		elif arg == "--capture-full-web":
			capture_full_web = true
		elif arg.begins_with("--capture-web-pan="):
			var pan_parts: PackedStringArray = arg.trim_prefix("--capture-web-pan=").split(",")
			if pan_parts.size() == 2:
				capture_web_pan = Vector2(float(pan_parts[0]), float(pan_parts[1]))
				capture_web_pan_provided = true
	for arg in args:
		if arg.begins_with("--capture="):
			var dimensions: PackedStringArray = arg.trim_prefix("--capture=").split("x")
			if dimensions.size() == 2:
				capture_size = Vector2i(int(dimensions[0]), int(dimensions[1]))
				capture_path = capture_directory.path_join("%dx%d.png" % [capture_size.x, capture_size.y])
				capture_requested = true
				if capture_page == "title":
					page = "title"
					overlay = capture_overlay
					if capture_fresh_profile:
						sim.profile = {"version": 1, "unlocked_character_ids": sim.get_starting_character_ids(), "pending_character_reveals": [], "enabled_package_ids": []}
						sim.save_profile()
					if capture_scenario == "title_reveal":
						sim.unlock_character("aldren")
						reveal_character_id = "aldren"
						overlay = "character_reveal"
					elif capture_scenario.begins_with("title_reveal_"):
						var reveal_ids := {"spellblade": "aldren", "bloodletter": "mara", "warrior": "brakka", "necromancer": "orin", "ranger": "sylvi"}
						var requested_reveal := String(reveal_ids.get(capture_scenario.trim_prefix("title_reveal_"), ""))
						if requested_reveal != "":
							sim.unlock_character(requested_reveal)
							reveal_character_id = requested_reveal
							overlay = "character_reveal"
					elif capture_scenario == "title_all_unlocked":
						var capture_unlocks: Array = sim.profile.get("unlocked_character_ids", []).duplicate()
						for capture_id in ["aldren", "mara", "brakka", "orin", "sylvi"]:
							if not capture_unlocks.has(capture_id): capture_unlocks.append(capture_id)
						sim.profile["unlocked_character_ids"] = capture_unlocks
						sim.save_profile()
				else:
					page = "battle"
					var capture_character := "aldren" if capture_scenario == "summon" else "brakka" if capture_scenario in ["abilities_cleave", "passives", "known"] else "mara"
					if not sim.is_character_unlocked(capture_character): sim.profile.unlocked_character_ids.append(capture_character)
					sim.start_run(912041, capture_character)
					sim.save_run()
					overlay = capture_overlay
					match capture_overlay:
						"map":
							overlay = ""
							ui_state.active_lower_panel = "world_map"
							ui_state.lower_dock_expanded = true
						"character", "abilities":
							overlay = ""
							ui_state.active_lower_panel = "character"
							ui_state.lower_dock_expanded = true
							ui_state.character_tab = "Abilities"
						"inventory": _open_lower_panel("inventory", false)
						"spellbook", "discovery":
							overlay = ""
							ui_state.active_lower_panel = "inventory"
							ui_state.lower_dock_expanded = true
							ui_state.inventory_tab = "Spellbooks"
						"ability_web": overlay = "abilities"
					match capture_overlay:
						"inventory": ui_state.selected_inventory_index = 0
						"map": sim.run.stage_completed = true
						"destinations": sim.run.stage_completed = true
						"rewards":
							sim.run.stage_completed = true
							sim.run.reward_choices = [
								{"type": "artifact", "id": "copper_hare", "claimed": false},
								{"type": "item", "id": "healing_potion", "claimed": false},
								{"type": "item", "id": "cinder_primer", "claimed": false}
							]
				if capture_page != "title" and capture_book != "" and sim.content.items.has(capture_book):
					sim.run.inventory.append(capture_book)
					ui_state.selected_inventory_index = sim.run.inventory.size() - 1
					codex_book_id = capture_book
					if capture_overlay == "codex_book":
						var captured_book_index: int = sim.run.inventory.size() - 1
						var book_options: Dictionary = sim.get_spellbook_options(captured_book_index)
						var book_choices: Array = [0] if book_options.get("mode") == "choose" else []
						sim.study_spellbook(captured_book_index, book_choices)
				if capture_page != "title" and capture_full_web:
					sim.run.disciplines = sim.content.progression.disciplines.duplicate()
					sim.run.schools = ["Fire", "Frost", "Storm", "Earth", "Nature", "Holy", "Shadow", "Necromancy", "Summoning", "Spirit", "Blood"]
					sim.run.skill_points = 12
					for ability_id in ["firebolt", "fireball", "frostbolt", "lightning_bolt", "aimed_shot", "parry", "dagger_flurry", "lunge"]:
						if not sim.run.known.has(ability_id): sim.run.known.append(ability_id)
					for book_id in ["cinder_primer", "storm_ledger", "lesser_key_of_ash"]:
						sim.run.inventory.append(book_id)
						var book_index: int = sim.run.inventory.size() - 1
						var book_options: Dictionary = sim.get_spellbook_options(book_index)
						var book_choices: Array = [0] if book_options.get("mode") == "choose" else []
						sim.study_spellbook(book_index, book_choices)
					ui_state.selected_ability_id = "storm_arrow"
				if capture_page != "title" and capture_overlay == "action_palette":
					var capture_abilities: Array = sim.get_available_abilities()
					selected_ability = String(capture_abilities[0]) if not capture_abilities.is_empty() else ""
				if capture_page != "title" and capture_target != "":
					target_mode = capture_target
				if capture_page != "title" and capture_overlay in ["abilities", "character", "ability_web"]:
					if ui_state.selected_ability_id == "":
						ui_state.selected_ability_id = String(sim.run.known.back()) if not sim.run.known.is_empty() else ""
					ability_filter = String(sim.content.abilities.get(ui_state.selected_ability_id, {}).get("school", "All"))
					web_zoom = 0.86
					_center_web_on(ui_state.selected_ability_id)
					if capture_web_pan_provided:
						web_pan += capture_web_pan
				_prepare_capture_scenario()
	if not capture_requested:
		if sim.has_saved_run():
			page = "title"
	if capture_requested:
		OS.low_processor_usage_mode = false
		call_deferred("_capture_after_draw")
	elif page == "title" and sim.get_pending_character_reveal() != "":
		reveal_character_id = sim.get_pending_character_reveal()
		overlay = "character_reveal"
	queue_redraw()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST]:
		mouse_press_active = false
		touch_index = -1
		press_position = Vector2(-1, -1)
		press_current_position = Vector2(-1, -1)
		_save_active_run()
		if playback_active: _finish_presentation()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		queue_redraw()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_back_request()
	elif what == NOTIFICATION_RESIZED:
		queue_redraw()

func _save_active_run() -> void:
	if sim != null and not sim.run.is_empty():
		sim.save_run()

func _handle_back_request() -> void:
	if playback_active:
		_finish_presentation()
		return
	if _is_mobile_layout():
		var now := Time.get_ticks_msec()
		if now - last_android_back_msec < 400:
			return
		last_android_back_msec = now
	if target_mode != "":
		_cancel_targeting()
	elif ui_state.lower_dock_expanded:
		ui_state.lower_dock_expanded = false
	elif overlay == "exit_confirm":
		overlay = "pause"
	elif overlay == "pause":
		overlay = "exit_confirm"
	elif overlay == "codex_book":
		overlay = "codex"
	elif overlay != "":
		overlay = ""
		ui_state.selected_inventory_index = -1
	elif page == "battle":
		overlay = "pause"
	elif page == "outcome":
		page = "title"
	else:
		get_tree().quit()
	queue_redraw()

func _process(_delta: float) -> void:
	if playback_active:
		_advance_presentation(_delta)
	if not floating_events.is_empty():
		var now := Time.get_ticks_msec()
		floating_events = floating_events.filter(func(item: Dictionary) -> bool: return now - int(item.born) < int(item.duration))
		queue_redraw()
	if notice != "" and Time.get_ticks_msec() > notice_until:
		notice = ""
		if not playback_active and floating_events.is_empty(): set_process(false)
		queue_redraw()

func _advance_presentation(delta: float) -> void:
	if playback_mode == "Instant":
		_finish_presentation()
		return
	if current_presentation_event.is_empty():
		_start_next_presentation_event()
		if current_presentation_event.is_empty():
			_finish_presentation()
		return
	playback_elapsed += delta
	playback_timer -= delta
	if playback_timer <= 0.0:
		current_presentation_event = {}
		acting_actor_id = ""
		acting_target_id = ""
		_start_next_presentation_event()
		if current_presentation_event.is_empty():
			_finish_presentation()
	queue_redraw()

func _start_next_presentation_event() -> void:
	if playback_index >= playback_events.size():
		return
	current_presentation_event = playback_events[playback_index]
	playback_index += 1
	playback_timer = _presentation_event_duration(String(current_presentation_event.get("type", "")))
	playback_elapsed = 0.0
	acting_actor_id = String(current_presentation_event.get("actor_id", ""))
	acting_target_id = String(current_presentation_event.get("target_id", ""))
	for patch in current_presentation_event.get("patches", []):
		var entity_id := String(patch.get("id", ""))
		if entity_id == "": continue
		if patch.get("hidden", false) or not patch.get("alive", true):
			presentation_state.entities.erase(entity_id)
			if not patch.get("hidden", false): presentation_state.entities[entity_id] = patch.duplicate(true)
		else:
			presentation_state.entities[entity_id] = patch.duplicate(true)
	var event_details: Dictionary = current_presentation_event.get("details", {})
	var event_type := String(current_presentation_event.get("type", ""))
	if event_type == "Move" and String(current_presentation_event.get("actor_id", "")) == "player":
		presentation_state.visible = sim.run.get("visible", []).duplicate(true)
		presentation_state.explored = sim.run.get("explored", []).duplicate(true)
	if String(current_presentation_event.get("type", "")) == "TerrainChanged" and event_details.has("pos"):
		var changed: Vector2i = Vector2i(int(event_details.pos[0]), int(event_details.pos[1]))
		if sim._inside(changed): presentation_state.grid[changed.y][changed.x] = String(event_details.get("terrain", "floor"))
	if event_type == "XPGranted":
		presentation_state.xp = int(presentation_state.get("xp", 0)) + int(event_details.get("amount", 0))
	if event_type == "LevelUp":
		presentation_state.level = int(event_details.get("level", presentation_state.get("level", 1)))
		presentation_state.xp = int(event_details.get("xp", presentation_state.get("xp", 0)))
		presentation_state.skill_points = int(presentation_state.get("skill_points", 0)) + int(event_details.get("skill_points", 1))
		var grown_attribute := String(event_details.get("attribute", ""))
		if grown_attribute != "": presentation_state.attributes[grown_attribute] = int(event_details.get("attribute_value", int(presentation_state.attributes.get(grown_attribute, 0)) + 1))
	var history_entry := {"type": String(current_presentation_event.get("type", "")), "actor_name": String(current_presentation_event.get("actor_name", "")), "target_name": String(current_presentation_event.get("target_name", "")), "details": event_details.duplicate(true)}
	if sim._is_meaningful_combat_event(history_entry):
		presentation_history.append(history_entry)
		if presentation_history.size() > 100: presentation_history.pop_front()
	_add_floating_combat_text(current_presentation_event)

func _presentation_event_duration(event_type: String) -> float:
	var normal := 0.16
	match event_type:
		"ActorTurnStarted": normal = 0.08
		"Move", "Spotted", "LeavesSight": normal = 0.26
		"Attack", "Cast", "Damage", "UnseenImpact": normal = 0.19
		"Death", "Summon", "LevelUp", "EncounterComplete": normal = 0.4 if event_type != "LevelUp" else 0.5
		"XPGranted", "KillCredit", "StatusApplied", "StatusTick", "Heal": normal = 0.16
		"TerrainChanged": normal = 0.24
	var duration := normal if playback_mode == "Normal" else normal * 0.48
	return duration

func _finish_presentation() -> void:
	playback_active = false
	playback_events.clear()
	playback_index = 0
	playback_timer = 0.0
	current_presentation_event = {}
	acting_actor_id = ""
	acting_target_id = ""
	presentation_state.clear()
	presentation_history.clear()
	if pending_outcome_page != "": page = pending_outcome_page
	if pending_outcome_overlay != "": overlay = pending_outcome_overlay
	pending_outcome_page = ""
	pending_outcome_overlay = ""
	if overlay == "" and page == "battle" and sim.get_pending_character_reveal() != "":
		reveal_character_id = sim.get_pending_character_reveal()
		overlay = "character_reveal"
	queue_redraw()
	if notice == "" and floating_events.is_empty(): set_process(false)

func _add_floating_combat_text(event: Dictionary) -> void:
	var event_type := String(event.get("type", ""))
	var details: Dictionary = event.get("details", {})
	var text := ""
	var color := COLORS.text
	match event_type:
		"Damage": text = "−%d" % int(details.get("amount", 0)); color = COLORS.red
		"UnseenImpact": text = "HIT"; color = COLORS.orange
		"Heal": text = "+%d HP" % int(details.get("amount", 0)); color = COLORS.green
		"StatusApplied": text = String(details.get("status", "")); color = COLORS.cyan
		"Summon": text = "SUMMONED"; color = COLORS.purple
		"Death": text = "FALLEN"; color = COLORS.red
		"XPGranted": text = "+%d XP%s" % [int(details.get("amount", 0)), " ASSIST" if details.get("reason") == "assist" else ""]; color = COLORS.gold
		"LevelUp": text = "LEVEL %d!" % int(details.get("level", 1)); color = COLORS.gold
		"TerrainChanged": text = String(details.get("terrain", "")).to_upper(); color = COLORS.orange
	if text == "": return
	var cell := Vector2i(-1, -1)
	var target_id := String(event.get("target_id", ""))
	var actor_id := String(event.get("actor_id", ""))
	var state_entities: Dictionary = presentation_state.get("entities", {})
	if target_id != "" and state_entities.has(target_id): cell = sim._pos(state_entities[target_id])
	elif actor_id != "" and state_entities.has(actor_id): cell = sim._pos(state_entities[actor_id])
	elif details.has("pos"): cell = Vector2i(int(details.pos[0]), int(details.pos[1]))
	if cell.x < 0: return
	floating_events.append({"text": text, "color": color, "cell": cell, "born": Time.get_ticks_msec(), "duration": 1150})
	if floating_events.size() > 12: floating_events.pop_front()
	set_process(true)

func _draw() -> void:
	active_hits.clear()
	var viewport := get_viewport_rect().size
	var layout := _calculate_layout(viewport, _safe_area_for_viewport(viewport))
	screen_size = layout.size
	draw_scale = layout.scale
	draw_offset = layout.offset
	draw_label_content_offset = Vector2.ZERO
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(Vector2.ZERO, viewport), COLORS.ink)
	draw_set_transform(draw_offset, 0.0, Vector2(draw_scale, draw_scale))
	draw_rect(Rect2(Vector2.ZERO, screen_size), COLORS.ink)
	_draw_backdrop()
	var hits_start := active_hits.size()
	var centered_content := page != "battle" and screen_size.x > LOGICAL_SIZE.x
	if centered_content:
		draw_label_content_offset = Vector2((screen_size.x - LOGICAL_SIZE.x) * 0.5, 0.0)
		draw_set_transform(draw_offset + draw_label_content_offset * draw_scale, 0.0, Vector2(draw_scale, draw_scale))
	if page == "title":
		_draw_title()
		if overlay != "":
			_draw_overlay()
	elif page == "battle":
		_draw_battle()
		if overlay != "":
			_draw_overlay()
	elif page == "outcome":
		_draw_outcome()
	if page == "battle" and overlay == "":
		_draw_hover_tooltip()
	if centered_content:
		_shift_active_hits(hits_start, (screen_size.x - LOGICAL_SIZE.x) * 0.5)
	draw_label_content_offset = Vector2.ZERO
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_backdrop() -> void:
	var bands := int(ceil(screen_size.y / 101.0))
	for i in range(bands):
		var alpha := 0.035 - float(i % 9) * 0.003
		draw_rect(Rect2(Vector2(0, i * 101), Vector2(screen_size.x, 102)), Color(0.08, 0.17, 0.23, alpha))
	for x in range(0, int(screen_size.x), 80):
		draw_line(Vector2(x, 0), Vector2(x, screen_size.y), Color(0.22, 0.39, 0.48, 0.035), 1.0)
	for y in range(0, int(screen_size.y), 80):
		draw_line(Vector2(0, y), Vector2(screen_size.x, y), Color(0.22, 0.39, 0.48, 0.035), 1.0)

func _draw_title() -> void:
	_draw_label("PROJECT", 56, 72, 18, COLORS.cyan)
	_draw_label("ARCANIST", 56, 129, 48, COLORS.text)
	_draw_label("THE FRACTURED MARCH", 58, 158, 15, COLORS.gold)
	_draw_label("A tactical roguelike of steel, spellcraft and hard choices", 58, 187, 17, COLORS.muted)
	_draw_panel(Rect2(47, 202, 1346, 458), "CHOOSE YOUR BEGINNING", COLORS.line)
	var characters: Array = sim.content.characters.keys()
	characters.sort_custom(func(a: String, b: String) -> bool:
		var order_a := int(sim.content.characters[a].get("selection_order", 99))
		var order_b := int(sim.content.characters[b].get("selection_order", 99))
		return order_a < order_b if order_a != order_b else String(a) < String(b)
	)
	for character_index in range(characters.size()):
		var character_id: String = characters[character_index]
		var definition: Dictionary = sim.content.characters[character_id]
		var col := character_index % 3
		var row := int(character_index / 3)
		var rect := Rect2(70 + col * 437, 234 + row * 140, 414, 136)
		var presentation := _character_card_presentation(character_id)
		var unlocked := bool(presentation.get("unlocked", false))
		var active: bool = character_id == selected_character
		_draw_panel(rect, "", COLORS.gold if active else COLORS.line_soft if unlocked else Color("#3a454d"))
		var portrait_rect := Rect2(rect.position.x + 12, rect.position.y + 14, 66, 78)
		if unlocked:
			_draw_character_portrait(portrait_rect, definition)
			var weapon: Dictionary = sim.content.weapons.get(String(definition.get("weapon", "")), {})
			var equipment_name := String(weapon.get("name", "Basic equipment"))
			if definition.get("starting_equipment", {}).has("Offhand"):
				equipment_name += " + " + String(sim.content.items.get(definition.starting_equipment.Offhand, {}).get("name", "Shield"))
			var title := String(presentation.get("class_title", "Newly Unlocked Class"))
			_draw_label(_fit_text(title, 300, 16), rect.position.x + 91, rect.position.y + 24, 16, COLORS.text)
			var class_description := String(presentation.get("class_description", "A distinct path with room to grow."))
			_draw_label(_fit_text(class_description, 300, 10), rect.position.x + 91, rect.position.y + 43, 10, COLORS.muted)
			_draw_label(_fit_text("BASIC GEAR  ·  " + equipment_name, 300, 10), rect.position.x + 91, rect.position.y + 64, 10, COLORS.cyan)
			_draw_label("HP %d  ·  MANA %d  ·  STA %d" % [definition.resources.Health[1], definition.resources.Mana[1], definition.resources.Stamina[1]], rect.position.x + 91, rect.position.y + 82, 9, COLORS.gold)
			var button_rect := Rect2(rect.position.x + 90, rect.position.y + 100, rect.size.x - 104, 25)
			_draw_button(button_rect, "SELECTED" if active else "CHOOSE", {"type": "select_character", "id": character_id}, active, 10)
			active_hits.append({"rect": portrait_rect, "action": {"type": "select_character", "id": character_id}})
			active_hits.append({"rect": Rect2(rect.position.x + 84, rect.position.y + 2, rect.size.x - 89, 93), "action": {"type": "select_character", "id": character_id}})
		else:
			_draw_panel(portrait_rect, "", COLORS.gold)
			_draw_label("?", portrait_rect.get_center().x, portrait_rect.position.y + 53, 42, COLORS.gold, HORIZONTAL_ALIGNMENT_CENTER)
			_draw_label("Unknown Character", rect.position.x + 91, rect.position.y + 43, 13, COLORS.text)
			_draw_label("Unlock Requirement", rect.position.x + 91, rect.position.y + 75, 9, COLORS.gold)
			var requirement := String(presentation.get("requirement", ""))
			var requirement_lines := _wrap_text_to_width(requirement, rect.size.x - 105, 9, 2)
			for line_index in range(requirement_lines.size()):
				_draw_label(String(requirement_lines[line_index]), rect.position.x + 91, rect.position.y + 92 + line_index * 12, 9, COLORS.muted)
	_draw_button(Rect2(481, 690, 310, 70), "BEGIN THE MARCH", {"type": "start"}, true, 18)
	if sim.has_saved_run():
		_draw_button(Rect2(805, 690, 235, 70), "RESUME RUN", {"type": "resume"}, false, 17)
	_draw_button(Rect2(1053, 690, 310, 70), "CODEX  ·  %d discoveries" % _codex_count(), {"type": "title_codex"}, false, 16)
	_draw_button(Rect2(70, 690, 310, 70), "CONTENT / MODS", {"type": "content_mods"}, false, 15)
	_draw_label("Landscape first  ·  Touch or mouse  ·  No timer while you decide", 56, 680, 13, COLORS.muted)
	_draw_corner_marks(Rect2(47, 215, 1346, 450))

func _draw_character_portrait(rect: Rect2, definition: Dictionary) -> void:
	var portrait_path := String(definition.get("portrait_path", ""))
	var texture := _load_portrait_texture(portrait_path) if portrait_path != "" else null
	if texture is Texture2D:
		draw_rect(rect, Color("#0b141b"))
		var portrait_box := rect.grow(-3.0)
		var source_size := texture.get_size()
		var portrait_scale := minf(portrait_box.size.x / source_size.x, portrait_box.size.y / source_size.y)
		var fitted_size := source_size * portrait_scale
		var fitted_rect := Rect2(portrait_box.position + (portrait_box.size - fitted_size) * 0.5, fitted_size)
		draw_texture_rect(texture, fitted_rect, false)
		return
	_draw_panel(rect, "", COLORS.line_soft)
	var key := String(definition.get("portrait_key", ""))
	var symbol: String = String({"mundane": "⚔", "archer": "➶", "apprentice": "◈", "defender": "⛨"}.get(key, "◇"))
	_draw_label(String(symbol), rect.get_center().x, rect.get_center().y + 7, 26, COLORS.cyan, HORIZONTAL_ALIGNMENT_CENTER)

func _load_portrait_texture(portrait_path: String) -> Texture2D:
	if portrait_texture_cache.has(portrait_path):
		return portrait_texture_cache[portrait_path] as Texture2D
	var texture: Texture2D = load(portrait_path) as Texture2D if ResourceLoader.exists(portrait_path) else null
	if texture == null and FileAccess.file_exists(portrait_path):
		var portrait_image := Image.new()
		if portrait_image.load(portrait_path) == OK:
			texture = ImageTexture.create_from_image(portrait_image)
	if texture != null:
		portrait_texture_cache[portrait_path] = texture
	return texture

func _character_card_presentation(character_id: String) -> Dictionary:
	var definition: Dictionary = sim.content.get("characters", {}).get(character_id, {})
	if definition.is_empty():
		return {}
	if not sim.is_character_unlocked(character_id):
		return {"unlocked": false, "requirement": sim.get_character_unlock_requirement(character_id)}
	return {
		"unlocked": true,
		"class_title": String(definition.get("class_title", "Newly Unlocked Class")),
		"class_description": String(definition.get("class_description", definition.get("subtitle", "A distinct path with room to grow."))),
		"portrait_path": String(definition.get("portrait_path", ""))
	}

func _draw_content_mods(_rect: Rect2) -> void:
	_draw_label("CONTENT / MODS", 131, 106, 22, COLORS.text)
	_draw_label("Choose which installed content packages are active for new runs.", 132, 132, 12, COLORS.muted)
	var packages: Array = sim.content_registry.available_packages
	var official: Array = packages.filter(func(package: Dictionary) -> bool: return String(package.get("kind", "")) in ["core", "official"])
	var mods: Array = packages.filter(func(package: Dictionary) -> bool: return String(package.get("kind", "")) == "mod")
	var groups: Array = [{"title": "OFFICIAL CONTENT", "entries": official, "x": 130.0}, {"title": "MODS", "entries": mods, "x": 730.0}]
	for group in groups:
		var x := float(group.x)
		var column := Rect2(x, 168, 576, 430)
		_draw_panel(column, String(group.title), COLORS.line_soft)
		var values: Array = group.entries
		if values.is_empty():
			_draw_label("No installed packages", x + 20, 224, 13, COLORS.muted)
		else:
			for index in range(values.size()):
				var package: Dictionary = values[index]
				var row := Rect2(x + 14, 205 + index * 72, column.size.x - 28, 62)
				_draw_panel(row, "", COLORS.line_soft)
				_draw_label(_fit_text(String(package.get("name", "Content")), row.size.x - 154, 13), row.position.x + 12, row.position.y + 23, 13, COLORS.text)
				if not package.get("dependencies", []).is_empty():
					_draw_label("Needs other installed content", row.position.x + 12, row.position.y + 43, 9, COLORS.muted)
				var toggle_rect := Rect2(row.end.x - 119, row.position.y + 11, 105, 38)
				if package.get("required", false):
					draw_rect(toggle_rect, Color("#14221f"))
					draw_rect(toggle_rect, COLORS.green, false, 1.0)
					_draw_label("ALWAYS ON", toggle_rect.get_center().x, toggle_rect.get_center().y + 4, 9, COLORS.green, HORIZONTAL_ALIGNMENT_CENTER)
				else:
					_draw_button(toggle_rect, "DISABLE" if package.get("enabled", false) else "ENABLE", {"type": "package_toggle", "id": package.id, "enabled": not bool(package.get("enabled", false))}, false, 10)
	_draw_panel(Rect2(130, 615, 1176, 45), "", COLORS.line_soft)
	_draw_label("Core content is always active.", 150, 643, 10, COLORS.muted)
	_draw_button(Rect2(128, 675, 180, TOUCH_TARGET), "RETURN", {"type": "close"}, false, 12)

func _draw_character_reveal(_rect: Rect2) -> void:
	var character_id := reveal_character_id if reveal_character_id != "" else sim.get_pending_character_reveal()
	var definition: Dictionary = sim.content.get("characters", {}).get(character_id, {})
	_draw_label("A NEW CLASS IS AVAILABLE", 131, 107, 12, COLORS.gold)
	_draw_character_portrait(Rect2(142, 164, 210, 260), definition)
	var title := String(definition.get("class_title", "Newly Unlocked Class"))
	var description := String(definition.get("class_description", "A new path has joined your roster."))
	var fitted_title := _fit_text(title, 780, 27)
	_draw_label(fitted_title, 395, 223, 27, COLORS.text)
	_draw_label("CLASS DISCOVERED", 397, 251, 10, COLORS.cyan)
	var description_lines := _wrap(description, 64)
	for line_index in range(mini(4, description_lines.size())):
		_draw_label(String(description_lines[line_index]), 397, 292 + line_index * 23, 13, COLORS.muted)
	_draw_panel(Rect2(395, 390, 760, 60), "", COLORS.line_soft)
	_draw_label("This unlock is saved permanently to your profile.", 417, 426, 12, COLORS.text)
	_draw_button(Rect2(961, 675, 245, TOUCH_TARGET), "CONTINUE", {"type": "close"}, true, 13)

func _battle_layout() -> Dictionary:
	var active_panel := String(ui_state.active_lower_panel)
	var panel_height := 0.0
	if not _is_mobile_layout():
		panel_height = 260.0
	elif ui_state.lower_dock_expanded:
		panel_height = 260.0 if active_panel in ["inventory", "character"] else 220.0
	var dock_bottom := screen_size.y - 18.0
	var dock_top := dock_bottom - (panel_height if panel_height > 0.0 else 38.0)
	var toolbar_height := 104.0
	var toolbar_y := dock_top - toolbar_height - 10.0
	var battle_bottom := toolbar_y - 10.0
	var right_width := clampf(screen_size.x * 0.19, 258.0, 310.0)
	var left_rect := Rect2(18.0, 18.0, 216.0, maxf(220.0, battle_bottom - 36.0))
	var right_rect := Rect2(screen_size.x - right_width - 18.0, 18.0, right_width, maxf(200.0, battle_bottom - 36.0))
	var center_rect := Rect2(left_rect.end.x + 10.0, 48.0, right_rect.position.x - left_rect.end.x - 20.0, maxf(160.0, battle_bottom - 58.0))
	var max_tile := WIDE_TILE if _is_wide_layout() else BASE_TILE
	var tile := minf(max_tile, maxf(20.0, center_rect.size.y / float(ArcanistSim.HEIGHT)))
	var board_size := Vector2(ArcanistSim.WIDTH * tile, ArcanistSim.HEIGHT * tile)
	var board_rect := Rect2(Vector2(center_rect.position.x + (center_rect.size.x - board_size.x) * 0.5, 58.0), board_size)
	var dock_header_y := dock_top
	var dock_header_height := 26.0 if not _is_mobile_layout() else 38.0 if panel_height <= 0.0 else 34.0
	var panel_content_height := maxf(0.0, panel_height - dock_header_height)
	var timeline_height := clampf(right_rect.size.y * 0.34, 170.0, 190.0)
	var group_target_width := minf(screen_size.x * 0.68, 1280.0)
	var end_turn_width := 126.0
	var action_gap := 6.0
	var ordinary_count := 11 + (1 if target_mode != "" and not playback_active else 0)
	var slot_width := clampf((group_target_width - end_turn_width - float(ordinary_count) * action_gap) / float(ordinary_count), 64.0, 96.0)
	var action_width := float(ordinary_count) * slot_width + end_turn_width + float(ordinary_count) * action_gap
	var action_x := (screen_size.x - action_width) * 0.5
	return {
		"dock_top": dock_top, "dock_bottom": dock_bottom, "dock_header_y": dock_header_y,
		"dock_header_height": dock_header_height, "panel_content_height": panel_content_height,
		"toolbar_y": toolbar_y, "toolbar_height": toolbar_height, "battle_bottom": battle_bottom,
		"left_rect": left_rect, "center_rect": center_rect, "right_rect": right_rect,
		"board_rect": board_rect, "tile": tile, "timeline_height": timeline_height,
		"action_x": action_x, "action_slot_width": slot_width, "action_end_width": end_turn_width,
		"action_gap": action_gap, "action_width": action_width, "ordinary_count": ordinary_count
	}

func _draw_battle() -> void:
	if sim.run.is_empty():
		page = "title"
		return
	_draw_player_card()
	_draw_board()
	_draw_timeline()
	_draw_inspection_card()
	_draw_side_controls()
	_draw_action_bar()
	lower_dock.draw()
	if notice != "":
		_draw_toast(notice)

func _draw_player_card() -> void:
	var player: Dictionary = _display_player()
	var mobile := _is_mobile_layout()
	var card_layout := _player_card_layout(player, mobile)
	var rect: Rect2 = card_layout.rect
	var displayed_level := int(presentation_state.get("level", sim.run.get("level", 1))) if playback_active else int(sim.run.get("level", 1))
	var displayed_xp := int(presentation_state.get("xp", sim.run.get("xp", 0))) if playback_active else int(sim.run.get("xp", 0))
	_draw_panel(rect, "", COLORS.line)
	var level_label := "LV %d" % displayed_level
	var level_width := ThemeDB.fallback_font.get_string_size(level_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13).x
	var name_width := 190.0 - level_width - 10.0
	_draw_label(_fit_text(String(player.get("name", "Adventurer")), name_width, 15), 31, 44, 15, COLORS.text)
	_draw_label(level_label, 221, 44, 13, COLORS.gold, HORIZONTAL_ALIGNMENT_RIGHT)
	_draw_label(_fit_text("MAP %s  ·  STAGE %d / 6" % [_format_count_for_ui(sim.run.get("map_depth", "1")), int(sim.run.get("stage_index", 0)) + 1], 188, 9), 31, 64, 9, COLORS.muted)
	var xp_required := maxi(1, displayed_level * 35)
	_draw_label("XP  %d / %d" % [displayed_xp, xp_required], 31, 82, 8 if mobile else 9, COLORS.gold)
	var displayed_skill_points := int(presentation_state.get("skill_points", sim.run.get("skill_points", 0))) if playback_active else int(sim.run.get("skill_points", 0))
	if displayed_skill_points > 0:
		_draw_label("✦ %d AP" % displayed_skill_points, 221, 82, 9, COLORS.gold, HORIZONTAL_ALIGNMENT_RIGHT)
		active_hits.append({"rect": _touch_hit_rect(Rect2(163, 70, 58, 22)), "action": {"type": "lower_panel", "id": "character"}})
	draw_rect(Rect2(31, 88, 190, 4), Color("#22272b"))
	draw_rect(Rect2(31, 88, 190.0 * clampf(float(displayed_xp) / xp_required, 0.0, 1.0), 4), COLORS.gold)
	_draw_bar(Rect2(31, 98, 190, 20), "HP", player.hp, player.max_hp, COLORS.red)
	var resource_rows: Array = card_layout.resource_rows
	var resource_y: float = card_layout.resource_y
	var resource_step: float = card_layout.resource_step
	var resource_height := 16.0 if mobile else 18.0
	for resource_index in range(resource_rows.size()):
		var resource = resource_rows[resource_index]
		var resource_color: Color = resource[2]
		_draw_bar(Rect2(31.0, resource_y + float(resource_index) * resource_step, 190.0, resource_height), String(resource[0]), int(resource[1][0]), int(resource[1][1]), resource_color)
	var attributes_y: float = card_layout.attributes_y
	_draw_line(31, attributes_y - 10, 221, attributes_y - 10, COLORS.line_soft)
	var attributes: Dictionary = presentation_state.get("attributes", sim.run.attributes) if playback_active else sim.run.attributes
	var names: Array = ["Might", "Dexterity", "Vitality", "Intelligence", "Willpower", "Perception"]
	for i in range(names.size()):
		var column := i % 2
		var row := int(i / 2)
		var stat_x := 31 + column * 96
		var stat_y := attributes_y + 12 + row * (14.0 if mobile else 17.0)
		_draw_label("%s  %d" % [String(names[i]).substr(0, 3).to_upper(), int(attributes.get(names[i], 10))], stat_x, stat_y, 8 if mobile else 9, COLORS.text)
	var status_y: float = card_layout.status_y
	_draw_line(31, status_y - 12, 221, status_y - 12, COLORS.line_soft)
	_draw_label("ACTIVE EFFECTS", 31, status_y, 9, COLORS.gold)
	var status_ids: Array = card_layout.status_ids
	var status_font_size: int = card_layout.status_font_size
	for status_index in range(status_ids.size()):
		var status_id: Variant = status_ids[status_index]
		var status: Dictionary = player.statuses[status_id]
		var duration := int(status.get("duration", status.get("turns", 0)))
		var suffix := " (%d)" % int(status.get("stacks", 1))
		if duration > 0: suffix += " · %d" % duration
		var baseline: float = card_layout.status_baselines[status_index]
		var effect_text := "✦  %s%s" % [String(status_id).replace("_", " "), suffix]
		_draw_label(_fit_text(effect_text, 183.0, status_font_size), 34, baseline, status_font_size, COLORS.cyan if status_id in ["Haste", "Empowered"] else COLORS.orange)
	if status_ids.is_empty():
		_draw_label("No active effects", 34, float(card_layout.status_baselines[0]), status_font_size, COLORS.muted)

func _player_card_layout(player: Dictionary, mobile: bool) -> Dictionary:
	var resource_rows := _player_resource_rows(player)
	var resource_y := 126.0 if mobile else 130.0
	var resource_step := 17.0 if mobile else 19.0
	var resource_height := 16.0 if mobile else 18.0
	var resource_end_y := resource_y + float(maxi(0, resource_rows.size() - 1)) * resource_step + resource_height
	var attributes_y := 184.0 if mobile else 224.0
	var attribute_step := 14.0 if mobile else 17.0
	attributes_y = maxf(attributes_y, resource_end_y + 8.0 - 12.0)
	var first_attribute_baseline := attributes_y + 12.0
	var last_attribute_baseline := attributes_y + 12.0 + 2.0 * attribute_step
	var status_y := maxf(244.0 if mobile else 313.0, last_attribute_baseline + 20.0)
	var status_font_size := 8 if mobile else 10
	var status_step := maxf(16.0, _text_line_height(status_font_size) + 3.0)
	var status_ids: Array = player.get("statuses", {}).keys()
	var status_baselines: Array[float] = []
	var visible_status_count := maxi(1, status_ids.size())
	for status_index in range(visible_status_count):
		status_baselines.append(status_y + 18.0 + float(status_index) * status_step)
	var bottom_padding := maxf(12.0, _text_line_height(status_font_size) + 6.0)
	var content_bottom: float = status_baselines.back() + bottom_padding
	var card_height := maxf(244.0 if mobile else 392.0, content_bottom - 18.0)
	return {
		"rect": Rect2(18.0, 18.0, 216.0, card_height),
		"resource_rows": resource_rows,
		"resource_y": resource_y,
		"resource_step": resource_step,
		"resource_end_y": resource_end_y,
		"attributes_y": attributes_y,
		"first_attribute_baseline": first_attribute_baseline,
		"status_y": status_y,
		"status_ids": status_ids,
		"status_step": status_step,
		"status_font_size": status_font_size,
		"status_baselines": status_baselines,
		"bottom_padding": bottom_padding
	}

func _player_resource_rows(player: Dictionary) -> Array:
	var has_mana_actions: bool = not sim.run.get("schools", []).is_empty()
	for ability_id in sim.run.get("known", []):
		if sim.content.abilities.has(ability_id) and int(sim.content.abilities[ability_id].get("costs", {}).get("Mana", 0)) > 0:
			has_mana_actions = true
	var command_is_relevant := int(player.get("resources", {}).get("Command", [0, 0])[0]) > 0
	for ability_id in sim.run.get("known", []):
		for effect in sim.content.abilities.get(ability_id, {}).get("effects", []):
			if effect.get("type") == "summon":
				command_is_relevant = true
	var resource_rows: Array = [["STA", player.resources.get("Stamina", [0, 0]), COLORS.green]]
	if has_mana_actions:
		resource_rows.append(["MP", player.resources.get("Mana", [0, 0]), COLORS.blue])
	var blood: Array = player.resources.get("Blood", [0, 0])
	if int(blood[1]) > 0:
		resource_rows.append(["BLOOD", blood, COLORS.blood])
	if command_is_relevant:
		resource_rows.append(["CMD", player.resources.get("Command", [0, 0]), COLORS.purple])
	return resource_rows

func _display_player() -> Dictionary:
	if playback_active and presentation_state.get("entities", {}).has("player"):
		return presentation_state.entities.player
	return sim.get_player()

func _is_quickbar_assigned(action_type: String, action_id: String) -> bool:
	for slot in sim.run.get("quickbar", []):
		if slot.get("type", "") == action_type and slot.get("id", "") == action_id:
			return true
	return false

func _draw_board() -> void:
	var origin := _board_origin()
	var tile := _tile_size()
	var board_rect := _board_rect()
	_draw_panel(Rect2(board_rect.position - Vector2(8.0, 8.0), board_rect.size + Vector2(16.0, 16.0)), "", COLORS.line)
	var board_state: Dictionary = presentation_state if playback_active else sim.run
	var grid: Array = board_state.get("grid", sim.run.grid)
	var visible: Array = board_state.get("visible", sim.run.visible)
	var explored: Array = board_state.get("explored", sim.run.explored)
	for y in range(ArcanistSim.HEIGHT):
		for x in range(ArcanistSim.WIDTH):
			var cell := Vector2i(x, y)
			var rect := Rect2(origin + Vector2(x * tile, y * tile), Vector2(tile - 1, tile - 1))
			var seen := bool(explored[y][x])
			var lit := bool(visible[y][x])
			var terrain: String = grid[y][x]
			var fill := Color("#070e14")
			var glyph := ""
			var glyph_color := COLORS.muted
			if seen:
				match terrain:
					"wall":
						fill = Color("#2a3440") if lit else Color("#151e27")
						glyph = "▪"
						glyph_color = Color("#657681") if lit else Color("#34414b")
					"water":
						fill = Color("#09253b") if lit else Color("#091b2a")
						glyph = "~"
						glyph_color = COLORS.cyan if lit else Color("#28516b")
					"ice":
						fill = Color("#1a3b4a") if lit else Color("#122833")
						glyph = "*"
						glyph_color = Color("#90e7ff")
					"fire":
						fill = Color("#472417") if lit else Color("#211710")
						glyph = "*"
						glyph_color = COLORS.orange
					"blood":
						fill = Color("#361923") if lit else Color("#1e151c")
						glyph = ":"
						glyph_color = COLORS.blood
					"vegetation":
						fill = Color("#15291f") if lit else Color("#101b18")
						glyph = "♣"
						glyph_color = COLORS.green if lit else Color("#345240")
					_:
						fill = Color("#16202a") if lit else Color("#101820")
						glyph = "·" if lit and (x + y) % 4 == 0 else ""
						glyph_color = Color("#354653")
			draw_rect(rect, fill)
			if glyph != "" and (lit or terrain == "wall"):
				_draw_label(glyph, rect.position.x + tile * 0.5, rect.position.y + tile * 0.68, 15 if tile <= BASE_TILE else 17, glyph_color, HORIZONTAL_ALIGNMENT_CENTER)
			if not lit:
				draw_rect(rect, Color(0.015, 0.025, 0.035, 0.28 if seen else 0.78))
	if not playback_active: _draw_targetable_cells(origin, tile)
	var board_objects: Array = board_state.get("objects", sim.run.objects)
	for object in board_objects:
		if int(object.get("hp", 1)) <= 0:
			continue
		var cell := Vector2i(int(object.pos[0]), int(object.pos[1]))
		if playback_active and not _display_cell_visible(cell) or not playback_active and not sim._cell_visible(cell):
			continue
		var center := _cell_center(cell)
		if object.get("kind") == "exit":
			draw_circle(center, 11, Color(0.2, 0.62, 0.9, 0.4))
			_draw_label("⇢", center.x, center.y + 7, 19, COLORS.cyan, HORIZONTAL_ALIGNMENT_CENTER)
		elif object.get("kind") == "chest":
			draw_circle(center, 11, Color(0.72, 0.45, 0.12, 0.3))
			_draw_label("▣", center.x, center.y + 6, 17, COLORS.gold, HORIZONTAL_ALIGNMENT_CENTER)
		elif object.get("kind") == "skill_book":
			draw_circle(center, 10, Color(0.51, 0.33, 0.75, 0.3))
			_draw_label("▤", center.x, center.y + 6, 15, COLORS.purple, HORIZONTAL_ALIGNMENT_CENTER)
		elif object.get("kind") in ["loot", "item"]:
			draw_circle(center, 10, Color(0.23, 0.56, 0.48, 0.26))
			_draw_label("★" if object.get("marker", "") == "star" else "✦", center.x, center.y + 5, 13, COLORS.gold if object.get("marker", "") == "star" else COLORS.cyan, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			draw_circle(center, 12, Color(0.59, 0.14, 0.2, 0.3))
			_draw_label("◆", center.x, center.y + 6, 15, COLORS.red, HORIZONTAL_ALIGNMENT_CENTER)
	for corpse in board_state.get("corpses", sim.run.corpses):
		var cell: Vector2i = Vector2i(int(corpse.pos[0]), int(corpse.pos[1]))
		if (playback_active and _display_cell_visible(cell) or not playback_active and sim._cell_visible(cell)) and (not playback_active or _display_occupant(cell) == ""):
			_draw_label("×", _cell_center(cell).x, _cell_center(cell).y + 5, 11, Color("#9b7378"), HORIZONTAL_ALIGNMENT_CENTER)
	var board_entities: Array = sim.get_visible_entities()
	if playback_active:
		board_entities = presentation_state.get("entities", {}).values()
	for entity in board_entities:
		if not entity.get("alive", true): continue
		var entity_id := String(entity.get("id", ""))
		var cell_float := Vector2(float(entity.pos[0]), float(entity.pos[1]))
		if playback_active and String(current_presentation_event.get("type", "")) == "Move" and acting_actor_id == entity_id:
			var move_details: Dictionary = current_presentation_event.get("details", {})
			if move_details.has("from") and move_details.has("to"):
				var move_progress := clampf(playback_elapsed / maxf(0.01, _presentation_event_duration("Move")), 0.0, 1.0)
				var move_from := Vector2(float(move_details.from[0]), float(move_details.from[1]))
				var move_to := Vector2(float(move_details.to[0]), float(move_details.to[1]))
				cell_float = move_from.lerp(move_to, move_progress)
		var cell := Vector2i(roundi(cell_float.x), roundi(cell_float.y))
		var size := int(entity.get("footprint", 1))
		var entity_rect := Rect2(origin + Vector2(cell_float.x * tile + 3, cell_float.y * tile + 3), Vector2(tile * size - 7, tile * size - 7))
		var presentation: Dictionary = _display_entity_presentation(entity)
		var entity_color := _entity_presentation_color(String(presentation.color_key))
		if entity_id == selected_enemy:
			draw_rect(entity_rect.grow(2), COLORS.gold, false, 2)
		if playback_active and entity_id == acting_actor_id:
			draw_rect(entity_rect.grow(4), Color(COLORS.gold.r, COLORS.gold.g, COLORS.gold.b, 0.78), false, 2.5)
		elif playback_active and entity_id == acting_target_id:
			draw_rect(entity_rect.grow(2), Color(COLORS.red.r, COLORS.red.g, COLORS.red.b, 0.72), false, 2)
		if not playback_active and target_mode != "" and entity_id != "player" and sim._is_hostile("player", entity_id) and _entity_is_legal_target(entity):
			draw_rect(entity_rect.grow(1), Color(0.9, 0.24, 0.3, 0.22), true)
			draw_rect(entity_rect.grow(1), COLORS.green, false, 2)
		var glyph := String(presentation.symbol)
		var center := entity_rect.get_center()
		_draw_label(glyph, center.x, center.y + 7, 20 if size == 1 else 26, entity_color, HORIZONTAL_ALIGNMENT_CENTER)
		if entity_id != "player":
			var hp_fraction := clampf(float(entity.hp) / maxf(1.0, float(entity.max_hp)), 0.0, 1.0)
			draw_rect(Rect2(entity_rect.position.x, entity_rect.end.y + 1, entity_rect.size.x, 3), Color("#151c22"))
			draw_rect(Rect2(entity_rect.position.x, entity_rect.end.y + 1, entity_rect.size.x * hp_fraction, 3), COLORS.red if entity.get("kind", "enemy") != "summon" else COLORS.cyan)
	if playback_active:
		_draw_presentation_effect(origin, tile)
		_draw_floating_combat_text()
	if target_mode != "" and not playback_active:
		_draw_label("TARGETING  ·  %s  ·  tap a highlighted target; tap the action again to cancel" % _target_action_name(), origin.x, origin.y - 15, 9, COLORS.gold)
	else:
		_draw_label("%s  ·  %s" % [sim.get_stage_name().to_upper(), sim.get_objective_text()], origin.x, origin.y - 15, 11, COLORS.text)
	if target_mode != "" and not playback_active and _point_in_board(press_current_position):
		var preview_cell := _cell_from_point(press_current_position)
		if sim._inside(preview_cell):
			var preview_center := _cell_center(preview_cell)
			draw_rect(Rect2(preview_center - Vector2(tile * 0.44, tile * 0.44), Vector2(tile * 0.88, tile * 0.88)), COLORS.gold, false, 2.5)
			var radius := _target_preview_radius()
			if radius > 0:
				for y in range(maxi(0, preview_cell.y - radius), mini(ArcanistSim.HEIGHT, preview_cell.y + radius + 1)):
					for x in range(maxi(0, preview_cell.x - radius), mini(ArcanistSim.WIDTH, preview_cell.x + radius + 1)):
						var area_cell := Vector2i(x, y)
						if sim._dist(preview_cell, area_cell) <= radius:
							var area_rect := Rect2(origin + Vector2(x * tile, y * tile), Vector2(tile - 1, tile - 1))
							draw_rect(area_rect, Color(0.92, 0.76, 0.28, 0.11), true)
							draw_rect(area_rect, Color(0.92, 0.76, 0.28, 0.6), false, 1.0)

func _display_cell_visible(cell: Vector2i) -> bool:
	if not sim._inside(cell) or not presentation_state.has("visible"): return false
	return bool(presentation_state.visible[cell.y][cell.x])

func _display_occupant(cell: Vector2i) -> String:
	for entity_id in presentation_state.get("entities", {}):
		var entity: Dictionary = presentation_state.entities[entity_id]
		if entity.get("alive", true) and sim._pos(entity) == cell: return String(entity_id)
	return ""

func _display_entity_presentation(entity: Dictionary) -> Dictionary:
	var entity_id := String(entity.get("id", ""))
	var definition: Dictionary = sim.content.get("summons", {}).get(entity.get("enemy_id", entity_id), sim.content.get("enemies", {}).get(entity.get("enemy_id", entity_id), {}))
	var faction := String(entity.get("faction", ""))
	return {"id": entity_id, "name": String(entity.get("name", definition.get("name", "Creature"))),
		"symbol": "@" if entity_id == "player" else String(entity.get("symbol", definition.get("symbol", "?"))),
		"color_key": "player" if entity_id == "player" else "ally" if faction == "Adventurers" else "hostile" if faction in ["Undead", "Demons"] else "other"}

func _draw_presentation_effect(origin: Vector2, tile: float) -> void:
	if current_presentation_event.is_empty(): return
	var kind := String(current_presentation_event.get("type", ""))
	var details: Dictionary = current_presentation_event.get("details", {})
	if kind not in ["Attack", "Cast"]: return
	var actor_id := String(current_presentation_event.get("actor_id", ""))
	var target_id := String(current_presentation_event.get("target_id", ""))
	if not presentation_state.get("entities", {}).has(actor_id): return
	var actor_pos := sim._pos(presentation_state.entities[actor_id])
	var color := COLORS.gold if kind == "Attack" else _school_color(String(details.get("school", "Arcane")))
	var target_pos := actor_pos
	if target_id != "" and presentation_state.entities.has(target_id): target_pos = sim._pos(presentation_state.entities[target_id])
	elif details.has("pos"): target_pos = Vector2i(int(details.pos[0]), int(details.pos[1]))
	var from_point := origin + Vector2(actor_pos.x * tile + tile * 0.5, actor_pos.y * tile + tile * 0.5)
	var to_point := origin + Vector2(target_pos.x * tile + tile * 0.5, target_pos.y * tile + tile * 0.5)
	var pulse := 1.0 - clampf(playback_elapsed / maxf(0.01, playback_timer + playback_elapsed), 0.0, 1.0)
	if kind == "Cast":
		draw_line(from_point, to_point, Color(color.r, color.g, color.b, 0.75 * pulse), 3.0)
		draw_circle(to_point, 8.0 + 10.0 * (1.0 - pulse), Color(color.r, color.g, color.b, 0.3 * pulse))
	else:
		draw_line(from_point, to_point, Color(color.r, color.g, color.b, 0.8 * pulse), 4.0)

func _draw_floating_combat_text() -> void:
	var now := Time.get_ticks_msec()
	var stack_counts: Dictionary = {}
	var placed_labels: Array[Rect2] = []
	for item in floating_events:
		var elapsed := now - int(item.born)
		var progress := clampf(float(elapsed) / float(item.duration), 0.0, 1.0)
		var cell: Vector2i = item.cell
		var stack_key := "%d,%d" % [cell.x, cell.y]
		var stack_index := int(stack_counts.get(stack_key, 0))
		stack_counts[stack_key] = stack_index + 1
		var center := _cell_center(cell)
		var baseline := center.y - 18.0 - progress * 28.0 - stack_index * 17.0
		var text_size: Vector2 = ThemeDB.fallback_font.get_string_size(String(item.text), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12)
		var label_rect := Rect2(center.x - text_size.x * 0.5, baseline - 13.0, text_size.x, 16.0)
		var collision_steps := 0
		while collision_steps < 8:
			var overlaps := false
			for placed_rect in placed_labels:
				if label_rect.intersects(placed_rect):
					overlaps = true
					break
			if not overlaps:
				break
			label_rect.position.y -= 18.0
			collision_steps += 1
		placed_labels.append(label_rect)
		var color: Color = item.color
		color.a = 1.0 - progress
		_draw_label(String(item.text), center.x, label_rect.position.y + 13.0, 12, color, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_timeline() -> void:
	var layout := _battle_layout()
	var right_rect: Rect2 = layout.right_rect
	var panel_rect := Rect2(right_rect.position, Vector2(right_rect.size.x, float(layout.timeline_height)))
	var content_top := _draw_panel(panel_rect, "TURN TIMELINE", COLORS.line)
	var entries: Array = []
	var timeline_entities: Dictionary = presentation_state.get("entities", {}) if playback_active else sim.run.get("entities", {})
	for entity_id in timeline_entities:
		var entity: Dictionary = timeline_entities[entity_id]
		if not entity.get("alive", true): continue
		if entity_id != "player" and (playback_active and not entity_id in presentation_state.get("entities", {}) or not playback_active and not sim._cell_visible(sim._pos(entity))): continue
		entries.append({"id": String(entity_id), "name": String(entity.get("name", "Creature")), "symbol": "@" if entity_id == "player" else String(entity.get("symbol", "?")), "faction": String(entity.get("faction", "")), "time": int(entity.get("next_time", 0)), "kind": String(entity.get("kind", "enemy"))})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.time == b.time: return a.id < b.id
		return a.time < b.time)
	entries = entries.slice(0, 6)
	var label_x := panel_rect.position.x + 14.0
	var time_x := panel_rect.end.x - 15.0
	var footer_y := panel_rect.end.y - 30.0
	var first_entry_y := content_top + 7.0
	var last_entry_y := footer_y - 10.0
	var entry_step := (last_entry_y - first_entry_y) / float(maxi(1, entries.size() - 1))
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var y := first_entry_y + float(i) * entry_step
		var entry_id := String(entry.id)
		var color_key := "player" if entry_id == "player" else "ally" if entry.faction == "Adventurers" else "hostile" if entry.faction in ["Undead", "Demons"] else "other"
		var color := _entity_presentation_color(color_key)
		var is_current := entry_id == "player" and not playback_active
		var is_acting := playback_active and entry_id == acting_actor_id
		if is_current or is_acting:
			var row_height := minf(18.0, entry_step if entries.size() > 1 else 18.0)
			draw_rect(Rect2(panel_rect.position.x + 7, y - row_height + 3.0, panel_rect.size.x - 14, row_height), Color(0.75, 0.58, 0.2, 0.14), true)
			draw_rect(Rect2(panel_rect.position.x + 7, y - row_height + 3.0, 3, row_height), COLORS.gold, true)
		_draw_label(String(entry.symbol), label_x, y, 14, color)
		_draw_label(_fit_text(String(entry.name), panel_rect.size.x - 94.0, 10), label_x + 22, y, 10, COLORS.text)
		var time_left := int(entry.time) - int(sim.get_player().next_time)
		_draw_label("ACTING" if is_acting else "NOW" if entry_id == "player" else str(maxi(0, time_left)), time_x, y, 9, COLORS.gold if is_acting or is_current else COLORS.muted, HORIZONTAL_ALIGNMENT_RIGHT)
		active_hits.append({"rect": _touch_hit_rect(Rect2(panel_rect.position.x + 7, y - 18, panel_rect.size.x - 14, 23)), "action": {"type": "inspect_entity", "id": entry_id}})
	_draw_line(label_x, footer_y, time_x, footer_y, COLORS.line_soft)
	_draw_label("NEXT ACTION  ·  TIME COST", label_x, panel_rect.end.y - 9.0, 8, COLORS.muted)

func _draw_inspection_card() -> void:
	var layout := _battle_layout()
	var right_rect: Rect2 = layout.right_rect
	var context_top := right_rect.position.y + float(layout.timeline_height) + 8.0
	var context_bottom := float(layout.battle_bottom) - 18.0
	var context_height := minf(250.0, maxf(160.0, context_bottom - context_top))
	var rect := Rect2(right_rect.position.x, context_top, right_rect.size.x, context_height)
	var content_x := rect.position.x + 14.0
	var content_width := rect.size.x - 28.0
	var display_entities: Dictionary = presentation_state.get("entities", {}) if playback_active else sim.run.get("entities", {})
	var enemy: Dictionary = display_entities.get(selected_enemy, {})
	var enemy_selected: bool = not enemy.is_empty() and bool(enemy.get("alive", true)) and (playback_active or sim._cell_visible(sim._pos(enemy)))
	var object: Dictionary = _selected_object()
	var content_top := _draw_panel(rect, "ENEMY INSPECTION" if enemy_selected else "FIELD INTELLIGENCE", COLORS.line)
	if enemy_selected or not object.is_empty():
		_draw_button(Rect2(rect.end.x - 31.0, rect.position.y + 2.0, 27.0, 26.0), "×", {"type": "clear_inspection"}, false, 9, COLORS.gold)
	var cursor_y := content_top
	if not object.is_empty():
		var object_kind := String(object.get("kind", "object"))
		var can_interact := object_kind in ["exit", "chest", "skill_book", "loot", "item"]
		_draw_label(String(object.get("name", "Field object")), content_x, cursor_y, 14, COLORS.cyan if object_kind == "exit" else COLORS.gold)
		var object_description: String = String({"chest": "Contents unknown until opened", "skill_book": "Run-specific ability learning", "loot": "A useful drop marked with a star", "item": "A field reward", "exit": "Stage exit", "ward": "%d / %d HP" % [int(object.get("hp", 1)), int(object.get("max_hp", 1))]}.get(object_kind, object_kind.capitalize()))
		_draw_label(_fit_text(String(object_description), content_width, 10), content_x, cursor_y + 22.0, 10, COLORS.text)
		var object_cell := Vector2i(int(object.pos[0]), int(object.pos[1]))
		_draw_label("Distance  ·  %d tiles" % sim._dist(sim._pos(sim.get_player()), object_cell), content_x, cursor_y + 42.0, 9, COLORS.muted)
		var object_action := {"type": "interact"} if can_interact else {"type": "target_object"}
		var object_label := "INTERACT" if object_kind == "exit" else "OPEN CHEST" if object_kind == "chest" else "PICK UP" if object_kind in ["skill_book", "loot", "item"] else "TARGET WARD"
		_draw_button(Rect2(content_x, cursor_y + 54.0, content_width, 46.0), object_label, object_action, false, 10)
		cursor_y += 110.0
	elif enemy_selected:
		var glyph := String(_display_entity_presentation(enemy).get("symbol", "?"))
		_draw_label(glyph, content_x + 4.0, cursor_y + 9.0, 25, COLORS.red if enemy.faction in ["Undead", "Demons"] else COLORS.gold)
		_draw_label(_fit_text(String(enemy.get("name", "Creature")), content_width - 36.0, 13), content_x + 35.0, cursor_y + 7.0, 13, COLORS.text)
		_draw_label("HP  %d / %d" % [int(enemy.get("hp", 0)), int(enemy.get("max_hp", 1))], content_x + 35.0, cursor_y + 25.0, 9, COLORS.muted)
		var hp_bar := Rect2(content_x + 35.0, cursor_y + 32.0, maxf(40.0, content_width - 40.0), 5.0)
		draw_rect(hp_bar, Color("#202a30"))
		draw_rect(Rect2(hp_bar.position, Vector2(hp_bar.size.x * clampf(float(enemy.get("hp", 0)) / maxf(1.0, float(enemy.get("max_hp", 1))), 0.0, 1.0), hp_bar.size.y)), COLORS.red)
		cursor_y += 51.0
		var footprint := int(enemy.get("footprint", 1))
		_draw_label("%s  ·  %s" % ["Large %d×%d" % [footprint, footprint] if footprint > 1 else "Standard", String(enemy.get("kind", "enemy")).capitalize()], content_x, cursor_y, 9, COLORS.muted)
		cursor_y += 17.0
		var damage_type := String(enemy.get("damage_type", "Blunt"))
		_draw_label("Attack  %d–%d  ·  %s" % [int(enemy.get("min_damage", enemy.get("damage", 0))), int(enemy.get("max_damage", enemy.get("damage", 0))), damage_type], content_x, cursor_y, 9, COLORS.text)
		cursor_y += 17.0
		var resistances: Dictionary = enemy.get("resist", {})
		var vulnerabilities: Dictionary = enemy.get("vulnerable", enemy.get("vulnerabilities", {}))
		_draw_label("Resist  %s" % (", ".join(resistances.keys()) if not resistances.is_empty() else "None"), content_x, cursor_y, 8, COLORS.cyan if not resistances.is_empty() else COLORS.muted)
		cursor_y += 15.0
		_draw_label("Vulnerable  %s" % (", ".join(vulnerabilities.keys()) if not vulnerabilities.is_empty() else "None"), content_x, cursor_y, 8, COLORS.gold if not vulnerabilities.is_empty() else COLORS.muted)
		cursor_y += 16.0
		var status_line := ", ".join(enemy.get("statuses", {}).keys()) if not enemy.get("statuses", {}).is_empty() else "Clear"
		_draw_label("Effects  %s" % _fit_text(status_line, content_width - 50.0, 8), content_x, cursor_y, 8, COLORS.orange if status_line != "Clear" else COLORS.muted)
		cursor_y += 18.0
	else:
		_draw_label("OBJECTIVE", content_x, cursor_y, 9, COLORS.gold)
		cursor_y += 17.0
		for line in _wrap_text_to_width(sim.get_objective_text(), content_width, 10):
			_draw_label(String(line), content_x, cursor_y, 10, COLORS.text)
			cursor_y += _text_line_height(10)
		_draw_label("STAGE  ·  %d / 6%s" % [int(sim.run.stage_index) + 1, "  ·  BOSS" if int(sim.run.stage_index) == 5 else ""], content_x, cursor_y + 3.0, 9, COLORS.gold)
		cursor_y += 20.0
		_draw_label("%d hostiles  ·  %d XP  ·  Level %d" % [sim._hostile_count(), int(sim.run.xp), int(sim.run.level)], content_x, cursor_y, 8, COLORS.muted)
		cursor_y += 22.0
	var feed: Array = presentation_history if playback_active else sim.run.get("combat_history", [])
	var can_show_next: bool = bool(sim.run.get("stage_completed", false))
	var show_next_button: bool = can_show_next
	var reserved_bottom := 14.0 + (44.0 if show_next_button else 0.0)
	var feed_capacity := maxi(0, int((rect.end.y - reserved_bottom - cursor_y - 36.0) / 14.0))
	var event_count := mini(mini(6, feed.size()), feed_capacity)
	var feed_start := maxf(cursor_y + 22.0, rect.end.y - reserved_bottom - (event_count * 14.0) - 26.0)
	if feed_start + 18.0 < rect.end.y - reserved_bottom:
		_draw_line(content_x, feed_start - 12.0, content_x + content_width, feed_start - 12.0, COLORS.line_soft)
		_draw_label("RECENT EVENTS  ·  VIEW HISTORY ›", content_x, feed_start, 8, COLORS.gold)
		active_hits.append({"rect": _touch_hit_rect(Rect2(content_x, feed_start - 12.0, content_width, 22.0)), "action": {"type": "open_combat_history"}})
	for i in range(event_count):
		var event: Dictionary = feed[feed.size() - 1 - i]
		_draw_label(_fit_text(_format_combat_event(event), content_width, 8), content_x, feed_start + 18.0 + i * 14.0, 8, COLORS.gold if event.get("type", "") in ["LevelUp", "XPGranted", "KillCredit"] else COLORS.text if i == 0 else COLORS.muted)
	if show_next_button:
		var button_y := rect.end.y - 49.0
		var transition_action := {"type": "next_stage"}
		var stage_index := int(sim.run.get("stage_index", 0))
		var next_label := "NEXT STAGE  ·  %d / 6  ›" % (stage_index + 2) if stage_index < 4 else "ENTER BOSS STAGE  ·  6 / 6  ›" if stage_index == 4 else "REVEAL NEXT MAP  ›"
		_draw_button(Rect2(content_x, button_y, content_width, 39.0), next_label, transition_action, true, 10, COLORS.green)

func _draw_side_controls() -> void:
	if not _is_mobile_layout():
		return
	var layout := _battle_layout()
	var dpad_y := float(layout.battle_bottom) - 162.0
	var dpad_x := 18.0 + (216.0 - 162.0) * 0.5
	var dpad_rect := Rect2(dpad_x, dpad_y, 162.0, 108.0)
	var player_rect: Rect2 = _player_card_layout(_display_player(), true).rect
	if dpad_rect.intersects(player_rect):
		# An expanded touch dock leaves little vertical room. Move the pad over the
		# board's lower-left margin instead of covering character information.
		dpad_rect.position.x = float(layout.center_rect.position.x) + 8.0
		dpad_rect.position.y = maxf(18.0, float(layout.battle_bottom) - 110.0)
	dpad_x = dpad_rect.position.x
	dpad_y = dpad_rect.position.y
	_draw_dpad_button(Rect2(dpad_x + 54.0, dpad_y, 54.0, 54.0), "▲", Vector2i(0, -1))
	_draw_dpad_button(Rect2(dpad_x, dpad_y + 54.0, 54.0, 54.0), "◀", Vector2i(-1, 0))
	_draw_dpad_button(Rect2(dpad_x + 54.0, dpad_y + 54.0, 54.0, 54.0), "▼", Vector2i(0, 1))
	_draw_dpad_button(Rect2(dpad_x + 108.0, dpad_y + 54.0, 54.0, 54.0), "▶", Vector2i(1, 0))

func _draw_action_bar() -> void:
	var layout := _battle_layout()
	var action_x := float(layout.action_x)
	var action_y := float(layout.toolbar_y)
	var slot_width := float(layout.action_slot_width)
	var end_turn_width := float(layout.action_end_width)
	var gap := float(layout.action_gap)
	var action_width := float(layout.action_width)
	_draw_panel(Rect2(action_x - 10.0, action_y, action_width + 20.0, float(layout.toolbar_height)), "", COLORS.line)
	var prompt := "COMBAT ACTIONS  ·  EQUIPPED ABILITIES AND ITEMS"
	if playback_active: prompt = "PRESENTING  ·  %s" % _format_combat_event(current_presentation_event)
	elif quickbar_assign_mode: prompt = "ASSIGNING  ·  TAP A SLOT FOR %s" % _quick_action_name(String(quickbar_pending.get("type", "")), String(quickbar_pending.get("id", ""))).to_upper()
	elif target_mode != "": prompt = "TARGETING  ·  %s  ·  TAP THE ACTION AGAIN, BACK OR × TO CANCEL" % _target_action_name()
	_draw_label(_fit_text(prompt, action_width - 18.0, 8), action_x, action_y + 12.0, 8, COLORS.gold if target_mode != "" or playback_active or quickbar_assign_mode else COLORS.muted)
	var y := action_y + 18.0
	var h := 84.0
	var x := action_x
	_draw_action_icon_slot(Rect2(x, y, slot_width, h), _ui_glyph("move"), "MOVE", "100T", {"type": "target_mode", "mode": "move"}, target_mode == "move", COLORS.cyan)
	x += slot_width + gap
	var weapon_id: String = sim.run.equipment.get("Weapon", "sword")
	var weapon: Dictionary = sim.content.weapons.get(weapon_id, sim.content.weapons.get("sword", {}))
	_draw_action_icon_slot(Rect2(x, y, slot_width, h), _ui_glyph("attack"), String(weapon.get("name", "Weapon")).to_upper(), "%d STA\n%dT" % [int(weapon.get("stamina", 0)), int(weapon.get("time", 100))], {"type": "target_mode", "mode": "attack"}, target_mode == "attack", COLORS.gold)
	x += slot_width + gap
	for slot_index in range(8):
		var assignment: Dictionary = sim.run.get("quickbar", [])[slot_index] if sim.run.get("quickbar", []).size() > slot_index else {"type": "empty", "id": ""}
		_draw_quickbar_slot(Rect2(x, y, slot_width, h), slot_index, assignment)
		x += slot_width + gap
	_draw_action_icon_slot(Rect2(x, y, slot_width, h), _ui_glyph("wait"), "WAIT", "100T", {"type": "wait"}, false, COLORS.muted)
	x += slot_width + gap
	if target_mode != "" and not playback_active:
		_draw_action_icon_slot(Rect2(x, y, slot_width, h), _ui_glyph("cancel"), "CANCEL", "", {"type": "cancel_target"}, false, COLORS.orange)
		x += slot_width + gap
	var end_action := {"type": "playback_skip"} if playback_active else {"type": "end_turn"}
	_draw_end_turn_slot(Rect2(x, y, end_turn_width, h), end_action, playback_active)

func _quick_action_name(action_type: String, action_id: String) -> String:
	if action_type == "ability":
		return String(sim.content.abilities.get(action_id, {}).get("name", action_id))
	if action_type == "item":
		return String(sim.content.items.get(action_id, {}).get("name", action_id))
	return action_id.replace("_", " ").capitalize()

func _draw_action_icon_slot(rect: Rect2, glyph: String, label: String, detail: String, action: Dictionary, active: bool, accent: Color) -> void:
	var fill := Color("#17342d") if active else Color("#0c151e")
	draw_rect(rect, fill)
	draw_rect(Rect2(rect.position.x + 3.0, rect.position.y + 2.0, rect.size.x - 6.0, 2.0), accent)
	draw_rect(rect, COLORS.gold if active else COLORS.line, false, 2.2 if active else 1.0)
	draw_circle(Vector2(rect.get_center().x, rect.position.y + 22.0), minf(17.0, rect.size.x * 0.28), Color(accent.r, accent.g, accent.b, 0.13))
	_draw_label(glyph, rect.get_center().x, rect.position.y + 25.0, 19, accent, HORIZONTAL_ALIGNMENT_CENTER)
	var label_lines := _wrap_text_to_width(label, rect.size.x - 8.0, 8, 2)
	if label_lines.size() == 1:
		_draw_label(label_lines[0], rect.get_center().x, rect.position.y + 45.0, 8, COLORS.text, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		for index in range(label_lines.size()):
			_draw_label(label_lines[index], rect.get_center().x, rect.position.y + 39.0 + float(index) * 10.0, 8, COLORS.text, HORIZONTAL_ALIGNMENT_CENTER)
	var detail_lines := _action_detail_lines(detail, rect.size.x - 8.0)
	for index in range(detail_lines.size()):
		var detail_y := rect.position.y + 57.0 + float(index) * (_text_line_height(7) + 1.0)
		_draw_label(detail_lines[index], rect.get_center().x, detail_y, 7, COLORS.muted, HORIZONTAL_ALIGNMENT_CENTER)
	active_hits.append({"rect": _panel_hit_rect(rect), "action": action})

func _draw_quickbar_slot(rect: Rect2, slot_index: int, assignment: Dictionary) -> void:
	var kind := String(assignment.get("type", "empty"))
	var action_id := String(assignment.get("id", ""))
	var label := "EMPTY"
	var glyph := "+"
	var detail := ""
	var accent := COLORS.line
	var action := {"type": "quickbar_slot", "index": slot_index}
	var enabled := true
	var selected_action := false
	if kind == "ability" and sim.content.abilities.has(action_id):
		var ability: Dictionary = sim.content.abilities[action_id]
		glyph = _ability_glyph(ability)
		label = String(ability.get("name", action_id))
		detail = "%s\n%dT" % [_cost_text(ability.get("costs", {})), int(ability.get("time", 0))]
		accent = _school_color(String(ability.get("school", "")))
		enabled = sim._can_pay(ability.get("costs", {}))
		selected_action = target_mode == action_id
		action = {"type": "quickbar_slot", "index": slot_index}
	elif kind == "item" and sim.content.items.has(action_id):
		var item: Dictionary = sim.content.items[action_id]
		var item_count := int(sim.run.inventory.count(action_id))
		glyph = _item_glyph(action_id, item)
		label = String(item.get("name", action_id)) if item_count > 0 else "EMPTY"
		detail = _quickbar_item_detail(item, item_count)
		accent = _item_color(String(item.get("type", "item")), String(item.get("rarity", "Common"))) if item_count > 0 else COLORS.line
		enabled = item_count > 0
	if quickbar_assign_mode:
		selected_action = true
		accent = COLORS.gold
	var fill := Color("#1a392e") if selected_action else Color("#121e28") if enabled else Color("#0a1015")
	draw_rect(rect, fill)
	draw_rect(Rect2(rect.position.x + 3.0, rect.position.y + 2.0, rect.size.x - 6.0, 2.0), accent)
	draw_rect(rect, COLORS.gold if selected_action else COLORS.line_soft, false, 2.2 if selected_action else 1.0)
	_draw_label(glyph, rect.get_center().x, rect.position.y + 25.0, 19, accent if enabled else COLORS.muted, HORIZONTAL_ALIGNMENT_CENTER)
	var label_lines := _wrap_text_to_width(label, rect.size.x - 8.0, 8, 2)
	if label_lines.size() == 1:
		_draw_label(label_lines[0], rect.get_center().x, rect.position.y + 45.0, 8, COLORS.text if enabled else COLORS.muted, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		for index in range(label_lines.size()):
			_draw_label(label_lines[index], rect.get_center().x, rect.position.y + 39.0 + float(index) * 10.0, 8, COLORS.text if enabled else COLORS.muted, HORIZONTAL_ALIGNMENT_CENTER)
	var detail_lines := _action_detail_lines(detail, rect.size.x - 8.0)
	for index in range(detail_lines.size()):
		var detail_y := rect.position.y + 57.0 + float(index) * (_text_line_height(7) + 1.0)
		_draw_label(detail_lines[index], rect.get_center().x, detail_y, 7, COLORS.muted, HORIZONTAL_ALIGNMENT_CENTER)
	_draw_label(str(slot_index + 1), rect.position.x + 5.0, rect.position.y + 12.0, 7, COLORS.gold)
	active_hits.append({"rect": _touch_hit_rect(rect), "action": {"type": "quickbar_slot", "index": slot_index}})

func _draw_action_slot(rect: Rect2, glyph: String, label: String, detail: String, action: Dictionary, active: bool, accent: Color) -> void:
	_draw_action_icon_slot(rect, glyph, label, detail, action, active, accent)

func _draw_end_turn_slot(rect: Rect2, action: Dictionary, skip: bool) -> void:
	var accent := COLORS.orange if skip else COLORS.green
	draw_rect(rect, Color("#17392b") if not skip else Color("#38251d"))
	draw_rect(rect, accent, false, 2.0)
	draw_rect(Rect2(rect.position.x + 4.0, rect.position.y + 4.0, rect.size.x - 8.0, rect.size.y - 8.0), Color(accent.r, accent.g, accent.b, 0.08), false, 1.0)
	_draw_label("▶▶" if skip else "↓", rect.get_center().x, rect.position.y + 29.0, 21, accent, HORIZONTAL_ALIGNMENT_CENTER)
	_draw_label("SKIP" if skip else "END TURN", rect.get_center().x, rect.position.y + 44.0, 9, COLORS.text, HORIZONTAL_ALIGNMENT_CENTER)
	_draw_label("" if skip else "100", rect.get_center().x, rect.position.y + 55.0, 7, COLORS.muted, HORIZONTAL_ALIGNMENT_CENTER)
	active_hits.append({"rect": _panel_hit_rect(rect), "action": action})

func _draw_utility_slot(rect: Rect2, icon_key: String, label: String, action: Dictionary, accent: Color) -> void:
	draw_rect(rect, COLORS.panel)
	draw_rect(rect, COLORS.line_soft, false, 1.0)
	_draw_label(_ui_glyph(icon_key), rect.get_center().x, rect.position.y + 33, 21, accent, HORIZONTAL_ALIGNMENT_CENTER)
	_draw_label(label, rect.get_center().x, rect.position.y + 60, 8, COLORS.text, HORIZONTAL_ALIGNMENT_CENTER)
	active_hits.append({"rect": _touch_hit_rect(rect), "action": action})

func _draw_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, screen_size), Color(0.005, 0.012, 0.02, 0.74))
	var overlay_hit_start_local := active_hits.size()
	var overlay_offset_x := (screen_size.x - LOGICAL_SIZE.x) * 0.5 if page == "battle" and screen_size.x > LOGICAL_SIZE.x else 0.0
	if not is_zero_approx(overlay_offset_x):
		draw_label_content_offset.x = overlay_offset_x
		draw_set_transform(draw_offset + Vector2(overlay_offset_x * draw_scale, 0.0), 0.0, Vector2(draw_scale, draw_scale))
	var rect := Rect2(100, 61, 1240, 690)
	_draw_panel(rect, "", COLORS.gold)
	overlay_hit_start = active_hits.size()
	if overlay == "content_mods":
		_draw_content_mods(rect)
	elif overlay == "character_reveal":
		_draw_character_reveal(rect)
	elif overlay == "abilities":
		_draw_abilities(rect)
	elif overlay == "action_palette":
		_draw_action_palette(rect)
	elif overlay == "rewards":
		_draw_rewards(rect)
	elif overlay == "map_reveal":
		_draw_map_reveal(rect)
	elif overlay == "new_run_confirm":
		_draw_new_run_confirmation(rect)
	elif overlay == "destinations":
		_draw_destination_picker(rect)
	elif overlay == "codex":
		_draw_codex(rect)
	elif overlay == "codex_book":
		_draw_spellbook_codex(rect)
	elif overlay == "combat_history":
		_draw_combat_history(rect)
	elif overlay == "inspect":
		_draw_inspect(rect)
	elif overlay == "pause":
		_draw_pause(rect)
	_draw_button(Rect2(1272, 67, TOUCH_TARGET, TOUCH_TARGET), "×", {"type": "close"}, false, 21)
	_draw_corner_marks(rect)
	if not is_zero_approx(overlay_offset_x):
		_shift_active_hits(overlay_hit_start_local, overlay_offset_x)
		draw_label_content_offset.x = 0.0
		draw_set_transform(draw_offset, 0.0, Vector2(draw_scale, draw_scale))

func _draw_combat_history(rect: Rect2) -> void:
	var history: Array = sim.run.get("combat_history", [])
	var per_page := 20
	var page_count := maxi(1, int(ceil(float(history.size()) / float(per_page))))
	combat_history_page = clampi(combat_history_page, 0, page_count - 1)
	var first_index := combat_history_page * per_page
	_draw_label("ENCOUNTER HISTORY", 131, 103, 20, COLORS.text)
	_draw_label("Recent visible combat outcomes · maximum 100 records", 132, 128, 11, COLORS.muted)
	_draw_panel(Rect2(124, 150, 1188, 520), "SEQUENCE  ·  %d EVENTS" % history.size(), COLORS.line_soft)
	if history.is_empty():
		_draw_label("No combat events have been recorded yet.", 150, 207, 12, COLORS.muted)
	else:
		var page_end := mini(first_index + per_page, history.size())
		for display_index in range(first_index, page_end):
			var event: Dictionary = history[display_index]
			var row_y := 183.0 + float(display_index - first_index) * 22.0
			var accent := COLORS.gold if event.get("type", "") in ["LevelUp", "XPGranted", "KillCredit"] else COLORS.text
			_draw_label("%03d" % int(event.get("sequence", display_index + 1)), 145, row_y, 9, COLORS.muted)
			_draw_label(_fit_text(_format_combat_event(event), 1080, 10), 194, row_y, 10, accent)
	_draw_button(Rect2(145, 686, 125, TOUCH_TARGET), "‹ OLDER", {"type": "combat_history_page", "delta": -1}, combat_history_page > 0, 10)
	_draw_label("PAGE %d / %d" % [combat_history_page + 1, page_count], 720, 720, 10, COLORS.gold, HORIZONTAL_ALIGNMENT_CENTER)
	_draw_button(Rect2(1118, 686, 170, TOUCH_TARGET), "NEWER ›", {"type": "combat_history_page", "delta": 1}, combat_history_page < page_count - 1, 10)

func _draw_abilities(rect: Rect2) -> void:
	_draw_label("CHARACTER  /  ABILITY WEB", 131, 103, 20, COLORS.text)
	_draw_label("%d points  ·  %d known   Drag to pan; tap a node to inspect" % [sim.run.skill_points, sim.run.known.size()], 132, 128, 11, COLORS.gold)
	_draw_button(Rect2(1000, 84, 48, TOUCH_TARGET), "−", {"type": "web_zoom", "factor": 0.82}, false, 17)
	_draw_button(Rect2(1052, 84, 48, TOUCH_TARGET), "+", {"type": "web_zoom", "factor": 1.22}, false, 17)
	_draw_button(Rect2(1106, 84, 94, TOUCH_TARGET), "SELECTED", {"type": "web_center"}, false, 9)
	_draw_button(Rect2(1206, 84, 94, TOUCH_TARGET), "ROOT", {"type": "web_center_root"}, false, 10)
	var graph: Array = sim.get_progression_graph()
	var filters: Array[String] = ["All"]
	for node in graph:
		if not filters.has(node.school):
			filters.append(String(node.school))
	var filter_page_count := maxi(1, int(ceil(float(filters.size()) / 5.0)))
	ability_filter_page = clampi(ability_filter_page, 0, filter_page_count - 1)
	var filter_x := 131.0
	if filter_page_count > 1:
		_draw_button(Rect2(filter_x, 151, 46, 34), "‹", {"type": "web_filter_page", "delta": -1}, false, 16)
		filter_x += 50
	for i in range(ability_filter_page * 5, mini((ability_filter_page + 1) * 5, filters.size())):
		var chip_rect := Rect2(filter_x, 151, 124, 34)
		_draw_button(chip_rect, _fit_text(filters[i].to_upper(), 112, 9), {"type": "web_filter", "school": filters[i]}, ability_filter == filters[i], 9, _school_color(filters[i]))
		filter_x += 128
	if filter_page_count > 1:
		_draw_button(Rect2(filter_x, 151, 46, 34), "›", {"type": "web_filter_page", "delta": 1}, false, 16)
	_draw_panel(Rect2(124, 194, 810, 487), "CONNECTED PATHS  ·  %s" % ability_filter.to_upper(), COLORS.line_soft)
	var graph_rect := _ability_graph_rect()
	var visible_nodes: Array = []
	var node_rects: Dictionary = {}
	for node in graph:
		if ability_filter != "All" and node.school != ability_filter:
			continue
		visible_nodes.append(node)
		var center: Vector2 = graph_rect.get_center() + (node.position - web_pan) * web_zoom
		var diameter := clampf(58.0 * web_zoom, 42.0, 70.0)
		var node_rect := Rect2(center - Vector2.ONE * diameter * 0.5, Vector2.ONE * diameter)
		node_rects[node.id] = node_rect
	for node in visible_nodes:
		var target_rect: Rect2 = node_rects[node.id]
		for parent_id in node.parents:
			if not node_rects.has(parent_id):
				continue
			var source_rect: Rect2 = node_rects[parent_id]
			if graph_rect.has_point(source_rect.get_center()) and graph_rect.has_point(target_rect.get_center()):
				var connected: bool = ui_state.selected_ability_id == String(node.id) or ui_state.selected_ability_id == String(parent_id)
				draw_line(source_rect.get_center(), target_rect.get_center(), COLORS.gold if connected else COLORS.line, 2.0 if connected else 1.0)
	for node in visible_nodes:
		var node_rect: Rect2 = node_rects[node.id]
		if not graph_rect.intersects(node_rect):
			continue
		var selected_node: bool = ui_state.selected_ability_id == node.id
		var fill := Color("#19372d") if node.learned else Color("#193042") if node.learnable else Color("#17212a")
		var accent := COLORS.gold if selected_node else COLORS.green if node.learned else COLORS.cyan if node.learnable else COLORS.line_soft
		var node_center := node_rect.get_center()
		var radius := node_rect.size.x * 0.42
		if node.root:
			draw_circle(node_center, radius + 5, Color(accent.r, accent.g, accent.b, 0.11))
		draw_circle(node_center, radius, fill)
		draw_arc(node_center, radius, 0.0, TAU, 48, accent, 2.5 if selected_node else 1.5)
		_draw_label(_ability_glyph(node.ability), node_center.x, node_center.y + 7, 22, _school_color(node.school), HORIZONTAL_ALIGNMENT_CENTER)
		var label_y := node_rect.end.y + 13
		_draw_label(_fit_text(String(node.ability.name), 104, 8), node_center.x, label_y, 8, COLORS.text, HORIZONTAL_ALIGNMENT_CENTER)
		var state := "KNOWN" if node.learned else "READY" if node.learnable else "LOCKED"
		_draw_label(state, node_center.x, label_y + 11, 7, COLORS.green if node.learned else COLORS.gold if node.learnable else COLORS.muted, HORIZONTAL_ALIGNMENT_CENTER)
		active_hits.append({"rect": _touch_hit_rect(node_rect), "action": {"type": "select_web_node", "id": node.id}})
	_draw_label("Roots radiate into prerequisite branches. Pan or zoom; the graph grows independently of this viewport.", 141, 665, 9, COLORS.muted)
	_draw_panel(Rect2(948, 194, 365, 487), "ABILITY DETAILS", COLORS.line_soft)
	var chosen_id: String = ui_state.selected_ability_id
	if chosen_id == "" or not sim.content.abilities.has(chosen_id):
		for known_id in sim.run.known:
			if sim.content.abilities.has(known_id):
				chosen_id = String(known_id)
				break
	if chosen_id != "" and sim.content.abilities.has(chosen_id):
		ui_state.selected_ability_id = chosen_id
		var ability: Dictionary = sim.content.abilities[chosen_id]
		var status: Dictionary = sim.get_ability_progress(chosen_id)
		_draw_label(String(ability.name), 972, 244, 17, COLORS.text)
		_draw_label("%s  ·  %s" % [ability.school, "PASSIVE" if ability.get("kind", "active") == "passive" else "ACTIVE"], 972, 267, 11, _school_color(ability.school))
		_draw_line(972, 281, 1292, 281, COLORS.line_soft)
		var summary_y := 306.0
		for line in _wrap(String(ability.get("description", "")), 43).slice(0, 3):
			_draw_label(String(line), 972, summary_y, 10, COLORS.muted)
			summary_y += 17
		if ability.get("kind", "active") == "passive":
			var modifier_labels: Array[String] = []
			for modifier_id in ability.get("modifiers", {}):
				modifier_labels.append(_passive_modifier_label(String(modifier_id), float(ability.modifiers[modifier_id])))
			_draw_label("Always active while learned.", 972, summary_y, 10, COLORS.text)
			for line in _wrap(", ".join(modifier_labels), 38):
				summary_y += 17
				_draw_label(line, 972, summary_y, 10, COLORS.cyan)
		else:
			_draw_label("%s  ·  %d time  ·  %s" % [ability.get("target", "enemy").capitalize(), ability.get("time", 0), _cost_text(ability.get("costs", {}))], 972, summary_y, 9, COLORS.text)
			summary_y += 21
			var effect_text: Array[String] = []
			for effect in ability.get("effects", []):
				effect_text.append(_effect_summary(effect))
			for line in _wrap("; ".join(effect_text), 43).slice(0, 3):
				_draw_label(String(line), 972, summary_y, 9, COLORS.muted)
				summary_y += 16
		var parents: Array = ability.get("requires", []).duplicate()
		parents.append_array(ability.get("prerequisites", {}).get("all_of", []))
		parents.append_array(ability.get("prerequisites", {}).get("any_of", []))
		if not parents.is_empty():
			summary_y += 10
			_draw_label("CONNECTED FROM", 972, summary_y, 9, COLORS.gold)
			for parent_id in parents.slice(0, 3):
				summary_y += 16
				_draw_label(String(sim.content.abilities.get(parent_id, {}).get("name", parent_id)), 972, summary_y, 10, COLORS.text)
		summary_y += 15
		_draw_label(_fit_text(String(status.reason), 320, 9), 972, minf(summary_y, 582), 9, COLORS.muted if not status.learnable else COLORS.green)
		if status.learnable:
			_draw_button(Rect2(972, 611, 320, TOUCH_TARGET), "LEARN  ·  SPEND 1 POINT", {"type": "learn", "id": chosen_id}, true, 11, COLORS.green)
		elif status.learned and ability.get("kind", "active") != "passive":
			_draw_button(Rect2(972, 611, 150, TOUCH_TARGET), "USE", {"type": "ability", "id": chosen_id}, false, 11, _school_color(ability.school))
			var ability_assigned := _is_quickbar_assigned("ability", chosen_id)
			_draw_button(Rect2(1128, 611, 164, TOUCH_TARGET), "REMOVE BAR" if ability_assigned else "ADD TO BAR", {"type": "remove_quickbar_assignment" if ability_assigned else "begin_quickbar_assignment", "kind": "ability", "id": chosen_id}, ability_assigned, 10, COLORS.gold)
	_draw_button(Rect2(121, 710, 180, TOUCH_TARGET), "BACK TO BATTLE", {"type": "close"}, false, 12)

func _draw_action_palette(rect: Rect2) -> void:
	_draw_label("ABILITY PALETTE", 131, 103, 20, COLORS.text)
	var abilities: Array = sim.get_available_abilities()
	var filtered: Array = []
	var filters: Array[String] = ["All"]
	for ability_id in abilities:
		var ability: Dictionary = sim.content.abilities[ability_id]
		if not filters.has(String(ability.school)):
			filters.append(String(ability.school))
		if palette_filter == "All" or String(ability.school) == palette_filter:
			filtered.append(String(ability_id))
	_draw_label("Every learned active ability is listed here. Filter, inspect, then choose it for the battlefield.", 132, 128, 10, COLORS.muted)
	var visible_filters := mini(5, filters.size())
	for i in range(visible_filters):
		var filter := filters[i]
		_draw_button(Rect2(131 + i * 126, 151, 122, 34), _fit_text(filter.to_upper(), 112, 9), {"type": "palette_filter", "school": filter}, palette_filter == filter, 9, _school_color(filter))
	var page_count := maxi(1, int(ceil(float(filtered.size()) / 20.0)))
	palette_page = clampi(palette_page, 0, page_count - 1)
	_draw_panel(Rect2(124, 194, 810, 487), "KNOWN ABILITIES  ·  %d" % filtered.size(), COLORS.line_soft)
	for local_index in range(20):
		var index := palette_page * 20 + local_index
		if index >= filtered.size():
			continue
		var ability_id: String = filtered[index]
		var ability: Dictionary = sim.content.abilities[ability_id]
		var node_rect := Rect2(139 + (local_index % 4) * 194, 211 + int(local_index / 4) * 83, 187, 72)
		var selected := selected_ability == ability_id
		var affordable: bool = sim._can_pay(ability.get("costs", {}))
		_draw_panel(node_rect, "", COLORS.gold if selected else _school_color(String(ability.school)) if affordable else COLORS.line_soft)
		_draw_label(_ability_glyph(ability), node_rect.position.x + 25, node_rect.position.y + 34, 20, _school_color(String(ability.school)))
		_draw_label(_fit_text(String(ability.name), 142, 10), node_rect.position.x + 48, node_rect.position.y + 29, 10, COLORS.text)
		_draw_label(_fit_text(_cost_text(ability.get("costs", {})), 142, 8), node_rect.position.x + 48, node_rect.position.y + 50, 8, COLORS.muted if affordable else COLORS.red)
		active_hits.append({"rect": _touch_hit_rect(node_rect), "action": {"type": "select_palette_ability", "id": ability_id}})
	_draw_button(Rect2(140, 632, 100, TOUCH_TARGET), "‹ PAGE", {"type": "palette_page", "delta": -1}, false, 10)
	_draw_label("PAGE %d / %d" % [palette_page + 1, page_count], 355, 660, 11, COLORS.gold, HORIZONTAL_ALIGNMENT_CENTER)
	_draw_button(Rect2(827, 632, 100, TOUCH_TARGET), "PAGE ›", {"type": "palette_page", "delta": 1}, false, 10)
	_draw_panel(Rect2(948, 194, 365, 487), "ABILITY DETAILS", COLORS.line_soft)
	if selected_ability == "" or not sim.content.abilities.has(selected_ability):
		if not filtered.is_empty(): selected_ability = String(filtered[0])
	if selected_ability != "" and sim.content.abilities.has(selected_ability):
		var ability: Dictionary = sim.content.abilities[selected_ability]
		_draw_label(String(ability.name), 972, 244, 17, COLORS.text)
		_draw_label("%s  ·  %s" % [ability.school, _cost_text(ability.get("costs", {}))], 972, 268, 10, _school_color(String(ability.school)))
		var detail_y := 302.0
		for line in _wrap(String(ability.get("description", "")), 43).slice(0, 5):
			_draw_label(String(line), 972, detail_y, 10, COLORS.muted)
			detail_y += 18
		if ability.get("target", "") != "self":
			_draw_label("Target  ·  %s    Range  ·  %d    Action  ·  %d" % [String(ability.get("target", "enemy")).capitalize(), int(ability.get("range", 0)), int(ability.get("time", 0))], 972, maxf(detail_y + 12, 420), 9, COLORS.text)
		_draw_button(Rect2(972, 611, 150, TOUCH_TARGET), "USE", {"type": "palette_cast", "id": selected_ability}, true, 11, _school_color(String(ability.school)))
		var palette_assigned := _is_quickbar_assigned("ability", selected_ability)
		_draw_button(Rect2(1128, 611, 164, TOUCH_TARGET), "REMOVE BAR" if palette_assigned else "ADD TO BAR", {"type": "remove_quickbar_assignment" if palette_assigned else "begin_quickbar_assignment", "kind": "ability", "id": selected_ability}, palette_assigned, 10, COLORS.gold)
	_draw_button(Rect2(121, 710, 180, TOUCH_TARGET), "BACK TO BATTLE", {"type": "close"}, false, 12)

func _draw_rewards(rect: Rect2) -> void:
	var is_map_complete := int(sim.run.get("stage_index", 0)) == 5
	_draw_label("MAP %s COMPLETE" % _format_count_for_ui(sim.run.get("map_depth", "1")) if is_map_complete else "STAGE %d / 6 COMPLETE" % (int(sim.run.get("stage_index", 0)) + 1), 131, 105, 23, COLORS.text)
	var resolved: bool = sim.run.get("reward_choice_resolved", false)
	_draw_label("One choice is kept for this encounter. This decision persists with your run.", 132, 131, 12, COLORS.muted)
	_draw_panel(Rect2(127, 164, 1185, 411), "CHOOSE ONE REWARD", COLORS.line_soft)
	for i in range(sim.run.reward_choices.size()):
		var reward: Dictionary = sim.run.reward_choices[i]
		var entry: Dictionary = sim.content.artifacts[reward.id] if reward.type == "artifact" else sim.content.items[reward.id]
		var card := Rect2(153 + i * 376, 213, 350, 292)
		var chosen := int(sim.run.get("reward_chosen_index", -1)) == i
		var available := not resolved and bool(reward.get("available", true))
		_draw_panel(card, "", COLORS.gold if chosen else COLORS.line if available else COLORS.line_soft)
		if resolved and not chosen:
			draw_rect(card, Color(0.02, 0.03, 0.04, 0.35), true)
		var rarity: String = String(entry.get("rarity", "FIELD GEAR"))
		_draw_label(String(rarity).to_upper(), card.position.x + 19, card.position.y + 31, 10, COLORS.purple if reward.type == "artifact" or entry.get("type") == "spellbook" else COLORS.gold)
		_draw_label(String(entry.name), card.position.x + 19, card.position.y + 67, 19, COLORS.text)
		var description := String(entry.get("description", "A useful object for the road ahead."))
		var lines := _wrap(description, 34)
		for line_index in range(mini(4, lines.size())):
			_draw_label(lines[line_index], card.position.x + 19, card.position.y + 105 + line_index * 21, 13, COLORS.muted)
		if reward.type == "artifact":
			_draw_label("PERSISTENT RUN MODIFIER", card.position.x + 19, card.position.y + 206, 10, COLORS.cyan)
		elif entry.get("type") == "spellbook":
			_draw_label("CONTENTS VISIBLE BEFORE STUDY", card.position.x + 19, card.position.y + 206, 10, COLORS.purple)
		else:
			_draw_label(String(entry.get("type", "item")).to_upper(), card.position.x + 19, card.position.y + 206, 10, COLORS.cyan)
		var choice_label := "CHOSEN" if chosen else "CHOICE CLOSED" if resolved else "CLAIM REWARD"
		if available:
			_draw_button(Rect2(card.position.x + 19, card.position.y + 221, card.size.x - 38, TOUCH_TARGET), choice_label, {"type": "claim_reward", "index": i}, true, 12, COLORS.gold)
		else:
			_draw_label(choice_label, card.get_center().x, card.position.y + 254, 11, COLORS.gold if chosen else COLORS.muted, HORIZONTAL_ALIGNMENT_CENTER)
	_draw_label("MAP %s  ·  %s XP  ·  %s ENEMIES DEFEATED  ·  %s STAGES COMPLETED" % [_format_count_for_ui(sim.run.get("map_depth", "1")), _format_count_for_ui(sim.run.get("xp", 0)), _format_count_for_ui(sim.run.get("enemies_defeated", sim.run.kills)), _format_count_for_ui(sim.run.get("stages_completed", sim.run.encounters_completed))], 155, 616, 13, COLORS.gold)
	_draw_button(Rect2(128, 640, 205, TOUCH_TARGET), "KEEP EXPLORING", {"type": "close"}, false, 12)
	var action_label := "REVEAL NEXT MAP  →" if is_map_complete else "CONTINUE TO STAGE %d  →" % (int(sim.run.get("stage_index", 0)) + 2)
	_draw_button(Rect2(1026, 640, 286, TOUCH_TARGET), action_label, {"type": "next_stage"}, true, 12)

func _draw_map_reveal(rect: Rect2) -> void:
	var next_map: Dictionary = sim.run.get("next_map", {})
	if next_map.is_empty():
		_draw_label("THE PATH AHEAD", 131, 105, 23, COLORS.text)
		_draw_label("The next map could not be found in the saved journey.", 132, 139, 13, COLORS.muted)
		_draw_button(Rect2(128, 640, 250, TOUCH_TARGET), "RETURN TO REWARDS", {"type": "close"}, false, 12)
		return
	_draw_label("THE NEXT MAP IS REVEALED", 131, 105, 23, COLORS.gold)
	_draw_label("Your expedition continues. The next region is now known.", 132, 133, 12, COLORS.muted)
	_draw_panel(Rect2(300, 190, 840, 340), "MAP %s" % _format_count_for_ui(next_map.get("map_number", "1")), COLORS.green)
	draw_circle(Vector2(720, 326), 64.0, Color("#122a30"))
	draw_arc(Vector2(720, 326), 64.0, 0.0, TAU, 48, COLORS.green, 3.0)
	_draw_label("◇", 720, 336, 38, COLORS.green, HORIZONTAL_ALIGNMENT_CENTER)
	_draw_label(_fit_text(String(next_map.get("name", "Unknown Region")), 720, 27), 720, 431, 27, COLORS.text, HORIZONTAL_ALIGNMENT_CENTER)
	var subtitle_lines := _wrap_text_to_width(String(next_map.get("subtitle", "")), 700, 13, 2)
	for index in range(subtitle_lines.size()):
		_draw_label(String(subtitle_lines[index]), 720, 461.0 + float(index) * 18.0, 13, COLORS.muted, HORIZONTAL_ALIGNMENT_CENTER)
	_draw_label("Health and resources are unchanged. The next stage begins when you are ready.", 720, 574, 12, COLORS.cyan, HORIZONTAL_ALIGNMENT_CENTER)
	_draw_button(Rect2(510, 620, 420, 52), "ENTER MAP %s  →" % _format_count_for_ui(next_map.get("map_number", "1")), {"type": "enter_next_map"}, true, 14, COLORS.green)

func _draw_new_run_confirmation(_rect: Rect2) -> void:
	_draw_label("AN EXPEDITION IS ALREADY UNDER WAY", 186, 177, 22, COLORS.text)
	_draw_label("Starting over will replace its saved run. You can resume it or discard it here.", 187, 210, 13, COLORS.muted)
	_draw_panel(Rect2(220, 260, 1000, 250), "ACTIVE RUN", COLORS.gold)
	_draw_label("Resume the current hero and map journey, or replace that run with a new character.", 254, 337, 16, COLORS.text)
	_draw_button(Rect2(272, 418, 360, 64), "RESUME ACTIVE RUN", {"type": "resume"}, true, 14)
	_draw_button(Rect2(656, 418, 440, 64), "DISCARD AND BEGIN NEW RUN", {"type": "replace_active_run"}, false, 13, COLORS.red)
	_draw_button(Rect2(272, 530, 180, TOUCH_TARGET), "CANCEL", {"type": "close"}, false, 12)

func _draw_run_summary_list(title: String, values: Array, x: float, y: float, width: float, color: Color) -> void:
	_draw_label(title, x, y, 10, COLORS.gold)
	if values.is_empty():
		_draw_label("None", x, y + 23.0, 11, COLORS.muted)
		return
	for index in range(values.size()):
		_draw_label(_fit_text("• " + String(values[index]), width, 10), x, y + 22.0 + float(index) * 18.0, 10, color)

func _draw_destination_picker(_rect: Rect2) -> void:
	_draw_label("CHOOSE NEXT DESTINATION", 131, 105, 23, COLORS.text)
	_draw_label("Only connected routes recorded for this run are shown.", 132, 132, 12, COLORS.muted)
	var choices: Array = []
	var boss_ready := int(sim.run.get("stage_index", 0)) >= ArcanistSim.STAGE_ORDER.size() - 1
	if boss_ready:
		choices.append("grave_tyrant")
	else:
		choices.assign(sim.run.get("route_choices", []))
	_draw_panel(Rect2(127, 164, 1185, 440), "CONNECTED DESTINATIONS  ·  %d" % choices.size(), COLORS.line_soft)
	if choices.is_empty():
		_draw_label("No connected destination is available from this encounter.", 160, 224, 14, COLORS.muted)
	else:
		var gap := 18.0
		var card_width := (1115.0 - gap * float(choices.size() - 1)) / float(choices.size())
		for index in range(choices.size()):
			var stage_id := String(choices[index])
			var stage: Dictionary = sim.content.enemies.get(stage_id, {}) if stage_id == "grave_tyrant" else sim.content.stages.get(stage_id, {})
			var card := Rect2(157.0 + float(index) * (card_width + gap), 216.0, card_width, 300.0)
			var accent: Color = COLORS.red if stage_id == "grave_tyrant" else COLORS.green
			_draw_panel(card, "BOSS" if stage_id == "grave_tyrant" else "COMBAT", accent)
			_draw_label("☠" if stage_id == "grave_tyrant" else "◇", card.get_center().x, card.position.y + 67.0, 34, accent, HORIZONTAL_ALIGNMENT_CENTER)
			_draw_label(_fit_text(String(stage.get("name", "Grave Tyrant" if stage_id == "grave_tyrant" else stage_id)), card.size.x - 30.0, 15), card.get_center().x, card.position.y + 113.0, 15, COLORS.text, HORIZONTAL_ALIGNMENT_CENTER)
			var subtitle := String(stage.get("subtitle", stage.get("description", "The final threat waits ahead.")))
			var subtitle_lines: Array = _wrap(subtitle, maxi(18, int(card.size.x / 8.0)))
			for line_index in range(mini(4, subtitle_lines.size())):
				_draw_label(String(subtitle_lines[line_index]), card.get_center().x, card.position.y + 150.0 + float(line_index) * 18.0, 10, COLORS.muted, HORIZONTAL_ALIGNMENT_CENTER)
			_draw_button(Rect2(card.position.x + 18.0, card.end.y - 58.0, card.size.x - 36.0, 42.0), "ENTER DESTINATION", {"type": "destination_route", "id": stage_id}, true, 10, accent)
	_draw_label("The persistent World Map remains an overview; travel happens here after the objective.", 155, 635, 11, COLORS.gold)
	_draw_button(Rect2(128, 640, 205, TOUCH_TARGET), "KEEP EXPLORING", {"type": "close"}, false, 12)

func _draw_codex(rect: Rect2) -> void:
	_draw_label("FIELD CODEX", 131, 103, 21, COLORS.text)
	_draw_label("Persistent discoveries · knowledge does not carry into a new run", 132, 128, 13, COLORS.muted)
	var categories: Array = [["CREATURES", "creatures"], ["ABILITIES", "abilities"], ["SPELLBOOKS", "spellbooks"], ["ARTIFACTS", "artifacts"], ["SCHOOLS", "schools"]]
	for i in range(categories.size()):
		var category: Array = categories[i]
		var x := 132 + (i % 3) * 390
		var y := 169 + int(i / 3) * 241
		var w := 365.0 if i < 3 else 560.0
		_draw_panel(Rect2(x, y, w, 210), String(category[0]), COLORS.line_soft)
		var values: Array = sim.codex.get(category[1], [])
		if values.is_empty():
			_draw_label("No discoveries yet", x + 18, y + 68, 13, COLORS.muted)
		else:
			var row_limit := 3 if category[1] == "spellbooks" else 7
			for j in range(mini(row_limit, values.size())):
				var value_id := String(values[j])
				var value_name := _content_display_name(value_id)
				if category[1] == "spellbooks":
					var row_rect := Rect2(x + 12, y + 46 + j * 56, w - 24, 50)
					_draw_panel(row_rect, "", COLORS.purple)
					_draw_label("▣  " + _fit_text(value_name, row_rect.size.x - 26, 10), row_rect.position.x + 9, row_rect.position.y + 19, 10, COLORS.text)
					var book: Dictionary = sim.content.items.get(value_id, {})
					_draw_label("%s  ·  %s" % [book.get("school", "Knowledge"), book.get("rarity", "Common")], row_rect.position.x + 27, row_rect.position.y + 36, 8, COLORS.muted)
					active_hits.append({"rect": _touch_hit_rect(row_rect), "action": {"type": "codex_book", "id": value_id}})
				else:
					_draw_label("✦  %s" % value_name, x + 18, y + 66 + j * 19, 12, COLORS.text)
	_draw_button(Rect2(128, 651, 180, TOUCH_TARGET), "BACK TO BATTLE" if page == "battle" else "RETURN", {"type": "close"}, false, 12)

func _draw_spellbook_codex(rect: Rect2) -> void:
	var book: Dictionary = sim.content.items.get(codex_book_id, {})
	if book.is_empty():
		_draw_label("SPELLBOOK RECORD", 131, 103, 20, COLORS.text)
		_draw_label("This discovery is not in the Codex.", 145, 170, 14, COLORS.muted)
		_draw_button(Rect2(128, 651, 180, TOUCH_TARGET), "BACK TO CODEX", {"type": "close"}, false, 12)
		return
	_draw_label(String(book.get("name", "Spellbook")), 131, 105, 23, COLORS.text)
	_draw_label("%s  ·  %s SPELLBOOK" % [String(book.get("school", "Knowledge")).to_upper(), String(book.get("rarity", "COMMON")).to_upper()], 132, 132, 12, COLORS.purple)
	_draw_panel(Rect2(128, 158, 1185, 456), "RECORDED IMMEDIATE KNOWLEDGE", COLORS.line_soft)
	_draw_label("DESCRIPTION", 158, 204, 10, COLORS.gold)
	var desc_y := 229.0
	for line in _wrap(String(book.get("description", "A recorded work of recovered knowledge.")), 96).slice(0, 3):
		_draw_label(String(line), 158, desc_y, 12, COLORS.text)
		desc_y += 21
	var learning: Dictionary = book.get("learning", {})
	var offered: Array = learning.get("abilities", book.get("learns", []))
	var learn_mode := String(learning.get("mode", "all"))
	_draw_label("IMMEDIATE STUDY" if learn_mode != "choose" else "IMMEDIATE CHOICES", 158, 307, 10, COLORS.gold)
	var contents: Array = []
	if learn_mode == "school_only":
		contents.append("Unlocks %s knowledge" % String(book.get("school", "")))
	else:
		for ability_id in offered:
			contents.append(String(sim.content.abilities.get(ability_id, {}).get("name", ability_id)))
	var left_x := 158.0
	for i in range(contents.size()):
		var column := int(i / 8)
		var row := i % 8
		if column > 1: break
		_draw_label("%02d  ·  %s" % [i + 1, String(contents[i])], left_x + column * 350, 335 + row * 25, 11, COLORS.text)
	_draw_label("LEARNING", 980, 204, 10, COLORS.gold)
	var learn_count := int(book.get("learning", {}).get("choice_count", offered.size()))
	var resolution: Dictionary = sim.run.get("spellbook_resolutions", {}).get(codex_book_id, {})
	_draw_label("%s  ·  %d offered" % ["Choose %d" % learn_count if learn_mode == "choose" else "Study all" if learn_mode == "all" else "School unlock", offered.size()], 980, 229, 10, COLORS.purple)
	if resolution.is_empty():
		_draw_label("Not yet studied in this run.", 980, 252, 10, COLORS.muted)
	else:
		_draw_label("Learned this run", 980, 252, 10, COLORS.green)
	var option_y := 285.0
	for ability_id in offered.slice(0, 7):
		var ability: Dictionary = sim.content.abilities.get(ability_id, {})
		_draw_label("✦  %s" % String(ability.get("name", ability_id)), 980, option_y, 11, COLORS.text)
		option_y += 21
		for line in _wrap(String(ability.get("description", "")), 45).slice(0, 2):
			_draw_label(String(line), 1000, option_y, 9, COLORS.muted)
			option_y += 15
	var chosen_names: Array[String] = []
	for ability_id in resolution.get("abilities", []):
		chosen_names.append(String(sim.content.abilities.get(ability_id, {}).get("name", ability_id)))
	if not chosen_names.is_empty():
		_draw_label("Chosen  ·  %s" % ", ".join(chosen_names), 158, 578, 10, COLORS.green)
	_draw_button(Rect2(128, 651, 180, TOUCH_TARGET), "BACK TO CODEX", {"type": "close"}, false, 12)

func _draw_inspect(rect: Rect2) -> void:
	var enemy: Dictionary = sim.run.entities.get(selected_enemy, {})
	var presentation: Dictionary = sim.get_entity_presentation(selected_enemy)
	_draw_label("CREATURE RECORD", 131, 103, 20, COLORS.text)
	if enemy.is_empty():
		_draw_label("No creature is selected.", 145, 180, 15, COLORS.muted)
	else:
		_draw_label(String(presentation.get("symbol", "?")), 160, 196, 30, _entity_presentation_color(String(presentation.get("color_key", "neutral"))))
		_draw_label(String(presentation.get("name", "Creature")), 195, 180, 23, COLORS.text)
		_draw_label("Faction  ·  %s" % enemy.get("faction", "Unknown"), 147, 218, 15, COLORS.text)
		_draw_label("Health  ·  %d / %d" % [enemy.hp, enemy.max_hp], 147, 251, 15, COLORS.text)
		_draw_label("Behavior  ·  %s" % String(enemy.get("behavior", enemy.get("summon_behavior", "summon"))).capitalize(), 147, 284, 15, COLORS.text)
		_draw_label("Attack  ·  %d %s   /   Reach %d" % [enemy.damage, enemy.damage_type, enemy.range], 147, 317, 15, COLORS.text)
		_draw_label("Footprint  ·  %d × %d" % [enemy.footprint, enemy.footprint], 147, 350, 15, COLORS.text)
		var resistances: Array = []
		for damage_type in enemy.get("resist", {}):
			resistances.append("%s %d%%" % [damage_type, int(enemy.resist[damage_type] * 100)])
		_draw_label("Resistance  ·  %s" % (", ".join(resistances) if not resistances.is_empty() else "None known"), 147, 383, 15, COLORS.cyan)
		_draw_label("Effects  ·  %s" % (", ".join(enemy.get("statuses", {}).keys()) if not enemy.get("statuses", {}).is_empty() else "None"), 147, 416, 15, COLORS.orange)
	_draw_button(Rect2(128, 651, 180, TOUCH_TARGET), "RETURN", {"type": "close"}, false, 12)

func _draw_pause(rect: Rect2) -> void:
	if overlay == "exit_confirm":
		_draw_label("LEAVE THE MARCH?", 131, 104, 24, COLORS.text)
		_draw_label("Your current run is saved. You can resume from the title screen.", 132, 133, 14, COLORS.muted)
		_draw_button(Rect2(160, 205, 330, 70), "RETURN TO PAUSE MENU", {"type": "pause_menu"}, true, 15)
		_draw_button(Rect2(160, 296, 330, 70), "EXIT PROJECT ARCANIST", {"type": "quit_app"}, false, 14, COLORS.red)
		return
	_draw_label("PAUSED", 131, 104, 24, COLORS.text)
	_draw_label("The battlefield is waiting. Nothing advances until you choose an action.", 132, 133, 14, COLORS.muted)
	_draw_button(Rect2(160, 205, 330, 70), "RETURN TO BATTLE", {"type": "close"}, true, 16)
	_draw_button(Rect2(160, 296, 330, 70), "SAVE RUN", {"type": "save"}, false, 15)
	_draw_button(Rect2(160, 387, 330, 70), "RETURN TO TITLE", {"type": "title"}, false, 15)
	_draw_label("Run state is saved after every committed action.", 160, 498, 13, COLORS.muted)

func _draw_outcome() -> void:
	_draw_label("THE MARCH CLAIMS YOU", 190, 107, 32, COLORS.red)
	_draw_label("Your expedition ends here. What you learned remains yours.", 192, 139, 15, COLORS.muted)
	var summary: Dictionary = sim.get_summary()
	_draw_panel(Rect2(128, 172, 1184, 468), "RUN SUMMARY", COLORS.line)
	_draw_label(String(summary.character), 158, 225, 22, COLORS.text)
	_draw_label("LEVEL %d  ·  %s MAPS COMPLETED  ·  DEEPEST: MAP %s, STAGE %d / 6" % [int(summary.level), _format_count_for_ui(summary.maps_completed), _format_count_for_ui(summary.deepest_map), int(summary.stage_reached)], 158, 253, 12, COLORS.cyan)
	var stats := [
		"MAPS COMPLETED  %s" % _format_count_for_ui(summary.maps_completed),
		"DEEPEST MAP  %s  ·  STAGE %d / 6" % [_format_count_for_ui(summary.deepest_map), int(summary.stage_reached)],
		"STAGES CLEARED  %s" % _format_count_for_ui(summary.stages_completed),
		"ENEMIES DEFEATED  %s" % _format_count_for_ui(summary.enemies_defeated),
		"BOSSES DEFEATED  %s" % _format_count_for_ui(summary.bosses_defeated),
		"LEVEL  %d  ·  XP  %d" % [int(summary.level), int(summary.xp)]
	]
	for index in range(stats.size()):
		var column := index % 3
		var row := int(index / 3)
		var stat_rect := Rect2(157.0 + float(column) * 368.0, 279.0 + float(row) * 38.0, 350.0, 32.0)
		_draw_panel(stat_rect, "", COLORS.line_soft)
		_draw_label(_fit_text(String(stats[index]), stat_rect.size.x - 16.0, 10), stat_rect.position.x + 10.0, stat_rect.position.y + 20.0, 10, COLORS.gold)
	_draw_panel(Rect2(157, 367, 1097, 218), "FINAL BUILD AND EQUIPMENT", COLORS.line_soft)
	var build_entries: Array[String] = []
	for value in summary.get("abilities", []): build_entries.append("Ability  ·  " + String(value))
	for value in summary.get("equipment", []): build_entries.append("Gear  ·  " + String(value))
	for value in summary.get("relics", []): build_entries.append("Relic  ·  " + String(value))
	for value in summary.get("artifacts", []): build_entries.append("Artifact  ·  " + String(value))
	var page_size := 12
	var page_count := maxi(1, int(ceil(float(build_entries.size()) / float(page_size))))
	run_summary_page = clampi(run_summary_page, 0, page_count - 1)
	if build_entries.is_empty():
		_draw_label("No learned abilities, equipment or run relics.", 178, 425, 11, COLORS.muted)
	else:
		var first := run_summary_page * page_size
		var last := mini(first + page_size, build_entries.size())
		for index in range(first, last):
			var local_index := index - first
			var column := local_index % 2
			var row := int(local_index / 2)
			_draw_label(_fit_text(build_entries[index], 510, 10), 178.0 + float(column) * 525.0, 425.0 + float(row) * 22.0, 10, COLORS.text)
	if page_count > 1:
		_draw_button(Rect2(177, 553, 104, 32), "‹ PREV", {"type": "run_summary_page", "delta": -1}, false, 9)
		_draw_label("BUILD %d / %d" % [run_summary_page + 1, page_count], 705, 575, 9, COLORS.gold, HORIZONTAL_ALIGNMENT_CENTER)
		_draw_button(Rect2(1128, 553, 104, 32), "NEXT ›", {"type": "run_summary_page", "delta": 1}, false, 9)
	_draw_button(Rect2(414, 684, 280, 56), "CHOOSE A NEW WANDERER", {"type": "title"}, true, 13)
	_draw_button(Rect2(722, 684, 280, 56), "FIELD CODEX", {"type": "title_codex"}, false, 13)

func _draw_toast(text: String) -> void:
	var width := minf(750, maxf(300, text.length() * 9.0))
	var rect := Rect2((1440 - width) * 0.5, 602, width, 34)
	draw_rect(rect, Color("#172936"))
	draw_rect(rect, COLORS.line, false, 1.0)
	_draw_label(text, 720, 625, 13, COLORS.text, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_panel(rect: Rect2, title: String, border: Color) -> float:
	draw_rect(rect, COLORS.panel)
	draw_rect(rect, border, false, 1.4)
	if title != "":
		var title_baseline := rect.position.y + 25.0
		var title_font_size := _physical_font_size(11)
		var descent := ThemeDB.fallback_font.get_descent(title_font_size) / maxf(0.1, draw_scale)
		var rule_y := maxf(rect.position.y + 40.0, title_baseline + descent + 7.0)
		_draw_label(title, rect.position.x + 14, title_baseline, 11, COLORS.gold)
		draw_line(Vector2(rect.position.x + 12, rule_y), Vector2(rect.end.x - 12, rule_y), COLORS.line_soft, 1.0)
		return rule_y + 11.0
	return rect.position.y + 8.0

func _draw_corner_marks(rect: Rect2) -> void:
	var length := 13.0
	var color := COLORS.cyan
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), rect.end]:
		var sx := 1.0 if corner.x == rect.position.x else -1.0
		var sy := 1.0 if corner.y == rect.position.y else -1.0
		draw_line(corner, corner + Vector2(sx * length, 0), color, 2)
		draw_line(corner, corner + Vector2(0, sy * length), color, 2)

func _draw_bar(rect: Rect2, label: String, current: int, maximum: int, color: Color) -> void:
	draw_rect(rect, Color("#101b25"))
	var ratio := clampf(float(current) / maxf(1.0, float(maximum)), 0.0, 1.0)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y)), color)
	draw_rect(rect, COLORS.line_soft, false, 1)
	_draw_label(label, rect.position.x + 5, rect.position.y + 15, 10, COLORS.text)
	var value_text := "%d / %d occupied" % [current, maximum] if label == "CMD" else "%d / %d" % [current, maximum]
	_draw_label(value_text, rect.end.x - 4, rect.position.y + 15, 9 if label == "CMD" else 10, COLORS.text, HORIZONTAL_ALIGNMENT_RIGHT)

func _draw_button(rect: Rect2, label: String, action: Dictionary, active: bool = false, font_size: int = 13, accent: Color = COLORS.cyan) -> void:
	var fill := Color("#173328") if active else COLORS.panel_2
	var outline := COLORS.green if active and accent == COLORS.cyan else accent if active else COLORS.line
	draw_rect(rect, fill)
	draw_rect(rect, outline, false, 1.5)
	var lines := label.split("\n")
	if lines.size() == 1:
		_draw_label(label, rect.get_center().x, rect.get_center().y + font_size * 0.35, font_size, COLORS.text, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		_draw_label(lines[0], rect.get_center().x, rect.get_center().y - 1, font_size, COLORS.text, HORIZONTAL_ALIGNMENT_CENTER)
		_draw_label(lines[1], rect.get_center().x, rect.get_center().y + 21, maxi(9, font_size - 1), COLORS.muted, HORIZONTAL_ALIGNMENT_CENTER)
	active_hits.append({"rect": _panel_hit_rect(rect), "action": action})

func _touch_hit_rect(rect: Rect2) -> Rect2:
	var target_size := Vector2(maxf(rect.size.x, TOUCH_TARGET), maxf(rect.size.y, TOUCH_TARGET))
	return Rect2(rect.get_center() - target_size * 0.5, target_size)

func _panel_hit_rect(rect: Rect2) -> Rect2:
	var target := _touch_hit_rect(rect) if _is_mobile_layout() else rect
	if active_hit_clip_rect.size.x > 0.0 and active_hit_clip_rect.size.y > 0.0:
		return target.intersection(active_hit_clip_rect)
	return target

func _draw_dpad_button(rect: Rect2, glyph: String, direction: Vector2i) -> void:
	draw_rect(rect, COLORS.panel_2)
	draw_rect(rect, COLORS.line, false, 1)
	_draw_label(glyph, rect.get_center().x, rect.get_center().y + 5, 14, COLORS.text, HORIZONTAL_ALIGNMENT_CENTER)
	active_hits.append({"rect": _touch_hit_rect(rect), "action": {"type": "dpad", "direction": [direction.x, direction.y]}})

func _draw_hover_tooltip() -> void:
	if capture_requested and capture_scenario in ["ability_tooltip", "tooltip_long"]:
		var tooltip_ability_id := "demonic_gateway" if capture_scenario == "tooltip_long" else "fireball"
		for hit in active_hits:
			if String(hit.action.get("type", "")) == "select_lower_ability" and String(hit.action.get("id", "")) == tooltip_ability_id:
				hover_position = hit.rect.get_center()
				break
	if _is_mobile_layout() or hover_position.x < 0.0:
		return
	var source: Dictionary = {}
	for index in range(active_hits.size() - 1, -1, -1):
		var candidate: Dictionary = active_hits[index]
		if candidate.rect.has_point(hover_position):
			source = candidate
			break
	if source.is_empty():
		return
	var lines: Array[String] = _tooltip_lines_for_action(source.action)
	if lines.is_empty():
		return
	var tooltip_layout := _tooltip_layout(lines)
	var width := float(tooltip_layout.width)
	var height := float(tooltip_layout.height)
	var point := _tooltip_position(hover_position, Vector2(width, height))
	var rect := Rect2(point, Vector2(width, height))
	draw_rect(rect, Color("#08121b"))
	draw_rect(rect, COLORS.cyan, false, 1.0)
	var wrapped_lines: Array[String] = tooltip_layout.lines
	var line_height := float(tooltip_layout.line_height)
	for i in range(wrapped_lines.size()):
		_draw_label(wrapped_lines[i], point.x + 10.0, point.y + 8.0 + line_height * float(i + 1), 8, COLORS.text if i == 0 else COLORS.muted)

func _tooltip_layout(lines: Array[String]) -> Dictionary:
	var width := minf(300.0, screen_size.x - 16.0)
	var text_width := maxf(80.0, width - 24.0)
	var wrapped_lines: Array[String] = []
	for line in lines:
		var wrapped := _wrap_text_to_width(line, text_width, 8)
		if wrapped.is_empty():
			wrapped_lines.append("")
		else:
			wrapped_lines.append_array(wrapped)
	var line_height := _text_line_height(8) + 3.0
	var height := 16.0 + float(wrapped_lines.size()) * line_height
	return {"width": width, "height": height, "text_width": text_width, "line_height": line_height, "lines": wrapped_lines}

func _tooltip_position(anchor: Vector2, size: Vector2) -> Vector2:
	var point := anchor + Vector2(14.0, 16.0)
	if point.x + size.x > screen_size.x - 8.0:
		point.x = anchor.x - size.x - 14.0
	if point.y + size.y > screen_size.y - 8.0:
		point.y = anchor.y - size.y - 14.0
	return Vector2(clampf(point.x, 8.0, maxf(8.0, screen_size.x - size.x - 8.0)), clampf(point.y, 8.0, maxf(8.0, screen_size.y - size.y - 8.0)))

func _tooltip_lines_for_action(action: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var kind := String(action.get("type", ""))
	if kind == "select_lower_ability":
		var ability_id := String(action.get("id", ""))
		var ability: Dictionary = sim.content.abilities.get(ability_id, {})
		if ability.is_empty(): return result
		result.append(String(ability.get("name", ability_id)))
		result.append("%s  ·  %d time  ·  %s" % [String(ability.get("school", "Ability")), int(ability.get("time", 0)), _cost_text(ability.get("costs", {}))])
		result.append(String(ability.get("description", "")))
		var requirements: Array = ability.get("requires", []).duplicate()
		requirements.append_array(ability.get("prerequisites", {}).get("all_of", []))
		if not requirements.is_empty():
			var names: Array[String] = []
			for required_id in requirements:
				names.append(String(sim.content.abilities.get(required_id, {}).get("name", required_id)))
			result.append("Requires  ·  %s" % ", ".join(names))
	elif kind == "select_item":
		var items: Array = sim.run.get("inventory", [])
		var index := int(action.get("index", -1))
		if index < 0 or index >= items.size(): return result
		var item_id := String(items[index])
		var item: Dictionary = sim.content.items.get(item_id, {})
		if item.is_empty(): return result
		result.append(String(item.get("name", item_id)))
		result.append(String(item.get("type", "item")).capitalize())
		result.append(String(item.get("description", "")))
		if item.get("type", "") == "equipment":
			result.append("Slot  ·  %s" % String(item.get("slot", "")))
			var stats: Dictionary = sim.get_equipment_item_stats(item_id)
			if stats.has("damage"):
				result.append("Damage  ·  %d %s" % [int(stats.damage), String(stats.damage_type)])
				result.append("Time %d  ·  Range %d  ·  Stamina %d" % [int(stats.time), int(stats.range), int(stats.stamina)])
			if int(stats.get("armor", 0)) > 0:
				result.append("Armor  ·  %d" % int(stats.armor))
			for resistance in stats.get("resist", {}):
				result.append("Resist  ·  %s %d%%" % [String(resistance), int(stats.resist[resistance] * 100.0)])
			for modifier in stats.get("modifiers", {}):
				result.append("%s  ·  %+d" % [String(modifier).replace("_", " ").capitalize(), int(stats.modifiers[modifier])])
	elif kind == "select_artifact":
		var artifacts: Array = sim.run.get("artifacts", [])
		var index := int(action.get("index", -1))
		if index < 0 or index >= artifacts.size(): return result
		var artifact_id := String(artifacts[index])
		var artifact: Dictionary = sim.content.artifacts.get(artifact_id, {})
		if artifact.is_empty(): return result
		result.append(String(artifact.get("name", artifact_id)))
		result.append(String(artifact.get("description", "Persistent run modifier")))
	elif kind == "select_equipment_slot":
		var slot := String(action.get("slot", ""))
		var item_id := String(sim.run.get("equipment", {}).get(slot, ""))
		var item: Dictionary = sim.content.items.get(item_id, {})
		result.append(slot)
		result.append(String(item.get("name", "Empty")))
		if not item.is_empty():
			result.append(String(item.get("description", "")))
			var stats: Dictionary = sim.get_equipment_item_stats(item_id)
			if stats.has("damage"):
				result.append("Damage  ·  %d %s" % [int(stats.damage), String(stats.damage_type)])
				result.append("Time %d  ·  Range %d  ·  Stamina %d" % [int(stats.time), int(stats.range), int(stats.stamina)])
			if int(stats.get("armor", 0)) > 0:
				result.append("Armor  ·  %d" % int(stats.armor))
	elif kind == "select_lower_book":
		var book_id := String(action.get("id", ""))
		var book: Dictionary = sim.content.items.get(book_id, {})
		if book.is_empty(): return result
		result.append(String(book.get("name", book_id)))
		result.append("%s  ·  %s" % [String(book.get("school", "Knowledge")), String(book.get("rarity", "Common"))])
		result.append(String(book.get("description", "")))
	return result

static func _calculate_layout(viewport_size: Vector2, safe_area: Rect2) -> Dictionary:
	var bounds := Rect2(Vector2.ZERO, viewport_size)
	var safe := safe_area.intersection(bounds)
	if safe.size.x <= 0.0 or safe.size.y <= 0.0:
		safe = bounds
	safe = safe.grow_individual(-8.0, -8.0, -8.0, -8.0)
	if safe.size.x <= 0.0 or safe.size.y <= 0.0:
		safe = bounds
	var scale_factor := minf(safe.size.x / LOGICAL_SIZE.x, safe.size.y / LOGICAL_SIZE.y)
	if scale_factor <= 0.0:
		return {"size": LOGICAL_SIZE, "scale": 1.0, "offset": Vector2.ZERO}
	return {
		"size": safe.size / scale_factor,
		"scale": scale_factor,
		"offset": safe.position
	}

func _safe_area_for_viewport(viewport_size: Vector2) -> Rect2:
	var bounds := Rect2(Vector2.ZERO, viewport_size)
	if OS.get_name() != "Android":
		return bounds
	var physical_size := Vector2(DisplayServer.screen_get_size())
	var physical_safe := DisplayServer.get_display_safe_area()
	if physical_size.x <= 0.0 or physical_size.y <= 0.0 or physical_safe.size.x <= 0 or physical_safe.size.y <= 0:
		return bounds
	var scale_to_viewport := viewport_size / physical_size
	var mapped_safe := Rect2(Vector2(physical_safe.position) * scale_to_viewport, Vector2(physical_safe.size) * scale_to_viewport)
	return mapped_safe.intersection(bounds)

func _is_wide_layout() -> bool:
	return screen_size.x >= WIDE_LAYOUT_MIN_WIDTH

func _is_mobile_layout() -> bool:
	return mobile_layout_override or OS.get_name() == "Android"

func _board_origin() -> Vector2:
	return _battle_layout().board_rect.position

func _tile_size() -> float:
	return float(_battle_layout().tile)

func _board_rect() -> Rect2:
	return _battle_layout().board_rect

func _open_lower_panel(panel_id: String, toggle: bool = true) -> void:
	if target_mode != "": _cancel_targeting()
	overlay = ""
	if not _is_mobile_layout():
		ui_state.active_lower_panel = panel_id
		ui_state.lower_dock_expanded = false
		if panel_id == "character" and String(ui_state.selected_ability_id) == "" and not sim.run.get("known", []).is_empty():
			ui_state.selected_ability_id = String(sim.run.known[0])
		if panel_id == "spellbook" and String(ui_state.selected_spellbook_id) == "":
			for book_id in sim.run.get("inventory", []):
				if sim.content.items.get(book_id, {}).get("type", "") == "spellbook":
					ui_state.selected_spellbook_id = String(book_id)
					ui_state.selected_inventory_index = int(sim.run.inventory.find(book_id))
					break
		queue_redraw()
		return
	if toggle and ui_state.lower_dock_expanded and String(ui_state.active_lower_panel) == panel_id:
		ui_state.lower_dock_expanded = false
	else:
		ui_state.active_lower_panel = panel_id
		ui_state.lower_dock_expanded = true
		if panel_id == "character" and String(ui_state.selected_ability_id) == "" and not sim.run.get("known", []).is_empty():
			ui_state.selected_ability_id = String(sim.run.known[0])
		if panel_id == "spellbook" and String(ui_state.selected_spellbook_id) == "":
			for book_id in sim.run.get("inventory", []):
				if sim.content.items.get(book_id, {}).get("type", "") == "spellbook":
					ui_state.selected_spellbook_id = String(book_id)
					ui_state.selected_inventory_index = int(sim.run.inventory.find(book_id))
					break
	queue_redraw()

func _shift_active_hits(first_index: int, horizontal_delta: float) -> void:
	if is_zero_approx(horizontal_delta):
		return
	for index in range(first_index, active_hits.size()):
		var hit: Dictionary = active_hits[index]
		var hit_rect: Rect2 = hit.rect
		hit_rect.position.x += horizontal_delta
		hit.rect = hit_rect
		active_hits[index] = hit

func _draw_label(text: String, x: float, y: float, size: int, color: Color, alignment: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	# Rasterize glyphs at integer physical-pixel sizes, then restore the geometry transform.
	var physical_size := _physical_font_size(size)
	var measured: Vector2 = ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, physical_size)
	var draw_x := x
	if alignment == HORIZONTAL_ALIGNMENT_CENTER:
		draw_x -= measured.x / maxf(0.1, draw_scale) * 0.5
	elif alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		draw_x -= measured.x / maxf(0.1, draw_scale)
	var logical_position := Vector2(draw_x, y) + draw_label_content_offset
	var physical_position := (draw_offset + logical_position * draw_scale).round()
	var restore_offset := draw_offset + draw_label_content_offset * draw_scale
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_string(ThemeDB.fallback_font, physical_position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, physical_size, color)
	draw_set_transform(restore_offset, 0.0, Vector2(draw_scale, draw_scale))

func _physical_font_size(size: int) -> int:
	var scaled := float(size) * draw_scale
	var floor_size := 9 if size <= 6 else 10 if size <= 8 else 11 if size <= 10 else 12
	return maxi(floor_size, roundi(scaled))

func _text_line_height(size: int) -> float:
	return ThemeDB.fallback_font.get_height(_physical_font_size(size)) / maxf(0.1, draw_scale)

func _action_detail_lines(text: String, max_width: float) -> Array[String]:
	var rows: Array[String] = []
	for paragraph_value in text.split("\n", false):
		var paragraph := String(paragraph_value).strip_edges()
		if paragraph.is_empty():
			continue
		rows.append_array(_wrap_text_to_width(paragraph, max_width, 7))
	if rows.size() > 3:
		var tail: String = rows.back()
		var overflow_parts: Array[String] = []
		for row_index in range(2, rows.size() - 1):
			overflow_parts.append(rows[row_index])
		var overflow := " ".join(overflow_parts)
		rows.resize(3)
		rows[2] = _fit_text((overflow + " " if not overflow.is_empty() else "") + tail + "…", max_width, 7)
	return rows

func _quickbar_item_detail(item: Dictionary, item_count: int) -> String:
	if item_count <= 0:
		return ""
	var use_time := 70
	if String(item.get("type", "")) == "scroll":
		var ability_id := String(item.get("ability", ""))
		use_time = int(sim.content.abilities.get(ability_id, {}).get("time", use_time))
	return "×%d\n%dT" % [item_count, use_time]

func _wrap_text_to_width(text: String, max_width: float, size: int, max_lines: int = -1) -> Array[String]:
	var wrapped: Array[String] = []
	var physical_limit := maxf(1.0, max_width * draw_scale - 2.0)
	var physical_size := _physical_font_size(size)
	var paragraphs := text.split("\n", true)
	for paragraph_index in range(paragraphs.size()):
		var paragraph := String(paragraphs[paragraph_index]).strip_edges()
		if paragraph.is_empty():
			if paragraph_index > 0 and paragraph_index < paragraphs.size() - 1:
				wrapped.append("")
			continue
		var current := ""
		for word_value in paragraph.split(" ", false):
			var word := String(word_value)
			var candidate := word if current.is_empty() else current + " " + word
			var candidate_width := ThemeDB.fallback_font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, physical_size).x
			if candidate_width <= physical_limit:
				current = candidate
				continue
			if not current.is_empty():
				wrapped.append(current)
				current = ""
			var word_width := ThemeDB.fallback_font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, physical_size).x
			if word_width > physical_limit:
				wrapped.append(_fit_text(word, max_width, size))
			else:
				current = word
		if not current.is_empty():
			wrapped.append(current)
		if paragraph_index < paragraphs.size() - 1 and not paragraph.is_empty():
			wrapped.append("")
	if max_lines > 0 and wrapped.size() > max_lines:
		var overflow: Array[String] = []
		for index in range(max_lines - 1, wrapped.size()):
			if not String(wrapped[index]).is_empty():
				overflow.append(String(wrapped[index]))
		wrapped.resize(max_lines)
		wrapped[max_lines - 1] = _fit_text(" ".join(overflow) + "…", max_width, size)
	return wrapped

func _fit_text(text: String, max_width: float, size: int) -> String:
	var physical_limit := max_width * draw_scale
	var physical_size := _physical_font_size(size)
	if ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, physical_size).x <= physical_limit:
		return text
	var shortened := text
	while not shortened.is_empty():
		shortened = shortened.substr(0, shortened.length() - 1).strip_edges()
		var candidate := shortened + "…"
		if ThemeDB.fallback_font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, physical_size).x <= physical_limit:
			return candidate
	return "…"

func _format_count_for_ui(value: Variant) -> String:
	var digits := sim._normalize_counter(value)
	if digits.length() <= 9:
		return digits
	var mantissa := digits.substr(0, 1) + "." + digits.substr(1, 3)
	return "~%se%d" % [mantissa, digits.length() - 1]

func _draw_line(x1: float, y1: float, x2: float, y2: float, color: Color) -> void:
	draw_line(Vector2(x1, y1), Vector2(x2, y2), color, 1.0)

func _cell_center(cell: Vector2i) -> Vector2:
	var tile := _tile_size()
	return _board_origin() + Vector2(cell.x * tile + tile * 0.5, cell.y * tile + tile * 0.5)

func _logical_position(point: Vector2) -> Vector2:
	return (point - draw_offset) / draw_scale

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		_handle_screen_pointer_event(event)
		get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if playback_active and event.button_index == MOUSE_BUTTON_RIGHT:
			accept_event()
			return
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and overlay == "abilities":
			if _ability_graph_rect().has_point(_logical_position(event.position)) and event.pressed:
				_zoom_ability_web(1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.89, _logical_position(event.position))
				accept_event()
			return
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var right_pos := _logical_position(event.position)
			if page == "battle" and _point_in_board(right_pos):
				_inspect_cell(_cell_from_point(right_pos), true)
				accept_event()
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			mouse_press_active = true
			press_position = _logical_position(event.position)
			press_current_position = press_position
			web_last_pointer = press_position
			web_pan_active = overlay == "abilities" and _ability_graph_rect().has_point(press_position)
			press_started = Time.get_ticks_msec()
			press_dragged = false
			queue_redraw()
		else:
			if not mouse_press_active:
				return
			_finish_pointer_press(_logical_position(event.position), false)
			mouse_press_active = false
			accept_event()
	elif event is InputEventMouseMotion:
		var pointer_now := _logical_position(event.position)
		var hover_changed := hover_position.distance_to(pointer_now) > 0.5
		hover_position = pointer_now
		if not mouse_press_active:
			if hover_changed:
				queue_redraw()
			return
		if web_pan_active:
			var pan_delta := pointer_now - web_last_pointer
			web_pan -= pan_delta / maxf(0.1, web_zoom)
			web_last_pointer = pointer_now
			if press_position.distance_to(pointer_now) > POINTER_DRAG_SLOP:
				press_dragged = true
			press_current_position = pointer_now
			queue_redraw()
			return
		press_current_position = pointer_now
		if press_position.distance_to(press_current_position) > POINTER_DRAG_SLOP:
			press_dragged = true
		queue_redraw()
	elif event is InputEventScreenTouch:
		_handle_screen_pointer_event(event)
		accept_event()
	elif event is InputEventScreenDrag:
		_handle_screen_pointer_event(event)
		accept_event()

func _handle_screen_pointer_event(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if touch_index >= 0 and event.index != touch_index:
				return
			touch_index = event.index
			press_position = _logical_position(event.position)
			press_current_position = press_position
			web_last_pointer = press_position
			web_pan_active = overlay == "abilities" and _ability_graph_rect().has_point(press_position)
			press_started = Time.get_ticks_msec()
			press_dragged = false
			queue_redraw()
		elif event.index == touch_index:
			_finish_pointer_press(_logical_position(event.position), event.canceled)
			touch_index = -1
	elif event is InputEventScreenDrag and event.index == touch_index:
		var pointer_now := _logical_position(event.position)
		if web_pan_active:
			var pan_delta := pointer_now - web_last_pointer
			web_pan -= pan_delta / maxf(0.1, web_zoom)
			web_last_pointer = pointer_now
			if press_position.distance_to(pointer_now) > POINTER_DRAG_SLOP:
				press_dragged = true
			press_current_position = pointer_now
			queue_redraw()
			return
		press_current_position = pointer_now
		if press_position.distance_to(press_current_position) > POINTER_DRAG_SLOP:
			press_dragged = true
		queue_redraw()

func _finish_pointer_press(point: Vector2, cancelled: bool) -> void:
	var duration := Time.get_ticks_msec() - press_started
	var valid_tap := not cancelled and not press_dragged and press_position.distance_to(point) <= POINTER_DRAG_SLOP
	if playback_active:
		press_current_position = Vector2(-1, -1)
		press_position = Vector2(-1, -1)
		press_dragged = false
		web_pan_active = false
		return
	if valid_tap and duration >= 500:
		if page == "battle" and _point_in_board(point):
			_inspect_cell(_cell_from_point(point), true)
	elif valid_tap:
		_handle_tap(point)
	press_current_position = Vector2(-1, -1)
	press_position = Vector2(-1, -1)
	press_dragged = false
	web_pan_active = false
	queue_redraw()

func _handle_tap(point: Vector2) -> void:
	if overlay != "":
		for i in range(active_hits.size() - 1, overlay_hit_start - 1, -1):
			var overlay_hit: Dictionary = active_hits[i]
			if overlay_hit.rect.has_point(point):
				_handle_action(overlay_hit.action)
				return
		return
	if page == "title":
		for hit in active_hits.duplicate():
			if hit.rect.has_point(point):
				_handle_action(hit.action)
				return
		return
	if page == "outcome":
		for hit in active_hits.duplicate():
			if hit.rect.has_point(point):
				_handle_action(hit.action)
				return
		return
	for i in range(active_hits.size() - 1, -1, -1):
		var hit: Dictionary = active_hits[i]
		if hit.rect.has_point(point):
			_handle_action(hit.action)
			return
	if _point_in_board(point):
		_battlefield_tap(_cell_from_point(point))

func _handle_action(action: Dictionary) -> void:
	var action_type := String(action.get("type", ""))
	if playback_active and action_type not in ["playback_skip", "pause_menu", "close"]:
		return
	if target_mode != "" and action_type not in ["cancel_target", "target_mode", "ability", "quick_item", "quickbar_slot", "palette_cast"]:
		target_mode = ""
	match String(action.get("type", "")):
		"select_character":
			selected_character = String(action.id)
		"start":
			if sim.has_saved_run():
				overlay = "new_run_confirm"
			else:
				_begin_selected_run()
		"replace_active_run":
			sim.delete_saved_run()
			overlay = ""
			_begin_selected_run()
		"resume":
			if sim.resume_run():
				page = "battle" if sim.run.get("outcome", "") == "" else "outcome"
				overlay = ""
				target_mode = ""
				selected_object_index = -1
			else:
				_show_notice("The saved expedition could not be opened.")
		"title_codex":
			sim._load_codex()
			page = "title"
			overlay = "codex"
		"content_mods":
			overlay = "content_mods"
		"package_toggle":
			var package_result: Dictionary = sim.set_package_enabled(String(action.get("id", "")), bool(action.get("enabled", false)))
			if package_result.get("ok", false):
				if not sim.is_character_unlocked(selected_character):
					selected_character = sim.get_starting_character_ids()[0]
				queue_redraw()
			else:
				_show_notice(String(package_result.get("error", "This package could not be changed.")))
		"unlock_character":
			var unlock_id := String(action.get("id", ""))
			if sim.unlock_character(unlock_id):
				reveal_character_id = unlock_id
				overlay = "character_reveal"
		"overlay":
			var overlay_id := String(action.id)
			if overlay_id in ["map", "inventory", "spellbook"]:
				if overlay_id == "map": _open_lower_panel("world_map")
				elif overlay_id == "inventory": _open_lower_panel("inventory")
				else: _open_lower_panel("spellbook")
			elif overlay_id == "abilities":
				_open_lower_panel("character")
			elif overlay_id == "ability_web":
				overlay = "abilities"
				ui_state.lower_dock_expanded = false
			elif overlay_id == "inspect":
				selected_enemy = String(action.get("id", selected_enemy))
				selected_object_index = -1
				overlay = ""
			else:
				if target_mode != "": _cancel_targeting()
				overlay = overlay_id
				ui_state.selected_inventory_index = -1
				selected_object_index = -1
				selected_enemy = "" if overlay_id != "inspect" else selected_enemy
			if overlay == "abilities":
				var known: Array = sim.run.get("known", [])
				ui_state.selected_ability_id = String(known.back()) if not known.is_empty() else ""
				ability_filter = String(sim.content.abilities.get(ui_state.selected_ability_id, {}).get("school", "All"))
				ability_filter_page = 0
				web_zoom = 0.86
				_center_web_on(ui_state.selected_ability_id)
			elif overlay == "action_palette":
				palette_page = 0
				palette_filter = "All"
		"close":
			if overlay != "":
				if overlay in ["rewards", "destinations"] and sim.run.get("stage_completed", false):
					sim.run["stage_prompt_dismissed"] = true
					sim.save_run()
					var pending_reveal := sim.get_pending_character_reveal()
					if pending_reveal != "" and page == "battle":
						reveal_character_id = pending_reveal
						overlay = "character_reveal"
						queue_redraw()
						return
				if overlay == "character_reveal":
					var revealed_id := reveal_character_id if reveal_character_id != "" else sim.get_pending_character_reveal()
					if revealed_id != "": sim.consume_character_reveal(revealed_id)
					reveal_character_id = ""
				overlay = "pause" if overlay == "exit_confirm" else "codex" if overlay == "codex_book" else ""
			else:
				ui_state.lower_dock_expanded = false
		"lower_panel":
			_open_lower_panel(String(action.get("id", "world_map")))
		"lower_character_tab":
			ui_state.character_tab = String(action.get("id", "Abilities"))
			ui_state.ability_page = 0
		"lower_inventory_tab":
			ui_state.inventory_tab = String(action.get("id", "Inventory"))
			ui_state.inventory_page = 0
			if ui_state.inventory_tab == "Equipment" and ui_state.selected_inventory_index >= 0 and not sim.can_equip_item(ui_state.selected_inventory_index, ui_state.selected_equipment_slot):
				ui_state.selected_inventory_index = -1
		"select_ability_category":
			ui_state.selected_ability_category = String(action.get("id", ""))
			ui_state.ability_page = 0
			if not String(ui_state.selected_ability_id).is_empty() and not sim.content.abilities.get(ui_state.selected_ability_id, {}).get("categories", []).has(ui_state.selected_ability_category):
				ui_state.selected_ability_id = ""
		"ability_category_page":
			var category_total: int = sim.content.get("ability_categories", {}).size()
			var category_pages := maxi(1, int(ceil(float(category_total) / 10.0)))
			ui_state.ability_category_page = posmod(int(ui_state.ability_category_page) + int(action.get("delta", 0)), category_pages)
		"lower_ability_page":
			var total_abilities: int = sim.get_progression_graph().size() if ui_state.character_tab == "Known" else sim.content.abilities.size()
			var page_count := maxi(1, int(ceil(float(total_abilities) / 6.0)))
			ui_state.ability_page = posmod(int(ui_state.ability_page) + int(action.get("delta", 0)), page_count)
		"inventory_page":
			var page_count := maxi(1, int(ceil(float(sim.run.get("artifacts", []).size()) / 18.0)))
			ui_state.inventory_page = posmod(int(ui_state.inventory_page) + int(action.get("delta", 0)), page_count)
		"select_artifact":
			ui_state.selected_artifact_index = int(action.get("index", -1))
		"clear_inspection":
			selected_enemy = ""
			selected_object_index = -1
		"select_equipment_slot":
			ui_state.selected_equipment_slot = String(action.get("slot", ""))
			if ui_state.selected_inventory_index >= 0 and not sim.can_equip_item(ui_state.selected_inventory_index, ui_state.selected_equipment_slot):
				ui_state.selected_inventory_index = -1
		"select_lower_ability":
			var ability_id := String(action.get("id", ""))
			ui_state.selected_ability_id = ability_id
			if quickbar_pending_slot >= 0 and sim.assign_quickbar(quickbar_pending_slot, "ability", ability_id):
				quickbar_pending_slot = -1
				_show_notice("Action bar updated.")
		"select_lower_book":
			ui_state.selected_spellbook_id = String(action.get("id", ""))
			ui_state.selected_inventory_index = int(sim.run.inventory.find(String(ui_state.selected_spellbook_id)))
			selected_book_abilities.clear()
		"pause_menu":
			overlay = "pause"
		"cancel_target":
			_cancel_targeting()
		"target_mode":
			_set_target_mode(String(action.mode))
		"ability":
			var ability_id: String = action.id
			var ability: Dictionary = sim.content.abilities[ability_id]
			if ability.get("target", "enemy") == "self":
				overlay = ""
				_commit_action(sim.act({"type": "cast", "id": ability_id, "target": sim.get_player().pos}))
			else:
				overlay = ""
				_set_target_mode(ability_id)
		"inspect":
			selected_enemy = String(action.id)
			selected_object_index = -1
			overlay = ""
		"dpad":
			var pos: Vector2i = sim._pos(sim.get_player()) + Vector2i(int(action.direction[0]), int(action.direction[1]))
			_commit_action(sim.act({"type": "move", "target": [pos.x, pos.y]}))
		"wait":
			_commit_action(sim.act({"type": "wait"}))
		"end_turn":
			_commit_action(sim.act({"type": "wait"}))
		"quick_item":
			var item_index := int(action.index)
			var item_id: String = sim.run.inventory[item_index]
			var item: Dictionary = sim.content.items[item_id]
			if item.get("effect") == "bomb" or item.get("type") == "scroll":
				_set_target_mode("item:%d" % item_index)
			else:
				target_mode = ""
				_commit_action(sim.act({"type": "use_item", "index": item_index, "target": [-1, -1]}))
		"use_item":
			if ui_state.selected_inventory_index >= 0:
				var item_id: String = sim.run.inventory[ui_state.selected_inventory_index]
				var item: Dictionary = sim.content.items[item_id]
				if item.get("effect") == "bomb" or item.get("type") == "scroll":
					_set_target_mode("item:%d" % ui_state.selected_inventory_index)
					overlay = ""
					_show_notice("Choose a visible target on the battlefield.")
				else:
					_commit_action(sim.act({"type": "use_item", "index": ui_state.selected_inventory_index, "target": [-1, -1]}))
		"equip":
			if sim.equip_item(ui_state.selected_inventory_index):
				ui_state.selected_inventory_index = -1
				if sim.get_pending_character_reveal() != "":
					reveal_character_id = sim.get_pending_character_reveal()
					overlay = "character_reveal"
				else:
					_show_notice("Equipment updated.")
		"discard":
			if sim.discard_item(ui_state.selected_inventory_index):
				ui_state.selected_inventory_index = -1
				_show_notice("Item discarded.")
		"unequip":
			if sim.unequip_item(String(action.get("slot", ""))):
				_show_notice("Equipment moved into the pack.")
		"select_item":
			ui_state.selected_inventory_index = int(action.index)
			selected_book_abilities.clear()
		"study_book":
			var book_id: String = sim.run.inventory[ui_state.selected_inventory_index] if ui_state.selected_inventory_index >= 0 and ui_state.selected_inventory_index < sim.run.inventory.size() else ""
			if sim.study_spellbook(ui_state.selected_inventory_index, selected_book_abilities):
				var resolution: Dictionary = sim.run.spellbook_resolutions.get(book_id, {})
				var chosen_names: Array[String] = []
				for ability_id in resolution.get("abilities", []):
					chosen_names.append(String(sim.content.abilities[ability_id].name))
				ui_state.selected_inventory_index = -1 if sim.content.items.get(book_id, {}).get("learning", {}).get("consume_on_study", false) else ui_state.selected_inventory_index
				selected_book_abilities.clear()
				var book: Dictionary = sim.content.items.get(book_id, {})
				var school_name := String(book.get("school", ""))
				var immediate_result := ", ".join(chosen_names) if not chosen_names.is_empty() else "%s knowledge unlocked" % school_name if school_name != "" else "knowledge recorded"
				if sim.get_pending_character_reveal() != "":
					reveal_character_id = sim.get_pending_character_reveal()
					overlay = "character_reveal"
				else:
					_show_notice("Knowledge recorded: %s." % immediate_result)
		"toggle_book_choice":
			var option_index := int(action.index)
			if selected_book_abilities.has(option_index):
				selected_book_abilities.erase(option_index)
			else:
				var book_options: Dictionary = sim.get_spellbook_options(ui_state.selected_inventory_index)
				var required_choices := int(book_options.get("choice_count", 0))
				if selected_book_abilities.size() >= required_choices:
					if required_choices == 1:
						selected_book_abilities.clear()
					else:
						_show_notice("Choose exactly %d abilities; remove one before adding another." % required_choices)
						return
				selected_book_abilities.append(option_index)
		"select_web_node":
			ui_state.selected_ability_id = String(action.id)
		"web_filter":
			ability_filter = String(action.get("school", "All"))
			var focus_id: String = sim.get_progression_focus_id(ability_filter) if ability_filter != "All" else ui_state.selected_ability_id
			if focus_id != "": ui_state.selected_ability_id = focus_id
			_center_web_on(focus_id if focus_id != "" else ui_state.selected_ability_id)
		"web_filter_page":
			ability_filter_page = maxi(0, ability_filter_page + int(action.get("delta", 0)))
		"web_zoom":
			_zoom_ability_web(float(action.get("factor", 1.0)), _ability_graph_rect().get_center())
		"web_center":
			_center_web_on(ui_state.selected_ability_id)
		"web_center_root":
			var root_school := ability_filter
			if root_school == "All": root_school = String(sim.content.abilities.get(ui_state.selected_ability_id, {}).get("school", ""))
			_center_web_on(sim.get_progression_root_id(root_school))
		"open_action_palette":
			overlay = ""
			ui_state.active_lower_panel = "character"
			ui_state.lower_dock_expanded = true
			ui_state.character_tab = "Known"
			palette_page = 0
			palette_filter = "All"
			quickbar_pending_slot = int(action.get("slot", -1))
		"open_combat_history":
			combat_history_page = maxi(0, int(ceil(float(sim.run.get("combat_history", []).size()) / 20.0)) - 1)
			overlay = "combat_history"
		"combat_history_page":
			combat_history_page = maxi(0, combat_history_page + int(action.get("delta", 0)))
		"quickbar_slot":
			var slot_index := int(action.get("index", -1))
			if quickbar_assign_mode:
				if sim.assign_quickbar(slot_index, String(quickbar_pending.get("type", "")), String(quickbar_pending.get("id", ""))):
					quickbar_assign_mode = false
					quickbar_pending = {"type": "", "id": ""}
					_show_notice("Action bar updated.")
				else:
					_show_notice("That action cannot be assigned to this slot.")
			elif slot_index >= 0 and slot_index < sim.run.get("quickbar", []).size():
				var assigned: Dictionary = sim.run.quickbar[slot_index]
				var assigned_type := String(assigned.get("type", "empty"))
				var assigned_id := String(assigned.get("id", ""))
				if assigned_type == "ability":
					_handle_action({"type": "ability", "id": assigned_id})
				elif assigned_type == "item":
					var item_index := int(sim.run.inventory.find(assigned_id))
					if item_index < 0:
						_show_notice("You have none of that item.")
					elif sim.content.items.get(assigned_id, {}).get("effect", "") == "bomb" or sim.content.items.get(assigned_id, {}).get("type", "") == "scroll":
						_set_target_mode("item:%d" % item_index)
					else:
						_commit_action(sim.act({"type": "use_item", "index": item_index, "target": [-1, -1]}))
				else:
					quickbar_pending_slot = slot_index
					ui_state.active_lower_panel = "character"
					ui_state.lower_dock_expanded = true
					ui_state.character_tab = "Known"
		"begin_quickbar_assignment":
			var assignment_type := String(action.get("kind", ""))
			var assignment_id := String(action.get("id", ""))
			if quickbar_pending_slot >= 0:
				if sim.assign_quickbar(quickbar_pending_slot, assignment_type, assignment_id):
					quickbar_pending_slot = -1
					_show_notice("Action bar updated.")
			else:
				quickbar_assign_mode = true
				quickbar_pending = {"type": assignment_type, "id": assignment_id}
				overlay = ""
				_show_notice("Tap a quick slot to assign this action.")
		"remove_quickbar_assignment":
			for slot_index in range(8):
				if sim.run.quickbar[slot_index].get("type") == String(action.get("kind", "")) and sim.run.quickbar[slot_index].get("id") == String(action.get("id", "")):
					sim.assign_quickbar(slot_index, "empty", "")
			quickbar_pending_slot = -1
			_show_notice("Action removed from the bar.")
		"playback_speed":
			playback_mode = String(action.get("mode", "Normal"))
			if playback_active and playback_mode == "Instant": _finish_presentation()
		"playback_skip":
			if playback_active: _finish_presentation()
		"palette_page":
			palette_page = maxi(0, palette_page + int(action.get("delta", 0)))
		"palette_filter":
			palette_filter = String(action.get("school", "All"))
			palette_page = 0
		"select_palette_ability":
			selected_ability = String(action.get("id", ""))
		"palette_cast":
			var selected_palette_id := String(action.get("id", selected_ability))
			_handle_action({"type": "ability", "id": selected_palette_id})
		"quickbar_page":
			var abilities: Array = sim.get_available_abilities()
			var page_count := maxi(1, int(ceil(float(abilities.size()) / 6.0)))
			quickbar_page = posmod(quickbar_page + int(action.get("delta", 0)), page_count)
		"route":
			if sim.choose_route(String(action.id)):
				ui_state.lower_dock_expanded = false
				selected_enemy = ""
				selected_object_index = -1
		"boss":
			if sim.start_boss():
				ui_state.lower_dock_expanded = false
				selected_enemy = ""
				selected_object_index = -1
		"next_stage":
			if sim.run.get("stage_completed", false):
				if int(sim.run.get("stage_index", 0)) == 5:
					if sim.reveal_next_map():
						overlay = "map_reveal"
					else:
						_show_notice("The next map could not be generated.")
				else:
					if sim.advance_stage():
						overlay = ""
						ui_state.lower_dock_expanded = false
						selected_enemy = ""
						selected_object_index = -1
		"enter_next_map":
			if sim.enter_next_map():
				overlay = ""
				ui_state.lower_dock_expanded = false
				selected_enemy = ""
				selected_object_index = -1
		"run_summary_page":
			run_summary_page = maxi(0, run_summary_page + int(action.get("delta", 0)))
		"map_history_page":
			var journey: Dictionary = lower_dock._persistent_journey()
			var last_start := maxi(0, journey.get("entries", []).size() - 5)
			var current_start := last_start if int(ui_state.map_history_start) < 0 else int(ui_state.map_history_start)
			var requested_start := clampi(current_start + int(action.get("delta", 0)), 0, last_start)
			ui_state.map_history_start = -1 if requested_start == last_start else requested_start
		"destination_route":
			var destination_id := String(action.get("id", ""))
			var traveled := sim.start_boss() if destination_id == "boss" else sim.choose_route(destination_id)
			if traveled:
				overlay = ""
				selected_enemy = ""
				selected_object_index = -1
		"claim_reward":
			if sim.claim_reward(int(action.index)):
				_show_notice("Your one reward choice is secured. You may keep exploring.")
		"learn":
			if sim.learn_ability(String(action.id)):
				ui_state.selected_ability_id = String(action.id)
				_center_web_on(ui_state.selected_ability_id)
				if sim.get_pending_character_reveal() != "":
					reveal_character_id = sim.get_pending_character_reveal()
					overlay = "character_reveal"
				else:
					_show_notice("Ability learned.")
		"codex_book":
			codex_book_id = String(action.id)
			overlay = "codex_book"
		"inspect_entity":
			var entity_id := String(action.get("id", ""))
			if entity_id == "player":
				_show_notice("You · %d / %d Health" % [sim.get_player().hp, sim.get_player().max_hp])
			else:
				selected_enemy = entity_id
				selected_object_index = -1
				overlay = ""
		"save":
			sim.save_run()
			_show_notice("Run saved.")
		"interact":
			if selected_object_index >= 0 and selected_object_index < sim.run.objects.size():
				var object_pos: Array = sim.run.objects[selected_object_index].pos
				var result: Dictionary = sim.act({"type": "interact", "target": object_pos})
				if result.ok:
					selected_object_index = -1
					_commit_action(result)
				else:
					_show_notice(String(result.message))
		"target_object":
			_set_target_mode("attack")
			selected_enemy = ""
			selected_object_index = -1
		"quit_app":
			_save_active_run()
			get_tree().quit()
		"title":
			page = "title"
			overlay = ""
			selected_enemy = ""
			selected_object_index = -1
	queue_redraw()

func _begin_selected_run() -> void:
	var seed_value := int(Time.get_unix_time_from_system())
	if sim.start_run(seed_value, selected_character):
		sim.save_run()
		page = "battle"
		overlay = ""
		selected_enemy = ""
		selected_object_index = -1
		target_mode = ""
	else:
		_show_notice("Choose an unlocked character to begin.")

func _battlefield_tap(cell: Vector2i) -> void:
	if playback_active: return
	if not sim._inside(cell):
		return
	if target_mode.begins_with("item:"):
		var item_index := int(target_mode.trim_prefix("item:"))
		_commit_action(sim.act({"type": "use_item", "index": item_index, "target": [cell.x, cell.y]}))
		return
	if target_mode == "move":
		var result: Dictionary = sim.act({"type": "move", "target": [cell.x, cell.y]})
		if result.ok:
			target_mode = ""
		_commit_action(result)
		return
	if target_mode == "attack":
		var result: Dictionary = sim.act({"type": "attack", "target": [cell.x, cell.y]})
		if result.ok:
			target_mode = ""
		_commit_action(result)
		return
	if sim.content.abilities.has(target_mode):
		var result: Dictionary = sim.act({"type": "cast", "id": target_mode, "target": [cell.x, cell.y]})
		if result.ok:
			target_mode = ""
		_commit_action(result)
		return
	var entity: Dictionary = sim.get_enemy_at(cell)
	if not entity.is_empty():
		selected_enemy = String(entity.id)
		selected_object_index = -1
		_show_notice("%s · tap Weapon Attack or an ability to act." % entity.name)
		return
	if not sim._cell_visible(cell):
		_show_notice("That tile is still hidden by fog of war.")
		return
	var object_index := sim._object_index_at(cell)
	if object_index >= 0:
		selected_object_index = object_index
		selected_enemy = ""
		_show_notice("%s · choose an available field action." % sim.run.objects[object_index].get("name", "Field object"))
		queue_redraw()
		return
	var move_result: Dictionary = sim.act({"type": "move", "target": [cell.x, cell.y]})
	_commit_action(move_result)

func _inspect_cell(cell: Vector2i, detailed: bool) -> void:
	var entity: Dictionary = sim.get_enemy_at(cell)
	if not entity.is_empty():
		selected_enemy = String(entity.id)
		if detailed:
			overlay = ""
			_show_notice("Inspecting %s." % entity.name)
		else:
			_show_notice("%s · %d / %d HP" % [entity.name, entity.hp, entity.max_hp])
	else:
		var object_index := sim._object_index_at(cell)
		if object_index >= 0:
			selected_object_index = object_index
			selected_enemy = ""
			var object: Dictionary = sim.run.objects[object_index]
			_show_notice("%s · %s" % [String(object.get("name", "Field object")), String(object.get("kind", "object")).capitalize()])
		else:
			selected_object_index = -1
			selected_enemy = ""
			_show_notice("%s tile  ·  %s" % [sim.get_stage_name(), sim._terrain_at(cell)])
	queue_redraw()

func _selected_object() -> Dictionary:
	if selected_object_index < 0 or selected_object_index >= sim.run.get("objects", []).size():
		return {}
	var object: Dictionary = sim.run.objects[selected_object_index]
	return object if int(object.get("hp", 1)) > 0 else {}

func _handle_key(event: InputEventKey) -> void:
	if playback_active and event.keycode != KEY_ESCAPE:
		if event.keycode == KEY_0:
			_finish_presentation()
		else:
			return
		queue_redraw()
		return
	if event.keycode == KEY_ESCAPE:
		# Android also delivers Back through NOTIFICATION_WM_GO_BACK_REQUEST.
		# Ignore its Escape key alias so one physical Back cannot dismiss a
		# context and then continue into the pause menu as a second action.
		if _is_mobile_layout():
			return
		if playback_active:
			overlay = "pause"
			queue_redraw()
			return
		if target_mode != "":
			_cancel_targeting()
		elif ui_state.lower_dock_expanded:
			ui_state.lower_dock_expanded = false
		elif overlay == "exit_confirm":
			overlay = "pause"
		elif overlay != "":
			overlay = ""
		elif page == "battle":
			overlay = "pause"
		elif page == "outcome":
			page = "title"
		queue_redraw()
		return
	if page != "battle" or overlay != "":
		return
	if event.keycode == KEY_I:
		_open_lower_panel("inventory")
		return
	if event.keycode == KEY_K:
		_open_lower_panel("character")
		return
	if event.keycode == KEY_M:
		_open_lower_panel("world_map")
		return
	if ui_state.lower_dock_expanded:
		return
	var direction := Vector2i.ZERO
	if event.keycode in [KEY_W, KEY_UP]: direction = Vector2i(0, -1)
	elif event.keycode in [KEY_S, KEY_DOWN]: direction = Vector2i(0, 1)
	elif event.keycode in [KEY_A, KEY_LEFT]: direction = Vector2i(-1, 0)
	elif event.keycode in [KEY_D, KEY_RIGHT]: direction = Vector2i(1, 0)
	if direction != Vector2i.ZERO:
		var cell: Vector2i = sim._pos(sim.get_player()) + direction
		_commit_action(sim.act({"type": "move", "target": [cell.x, cell.y]}))
	elif event.keycode in [KEY_E, KEY_PERIOD, KEY_SPACE]:
		_commit_action(sim.act({"type": "wait"}))
	elif event.keycode >= KEY_1 and event.keycode <= KEY_6:
		var index := int(event.keycode - KEY_1)
		var known: Array = sim.get_available_abilities()
		if index < known.size():
			_handle_action({"type": "ability", "id": known[index]})
	queue_redraw()

func _commit_action(result: Dictionary) -> void:
	if result.get("ok", false):
		target_mode = ""
		ui_state.lower_dock_expanded = false
		pending_outcome_page = "outcome" if sim.run.get("outcome", "") != "" else ""
		pending_outcome_overlay = "rewards" if sim.run.get("stage_completed", false) and not sim.run.get("stage_prompt_dismissed", false) and sim.run.get("outcome", "") == "" else ""
		var events: Array = result.get("presentation_events", [])
		if not events.is_empty() and playback_mode != "Instant":
			playback_active = true
			presentation_state = result.get("presentation_before", {}).duplicate(true)
			presentation_history = presentation_state.get("combat_history", []).duplicate(true)
			playback_events = events.duplicate(true)
			playback_index = 0
			current_presentation_event = {}
			overlay = ""
			set_process(true)
			_start_next_presentation_event()
		else:
			pending_outcome_page = ""
			pending_outcome_overlay = ""
			if sim.run.get("outcome", "") != "":
				page = "outcome"
				overlay = ""
			elif sim.run.get("stage_completed", false) and not sim.run.get("stage_prompt_dismissed", false) and overlay == "":
				overlay = "rewards"
			elif sim.get_pending_character_reveal() != "" and overlay == "":
				reveal_character_id = sim.get_pending_character_reveal()
				overlay = "character_reveal"
	else:
		_show_notice(String(result.get("message", "That action could not be completed.")))
	queue_redraw()

func _format_combat_event(event: Dictionary) -> String:
	if event.is_empty(): return "Resolving the turn"
	var kind := String(event.get("type", ""))
	var actor := String(event.get("actor_name", ""))
	var target := String(event.get("target_name", ""))
	var details: Dictionary = event.get("details", {})
	match kind:
		"ActorTurnStarted": return "%s acts" % actor if actor != "" else "A visible creature acts"
		"Move": return "%s moves" % actor if actor != "" else "Movement"
		"Spotted": return "%s enters view" % actor
		"LeavesSight": return "%s moves beyond sight" % actor
		"Attack": return "%s attacks %s" % [actor, target] if target != "" else "%s attacks" % actor
		"Cast": return "%s casts %s" % [actor, String(details.get("ability", "a spell"))] if actor != "" else "A spell flares nearby"
		"Damage": return "%s takes %d %s damage" % [target, int(details.get("amount", 0)), String(details.get("damage_type", ""))] if target != "" else "A creature takes damage"
		"UnseenImpact": return String(details.get("message", "An unseen attack strikes you."))
		"Heal": return "%s restores %d Health" % [target if target != "" else actor, int(details.get("amount", 0))]
		"StatusApplied": return "%s gains %s" % [target if target != "" else actor, String(details.get("status", "an effect"))]
		"StatusRemoved": return "%s loses %s" % [target if target != "" else actor, String(details.get("status", "an effect"))]
		"StatusTick": return "%s suffers %s" % [target, String(details.get("status", "an effect"))]
		"Summon": return "%s summons %s" % [actor if actor != "" else "A creature", target if target != "" else String(details.get("name", "an ally"))]
		"Death": return "%s falls" % target if target != "" else "A creature falls"
		"KillCredit": return "%s falls — +%d %sXP" % [target, int(details.get("xp", 0)), "Assist " if details.get("credit") == "assist" else ""] if int(details.get("xp", 0)) > 0 else "%s falls — no XP" % target
		"XPGranted": return "+%d %sXP" % [int(details.get("amount", 0)), "Assist " if details.get("reason") == "assist" else ""]
		"LevelUp": return "LEVEL %d  ·  +2 HP  ·  +1 ability point%s" % [int(details.get("level", 1)), "  ·  +1 %s" % String(details.get("attribute", "")) if details.get("attribute", "") != "" else ""]
		"TerrainChanged": return "Ground shifts to %s" % String(details.get("terrain", "floor"))
		"EncounterComplete": return "Encounter objective complete"
	return kind.replace("_", " ").capitalize()

func _cell_from_point(point: Vector2) -> Vector2i:
	var origin := _board_origin()
	var tile := _tile_size()
	return Vector2i(int(floor((point.x - origin.x) / tile)), int(floor((point.y - origin.y) / tile)))

func _point_in_board(point: Vector2) -> bool:
	return _board_rect().has_point(point)

func _target_ability() -> Dictionary:
	if target_mode.begins_with("item:"):
		var item_index := int(target_mode.trim_prefix("item:"))
		if item_index < 0 or item_index >= sim.run.get("inventory", []).size():
			return {}
		var item_id: String = sim.run.inventory[item_index]
		var item: Dictionary = sim.content.items.get(item_id, {})
		if item.get("type") == "scroll":
			return sim.content.abilities.get(item.get("ability", ""), {})
		return {}
	return sim.content.abilities.get(target_mode, {})

func _entity_is_legal_target(entity: Dictionary) -> bool:
	var pos := sim._pos(entity)
	var footprint := int(entity.get("footprint", 1))
	for y in range(pos.y, pos.y + footprint):
		for x in range(pos.x, pos.x + footprint):
			if sim.is_valid_target_cell(target_mode, Vector2i(x, y)):
				return true
	return false

func _cell_is_legal_target(cell: Vector2i) -> bool:
	if target_mode == "move":
		return sim._terrain_at(cell) != "wall" and not sim.get_movement_path(cell).is_empty()
	return sim.is_valid_target_cell(target_mode, cell)

func _draw_targetable_cells(origin: Vector2, tile: float) -> void:
	if target_mode == "":
		return
	if target_mode == "move" and _point_in_board(press_current_position):
		var move_cell := _cell_from_point(press_current_position)
		if _cell_is_legal_target(move_cell):
			var move_rect := Rect2(origin + Vector2(move_cell.x * tile, move_cell.y * tile), Vector2(tile - 1, tile - 1))
			draw_rect(move_rect, Color(0.33, 0.9, 0.53, 0.24), true)
			draw_rect(move_rect, COLORS.green, false, 2.0)
		return
	var preview: Dictionary = sim.get_targeting_preview(target_mode)
	if not preview.get("available", false):
		return
	var valid: Dictionary = {}
	for cell in preview.get("valid_cells", []):
		valid[sim._cell_key(cell)] = true
	for cell in preview.get("range_cells", []):
		var cell_position: Vector2i = cell
		var cell_rect := Rect2(origin + Vector2(cell_position.x * tile, cell_position.y * tile), Vector2(tile - 1.0, tile - 1.0))
		draw_rect(cell_rect, Color(0.92, 0.96, 1.0, 0.025), true)
		draw_rect(cell_rect, Color(0.88, 0.94, 1.0, 0.48), false, 1.0)
		if valid.has(sim._cell_key(cell_position)):
			draw_rect(cell_rect, Color(0.92, 0.96, 1.0, 0.08), true)
			draw_rect(cell_rect, COLORS.gold, false, 2.0)

func _target_preview_radius() -> int:
	if target_mode.begins_with("item:"):
		var item_index := int(target_mode.trim_prefix("item:"))
		if item_index >= 0 and item_index < sim.run.inventory.size():
			if sim.content.items.get(sim.run.inventory[item_index], {}).get("effect") == "bomb":
				return 1
	var ability := _target_ability()
	return int(ability.get("radius", 0)) if ability.get("target", "") == "area" else 0

func _show_notice(message: String) -> void:
	notice = message
	notice_until = Time.get_ticks_msec() + 2800
	set_process(true)
	queue_redraw()

func _school_color(school: String) -> Color:
	if school in ["Fire", "Demonology"]: return COLORS.orange
	if school in ["Frost", "Storm", "Arcane"]: return COLORS.cyan
	if school in ["Blood", "Necromancy", "Shadow"]: return COLORS.blood
	if school in ["Nature", "Summoning"]: return COLORS.green
	return COLORS.gold

func _ui_glyph(key: String) -> String:
	return String(UI_GLYPHS.get(key.to_lower(), UI_GLYPHS.neutral))

func _ability_glyph(ability: Dictionary) -> String:
	return _ui_glyph(String(ability.get("school", "neutral")))

func _entity_presentation_color(color_key: String) -> Color:
	match color_key:
		"player": return COLORS.cyan
		"ally": return COLORS.green
		"hostile": return COLORS.red
		"other": return COLORS.gold
		_: return COLORS.muted

func _set_target_mode(mode: String) -> void:
	if mode == target_mode:
		_cancel_targeting()
		return
	target_mode = mode
	selected_object_index = -1
	_show_notice("%s targeting active. Tap the action again, Back, or × to cancel." % _target_action_name())

func _cancel_targeting() -> void:
	if target_mode == "":
		return
	target_mode = ""
	_show_notice("Targeting cancelled.")

func _target_action_name() -> String:
	if target_mode == "": return ""
	if target_mode == "move": return "MOVE"
	if target_mode == "attack": return "WEAPON ATTACK"
	if target_mode.begins_with("item:"):
		var index := int(target_mode.trim_prefix("item:"))
		if index >= 0 and index < sim.run.get("inventory", []).size():
			return String(sim.content.items.get(sim.run.inventory[index], {}).get("name", "ITEM"))
	if sim.content.get("abilities", {}).has(target_mode):
		return String(sim.content.abilities[target_mode].get("name", "ABILITY"))
	return "TARGET"

func _center_web_on(ability_id: String) -> void:
	if ability_id == "":
		return
	for node in sim.get_progression_graph():
		if String(node.id) != ability_id:
			continue
		var viewport := _ability_graph_rect()
		web_pan = node.position
		return

func _item_glyph(item_id: String, item: Dictionary) -> String:
	if item.get("type") == "spellbook": return "▣"
	if item.get("type") == "scroll": return "▤"
	if item.get("type") == "consumable":
		match String(item.get("effect", "")):
			"heal": return "✚"
			"mana": return "◈"
			"bomb": return "✹"
	if item.has("weapon"):
		var weapon: Dictionary = sim.content.weapons.get(item.weapon, {})
		return "➶" if weapon.get("range", 1) > 2 else "⚔"
	if item.get("slot", "") in ["Ring 1", "Ring 2", "Amulet"]: return "◇"
	if int(item.get("armor", 0)) > 0: return "⛨"
	return String(item.get("name", item_id)).substr(0, 1).to_upper()

func _item_color(item_type: String, rarity: String) -> Color:
	if rarity in ["Rare", "Epic", "Legendary"]: return COLORS.purple
	match item_type:
		"spellbook": return COLORS.purple
		"scroll": return COLORS.cyan
		"consumable": return COLORS.orange
		"equipment": return COLORS.gold
		_: return COLORS.text

func _ability_graph_rect() -> Rect2:
	return Rect2(138, 220, 782, 414)

func _zoom_ability_web(factor: float, anchor: Vector2) -> void:
	var viewport := _ability_graph_rect()
	var world_point := web_pan + (anchor - viewport.get_center()) / maxf(0.1, web_zoom)
	web_zoom = clampf(web_zoom * factor, 0.65, 1.45)
	web_pan = world_point - (anchor - viewport.get_center()) / web_zoom
	queue_redraw()

func _effect_summary(effect: Dictionary) -> String:
	match String(effect.get("type", "")):
		"damage": return "%d %s damage%s" % [int(effect.get("amount", 0)), String(effect.get("damage", "Arcane")), " ×%d" % int(effect.get("repeats", 1)) if int(effect.get("repeats", 1)) > 1 else ""]
		"heal": return "Restore %d Health" % int(effect.get("amount", 0))
		"heal_on_hit": return "Recover %d Health on hit" % int(effect.get("amount", 0))
		"status": return "Apply %s" % String(effect.get("id", "an effect"))
		"summon": return "Summon %s" % String(sim.content.get("summons", {}).get(effect.get("id", ""), sim.content.get("enemies", {}).get(effect.get("id", ""), {})).get("name", "an ally"))
		"terrain": return "Shape the ground as %s" % String(effect.get("id", "terrain"))
		"move": return "Move up to %d tiles" % int(effect.get("distance", 1))
		"teleport": return "Teleport to a visible tile"
		"resource": return "%+d %s" % [int(effect.get("amount", 0)), String(effect.get("id", "resource"))]
		_: return "A tactical effect"

func _passive_modifier_label(modifier_id: String, value: float) -> String:
	match modifier_id:
		"armor_bonus": return "+%d armor" % int(round(value))
		"damage_reduction": return "%d%% damage reduction" % int(round(value * 100.0))
		"weapon_damage_bonus": return "+%d weapon damage" % int(round(value))
		"move_time_reduction": return "%d%% faster movement" % int(round(value * 100.0))
		"stamina_regen_bonus": return "+%d Stamina regeneration" % int(round(value))
		_: return "Improves %s" % modifier_id.replace("_", " ")

func _cost_text(costs: Dictionary) -> String:
	var values: Array = []
	for key in costs:
		values.append("%s %d" % [String(key).substr(0, 3).to_upper(), int(costs[key])])
	return " · ".join(values) if not values.is_empty() else "FREE"

func _wrap(text: String, width: int) -> Array:
	var result: Array = []
	var current := ""
	for word in text.split(" "):
		if current.length() + word.length() + 1 > width and current != "":
			result.append(current)
			current = word
		else:
			current = (current + " " + word).strip_edges()
	if current != "":
		result.append(current)
	return result

func _artifact_names() -> Array:
	var names: Array = []
	for artifact_id in sim.run.artifacts:
		names.append(sim.content.artifacts[artifact_id].name)
	return names

func _content_display_name(content_id: String) -> String:
	if sim.content.enemies.has(content_id): return sim.content.enemies[content_id].name
	if sim.content.abilities.has(content_id): return sim.content.abilities[content_id].name
	if sim.content.items.has(content_id): return sim.content.items[content_id].name
	if sim.content.artifacts.has(content_id): return sim.content.artifacts[content_id].name
	return content_id.capitalize()

func _prepare_capture_scenario() -> void:
	match capture_scenario:
		"exploration_chest", "exploration_book", "exploration_star":
			var player_cell: Vector2i = sim._pos(sim.get_player())
			var chest_cell := player_cell + Vector2i(2, 0)
			var book_cell := player_cell + Vector2i(0, 2)
			var star_cell := player_cell + Vector2i(1, 2)
			for cell in [chest_cell, book_cell, star_cell]: sim._set_grid(cell, "floor")
			sim.run.visible = sim._bool_grid(true)
			sim.run.explored = sim._bool_grid(true)
			sim.run.objects = [
				{"id": "qa_chest", "kind": "chest", "name": "Travel Chest", "pos": [chest_cell.x, chest_cell.y], "hp": 1, "max_hp": 1, "opened": false},
				{"id": "qa_book", "kind": "skill_book", "name": "Cinder Primer", "item_id": "cinder_primer", "pos": [book_cell.x, book_cell.y], "hp": 1, "max_hp": 1},
				{"id": "qa_star", "kind": "loot", "name": "Field Draught", "item_id": "healing_potion", "marker": "star", "pos": [star_cell.x, star_cell.y], "hp": 1, "max_hp": 1}
			]
			selected_object_index = 0 if capture_scenario == "exploration_chest" else 1 if capture_scenario == "exploration_book" else 2
		"map_locked":
			sim.run.stage_completed = false
			ui_state.active_lower_panel = "world_map"
		"map_ready":
			sim.run.stage_completed = true
			ui_state.active_lower_panel = "world_map"
		"map2_world":
			var map_one: Dictionary = sim.run.current_map.duplicate(true)
			map_one["completed"] = true
			map_one["current"] = false
			var map_two: Dictionary = sim._generate_map("2", String(map_one.get("theme_id", "")))
			map_two["completed"] = false
			map_two["current"] = true
			sim.run.map_history = [map_one, map_two]
			sim.run.current_map_index = 1
			sim.run.current_map = map_two
			sim.run.map_depth = "2"
			sim.run.maps_completed = "1"
			sim.run.stages_completed = "6"
			sim.run.stage_index = 0
			ui_state.active_lower_panel = "world_map"
			ui_state.lower_dock_expanded = true
			sim._new_stage(String(map_two.stage_templates[0]), false, true)
		"long_map_trail", "long_map_trail_early":
			var trail: Array = [sim.run.current_map.duplicate(true)]
			trail[0]["completed"] = true
			trail[0]["current"] = false
			var previous_theme := String(trail[0].get("theme_id", ""))
			for map_number in range(2, 15):
				var generated: Dictionary = sim._generate_map(str(map_number), previous_theme)
				if generated.is_empty(): break
				generated["completed"] = map_number < 14
				generated["current"] = map_number == 14
				trail.append(generated)
				previous_theme = String(generated.get("theme_id", ""))
			sim.run.map_history = trail
			sim.run.current_map_index = trail.size() - 1
			sim.run.current_map = trail.back().duplicate(true)
			sim.run.map_depth = String(trail.back().get("map_number", "14"))
			sim.run.maps_completed = str(trail.size() - 1)
			sim.run.stages_completed = str((trail.size() - 1) * 6 + 2)
			sim.run.stage_index = 2
			ui_state.active_lower_panel = "world_map"
			ui_state.lower_dock_expanded = true
			ui_state.map_history_start = 0 if capture_scenario == "long_map_trail_early" else -1
			sim._new_stage(String(sim.run.current_map.stage_templates[2]), false, true)
		"boss_stage":
			sim.run.stage_index = 5
			sim._new_stage(String(sim.run.current_map.stage_templates[0]), true, true)
		"map_reveal":
			sim.run.stage_index = 5
			sim._new_stage(String(sim.run.current_map.stage_templates[0]), true, true)
			for entity_id in sim.run.entities.keys():
				if sim.run.entities[entity_id].get("kind", "") == "boss":
					sim._on_death(String(entity_id), "The Mundane", "player")
					break
			if sim.reveal_next_map(): overlay = "map_reveal"
		"resume_run":
			page = "title"
			overlay = ""
			sim.start_run(912042, "jim")
			sim.save_run()
		"new_run_confirmation":
			page = "title"
			sim.start_run(912043, "jim")
			sim.save_run()
			overlay = "new_run_confirm"
		"run_summary", "run_summary_long":
			page = "outcome"
			overlay = ""
			sim.run.map_depth = "14"
			sim.run.maps_completed = "13"
			sim.run.stages_completed = "81"
			sim.run.enemies_defeated = "214"
			sim.run.bosses_defeated = "8"
			sim.run.level = 18
			sim.run.xp = 27
			sim.run.stage_index = 3
			sim.run.known.assign(sim.content.abilities.keys())
			sim.run.equipment.Weapon = "greatsword"
			sim.run.outcome = "defeat"
			run_summary_page = 1 if capture_scenario == "run_summary_long" else 0
		"long_map_depth":
			var huge_depth := "9".repeat(120)
			sim.run.map_depth = huge_depth
			sim.run.current_map["map_number"] = huge_depth
			var history: Array = sim.run.map_history
			history[0]["map_number"] = huge_depth
			sim.run.map_history = history
			ui_state.active_lower_panel = "world_map"
			ui_state.lower_dock_expanded = true
		"abilities_pyromancy", "ability_tooltip":
			ui_state.active_lower_panel = "character"
			ui_state.character_tab = "Abilities"
			ui_state.selected_ability_category = "pyromancy"
			ui_state.selected_ability_id = "fireball"
		"tooltip_long":
			ui_state.active_lower_panel = "character"
			ui_state.character_tab = "Abilities"
			ui_state.selected_ability_category = "summoning"
			ui_state.selected_ability_id = "demonic_gateway"
			ui_state.ability_page = 0
		"abilities_arcane":
			ui_state.active_lower_panel = "character"
			ui_state.character_tab = "Abilities"
			ui_state.selected_ability_category = "arcane"
			ui_state.selected_ability_id = "blink"
		"abilities_cleave":
			ui_state.active_lower_panel = "character"
			ui_state.lower_dock_expanded = true
			ui_state.character_tab = "Abilities"
			ui_state.selected_ability_category = "heavy_weapons"
			ui_state.selected_ability_id = "cleave"
		"passives":
			ui_state.active_lower_panel = "character"
			ui_state.lower_dock_expanded = true
			ui_state.character_tab = "Passives"
			ui_state.selected_ability_id = "iron_resolve"
		"known":
			ui_state.active_lower_panel = "character"
			ui_state.lower_dock_expanded = true
			ui_state.character_tab = "Known"
			ui_state.selected_ability_id = "cleave"
		"mobile_character_no_effects":
			ui_state.active_lower_panel = "character"
			ui_state.lower_dock_expanded = true
			ui_state.character_tab = "Character"
		"mobile_character_effects":
			ui_state.active_lower_panel = "character"
			ui_state.lower_dock_expanded = true
			ui_state.character_tab = "Character"
			sim.run.entities.player.statuses = {
				"Haste": {"stacks": 1, "duration": 3},
				"Guard": {"stacks": 1, "duration": 2},
				"Empowered": {"stacks": 1, "duration": 3}
			}
		"equipment_desktop":
			ui_state.active_lower_panel = "inventory"
			ui_state.inventory_tab = "Equipment"
			ui_state.selected_equipment_slot = "Body"
			sim.run.inventory.append("scale_armor")
			ui_state.selected_inventory_index = sim.run.inventory.size() - 1
		"equipment_head":
			ui_state.active_lower_panel = "inventory"
			ui_state.inventory_tab = "Equipment"
			ui_state.selected_equipment_slot = "Head"
			ui_state.selected_inventory_index = -1
		"equipment_weapon":
			ui_state.active_lower_panel = "inventory"
			ui_state.inventory_tab = "Equipment"
			ui_state.selected_equipment_slot = "Weapon"
			sim.run.inventory.append("dagger")
			sim.run.inventory.append("greatsword")
			ui_state.selected_inventory_index = sim.run.inventory.find("greatsword")
		"targeting_attack":
			for entity_id in sim.run.entities.keys():
				if entity_id != "player": sim.run.entities[entity_id].alive = false
			sim.run.equipment.Weapon = "bow"
			var origin: Vector2i = sim._pos(sim.get_player())
			for offset in range(1, 5): sim._set_grid(origin + Vector2i(offset, 0), "floor")
			var target_position := origin + Vector2i(4, 0)
			var target_id := sim._spawn_enemy("goblin", target_position, false)
			if target_id != "": sim.run.entities[target_id].next_time = int(sim.get_player().next_time) + 100000
			sim._update_vision()
		"selected_enemy":
			selected_enemy = _capture_adjacent_enemy()
		"assign_ability":
			var assignable_ability := "arcane_bolt"
			if not sim.run.known.has(assignable_ability): sim.run.known.append(assignable_ability)
			ui_state.selected_ability_id = assignable_ability
			ui_state.character_tab = "Known"
			ui_state.ability_page = int(sim.run.known.find(assignable_ability) / 4)
			quickbar_assign_mode = true
			quickbar_pending = {"type": "ability", "id": assignable_ability}
		"assign_item":
			ui_state.selected_inventory_index = 0
			ui_state.inventory_tab = "Inventory"
			quickbar_assign_mode = true
			quickbar_pending = {"type": "item", "id": String(sim.run.inventory[0]) if not sim.run.inventory.is_empty() else "healing_potion"}
		"quickbar_customized":
			var actives: Array = sim.get_available_abilities()
			var items: Array[String] = ["healing_potion", "mana_potion", "bomb", "fireball_scroll"]
			var slots: Array = []
			for index in range(4):
				slots.append({"type": "ability", "id": String(actives[index % actives.size()])})
			for item_id in items:
				slots.append({"type": "item", "id": item_id})
			sim.run.quickbar = slots
			sim.run.quickbar_customized = true
		"quickbar_empty":
			sim.run.inventory.erase("healing_potion")
			sim.run.quickbar[5] = {"type": "item", "id": "healing_potion"}
		"destination_popup":
			sim.run.stage_completed = true
		"map_after_choice":
			ui_state.active_lower_panel = "world_map"
			var selected_destination := String(sim.run.get("route_choices", [""])[0])
			sim.run.stage_completed = true
			if selected_destination != "": sim.choose_route(selected_destination)
		"map_late_5", "map_final_6":
			ui_state.active_lower_panel = "world_map"
			for _transition in range(4):
				sim.run.stage_completed = true
				var next_destination := String(sim.run.get("route_choices", [""])[0])
				if next_destination == "" or not sim.choose_route(next_destination):
					break
			if capture_scenario == "map_final_6":
				sim.run.stage_completed = true
				sim.start_boss()
		"full_inventory":
			var item_ids: Array = sim.content.items.keys()
			while sim.run.inventory.size() < 30:
				sim.run.inventory.append(String(item_ids[(sim.run.inventory.size() - 4) % item_ids.size()]))
			ui_state.selected_inventory_index = 29
		"selected_equipment":
			sim.run.inventory.append("scale_armor")
			ui_state.selected_inventory_index = sim.run.inventory.size() - 1
		"selected_consumable":
			ui_state.selected_inventory_index = 0
		"populated_history", "combat_history":
			var capture_events: Array = [
				{"sequence": 1, "type": "Move", "actor_name": "The Bloodletter", "target_name": "", "details": {"from": [12, 8], "to": [13, 8]}},
				{"sequence": 2, "type": "Attack", "actor_name": "The Bloodletter", "target_name": "Skeleton", "details": {"style": "melee"}},
				{"sequence": 3, "type": "Damage", "actor_name": "The Bloodletter", "target_name": "Skeleton", "details": {"amount": 12, "damage_type": "Slashing"}},
				{"sequence": 4, "type": "KillCredit", "actor_name": "The Bloodletter", "target_name": "Skeleton", "details": {"xp": 12, "credit": "full"}},
				{"sequence": 5, "type": "StatusApplied", "actor_name": "The Bloodletter", "target_name": "Rotwalker", "details": {"status": "Burning"}},
				{"sequence": 6, "type": "LevelUp", "actor_name": "The Bloodletter", "target_name": "", "details": {"level": 2, "skill_points": 1, "max_hp": 2, "attribute": "Willpower", "attribute_value": 15}}
			]
			sim.run.combat_history = capture_events
			if capture_scenario == "combat_history":
				overlay = "combat_history"
		"enemy_action", "fast_action", "instant_action":
			if capture_scenario == "fast_action": playback_mode = "Fast"
			if capture_scenario == "instant_action": playback_mode = "Instant"
			var result := _capture_enemy_action()
			if capture_scenario == "instant_action":
				_commit_action(result)
			else:
				_commit_action(result)
				_focus_capture_event("Attack")
		"damage_action", "level_up":
			if capture_scenario == "level_up":
				var target_id := _capture_adjacent_enemy()
				if target_id != "":
					sim.run.xp = 34
					sim.run.entities[target_id].hp = 1
					sim.run.entities[target_id].max_hp = 1
					var target_pos: Vector2i = sim._pos(sim.run.entities[target_id])
					var result: Dictionary = sim.act({"type": "attack", "target": [target_pos.x, target_pos.y]})
					_commit_action(result)
					_focus_capture_event("LevelUp")
			else:
				var damage_result := _capture_enemy_action()
				_commit_action(damage_result)
				_focus_capture_event("Damage")
		"summon":
			var player_position: Array = sim.get_player().pos
			var summon_result: Dictionary = sim.act({"type": "cast", "id": "phantom_blade", "target": player_position})
			_commit_action(summon_result)
			_focus_capture_event("Summon")
	queue_redraw()

func _capture_adjacent_enemy() -> String:
	var player_position := sim._pos(sim.get_player())
	var target_cell := Vector2i(-1, -1)
	for direction in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		var candidate: Vector2i = player_position + direction
		if sim._inside(candidate) and sim._object_index_at(candidate) < 0 and sim._occupant(candidate) == "":
			target_cell = candidate
			break
	if target_cell.x < 0:
		return ""
	sim._set_grid(target_cell, "floor")
	var target_id := ""
	for entity_id in sim.run.entities:
		var entity: Dictionary = sim.run.entities[entity_id]
		if entity_id != "player" and entity.get("alive", true) and entity.get("kind", "") == "enemy" and int(entity.get("footprint", 1)) == 1:
			target_id = String(entity_id)
			break
	if target_id == "":
		target_id = sim._spawn_enemy("skeleton", target_cell, false)
	else:
		sim.run.entities[target_id].pos = [target_cell.x, target_cell.y]
	return target_id

func _capture_enemy_action() -> Dictionary:
	var target_id := _capture_adjacent_enemy()
	if target_id == "":
		return {"ok": false, "message": "No visible enemy for this capture."}
	return sim.act({"type": "wait"})

func _focus_capture_event(event_type: String) -> void:
	if not playback_active:
		return
	var safety := 0
	while playback_active and String(current_presentation_event.get("type", "")) != event_type and safety < playback_events.size():
		safety += 1
		current_presentation_event = {}
		_start_next_presentation_event()
		if current_presentation_event.is_empty():
			_finish_presentation()

func _codex_count() -> int:
	var total := 0
	for category in sim.codex:
		total += sim.codex[category].size()
	return total

func _capture_after_draw() -> void:
	var original_viewport: Viewport = get_viewport()
	var offscreen := SubViewport.new()
	offscreen.name = "VisualCaptureViewport"
	offscreen.size = capture_size
	offscreen.transparent_bg = false
	offscreen.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	offscreen.world_2d = original_viewport.world_2d
	var parent := get_parent()
	parent.remove_child(self)
	parent.add_child(offscreen)
	offscreen.add_child(self)
	queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := offscreen.get_texture().get_image()
	var absolute_path := ProjectSettings.globalize_path(capture_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var error := image.save_png(absolute_path)
	if error != OK:
		push_error("Could not save visual QA image: %s" % error_string(error))
	get_tree().quit()
