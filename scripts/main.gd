extends Control

const SimScript = preload("res://scripts/game_sim.gd")
const LOGICAL_SIZE := Vector2(1440, 810)
const BASE_BOARD_ORIGIN := Vector2(250, 62)
const BASE_TILE := 35.0
const WIDE_TILE := 35.0
const WIDE_LAYOUT_MIN_WIDTH := 1550.0
const TOUCH_TARGET := 54.0
const POINTER_DRAG_SLOP := 18.0

var sim: ArcanistSim
var page := "title"
var overlay := ""
var selected_character := "jim"
var selected_enemy := ""
var selected_inventory_index := -1
var selected_object_index := -1
var selected_ability := ""
var target_mode := ""
var selected_book_abilities: Array = []
var codex_book_id := ""
var selected_ward := ""
var selected_web_ability := ""
var ability_filter := "All"
var ability_filter_page := 0
var palette_filter := "All"
var palette_page := 0
var quickbar_page := 0
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
var capture_full_web := false
var screen_size := LOGICAL_SIZE
var draw_scale := 1.0
var draw_offset := Vector2.ZERO

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
				page = "battle"
				sim.start_run(912041, "mara")
				sim.save_run()
				overlay = capture_overlay
				match capture_overlay:
					"inventory": selected_inventory_index = 0
					"map": sim.run.route_choices = ["graveyard", "flooded_ruins"]
					"rewards":
						sim.run.stage_completed = true
						sim.run.reward_choices = [{"type": "artifact", "id": "copper_hare", "claimed": false}, {"type": "item", "id": "healing_potion", "claimed": false}]
				if capture_book != "" and sim.content.items.has(capture_book):
					sim.run.inventory.append(capture_book)
					selected_inventory_index = sim.run.inventory.size() - 1
					codex_book_id = capture_book
					if capture_overlay == "codex_book":
						var captured_book_index: int = sim.run.inventory.size() - 1
						var book_options: Dictionary = sim.get_spellbook_options(captured_book_index)
						var book_choices: Array = [0] if book_options.get("mode") == "choose" else []
						sim.study_spellbook(captured_book_index, book_choices)
				if capture_full_web:
					sim.run.disciplines = sim.content.progression.disciplines.duplicate()
					sim.run.schools = ["Fire", "Frost", "Storm", "Earth", "Nature", "Arcane", "Holy", "Shadow", "Necromancy", "Summoning", "Spirit", "Blood"]
					sim.run.skill_points = 12
					for ability_id in ["firebolt", "fireball", "frostbolt", "lightning_bolt", "aimed_shot", "parry", "dagger_flurry", "lunge"]:
						if not sim.run.known.has(ability_id): sim.run.known.append(ability_id)
					for book_id in ["cinder_primer", "storm_ledger", "lesser_key_of_ash"]:
						sim.run.inventory.append(book_id)
						var book_index: int = sim.run.inventory.size() - 1
						var book_options: Dictionary = sim.get_spellbook_options(book_index)
						var book_choices: Array = [0] if book_options.get("mode") == "choose" else []
						sim.study_spellbook(book_index, book_choices)
					selected_web_ability = "storm_arrow"
				if capture_overlay == "action_palette":
					var capture_abilities: Array = sim.get_available_abilities()
					selected_ability = String(capture_abilities[0]) if not capture_abilities.is_empty() else ""
				if capture_target != "":
					target_mode = capture_target
				if capture_overlay == "abilities":
					if selected_web_ability == "":
						selected_web_ability = String(sim.run.known.back()) if not sim.run.known.is_empty() else ""
					ability_filter = String(sim.content.abilities.get(selected_web_ability, {}).get("school", "All"))
					web_zoom = 0.86
					_center_web_on(selected_web_ability)
					if capture_web_pan_provided:
						web_pan += capture_web_pan
	if not capture_requested:
		if sim.has_saved_run():
			page = "title"
	if capture_requested:
		OS.low_processor_usage_mode = false
		call_deferred("_capture_after_draw")
	queue_redraw()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST]:
		mouse_press_active = false
		touch_index = -1
		press_position = Vector2(-1, -1)
		press_current_position = Vector2(-1, -1)
		_save_active_run()
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
	if OS.get_name() == "Android":
		var now := Time.get_ticks_msec()
		if now - last_android_back_msec < 400:
			return
		last_android_back_msec = now
	if target_mode != "":
		_cancel_targeting()
	elif overlay == "exit_confirm":
		overlay = "pause"
	elif overlay == "pause":
		overlay = "exit_confirm"
	elif overlay == "codex_book":
		overlay = "codex"
	elif overlay != "":
		overlay = ""
		selected_inventory_index = -1
	elif page == "battle":
		overlay = "pause"
	elif page == "outcome":
		page = "title"
	else:
		get_tree().quit()
	queue_redraw()

func _process(_delta: float) -> void:
	if notice != "" and Time.get_ticks_msec() > notice_until:
		notice = ""
		set_process(false)
		queue_redraw()

func _draw() -> void:
	active_hits.clear()
	var viewport := get_viewport_rect().size
	var layout := _calculate_layout(viewport, _safe_area_for_viewport(viewport))
	screen_size = layout.size
	draw_scale = layout.scale
	draw_offset = layout.offset
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(Vector2.ZERO, viewport), COLORS.ink)
	draw_set_transform(draw_offset, 0.0, Vector2(draw_scale, draw_scale))
	draw_rect(Rect2(Vector2.ZERO, screen_size), COLORS.ink)
	_draw_backdrop()
	var hits_start := active_hits.size()
	var centered_content := page != "battle" and screen_size.x > LOGICAL_SIZE.x
	if centered_content:
		draw_set_transform(draw_offset + Vector2((screen_size.x - LOGICAL_SIZE.x) * 0.5 * draw_scale, 0.0), 0.0, Vector2(draw_scale, draw_scale))
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
	if centered_content:
		_shift_active_hits(hits_start, (screen_size.x - LOGICAL_SIZE.x) * 0.5)
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
	characters.sort_custom(func(a: String, b: String) -> bool: return int(sim.content.characters[a].get("selection_order", 99)) < int(sim.content.characters[b].get("selection_order", 99)))
	for character_index in range(characters.size()):
		var character_id: String = characters[character_index]
		var definition: Dictionary = sim.content.characters[character_id]
		var col := character_index % 3
		var row := int(character_index / 3)
		var rect := Rect2(70 + col * 437, 230 + row * 208, 414, 196)
		var active: bool = character_id == selected_character
		_draw_panel(rect, "", COLORS.gold if active else COLORS.line_soft)
		_draw_label(String(definition.name), rect.position.x + 16, rect.position.y + 28, 16, COLORS.text)
		_draw_label(String(definition.subtitle), rect.position.x + 16, rect.position.y + 49, 11, COLORS.muted)
		_draw_label("%s  ·  %s" % [definition.discipline, sim.content.weapons[definition.weapon].name], rect.position.x + 16, rect.position.y + 80, 12, COLORS.cyan)
		_draw_label("AURA  ·  %s" % ("Open progression" if definition.aura == "None" else definition.aura), rect.position.x + 16, rect.position.y + 105, 11, COLORS.gold)
		var identities: Array = definition.get("schools", []).duplicate()
		identities.append_array(definition.get("disciplines", []))
		_draw_label(_fit_text("BUILD  ·  " + "  /  ".join(identities), rect.size.x - 30, 11), rect.position.x + 16, rect.position.y + 130, 11, COLORS.muted)
		_draw_label("HP %d    MANA %d    STA %d" % [definition.resources.Health[1], definition.resources.Mana[1], definition.resources.Stamina[1]], rect.position.x + 16, rect.position.y + 151, 11, COLORS.text)
		active_hits.append({"rect": rect, "action": {"type": "select_character", "id": character_id}})
		_draw_button(Rect2(rect.position.x + 15, rect.position.y + 165, rect.size.x - 30, 25), "SELECTED" if active else "CHOOSE", {"type": "select_character", "id": character_id}, active, 10)
	_draw_button(Rect2(481, 690, 310, 70), "BEGIN THE MARCH", {"type": "start"}, true, 18)
	if sim.has_saved_run():
		_draw_button(Rect2(805, 690, 235, 70), "RESUME RUN", {"type": "resume"}, false, 17)
	_draw_button(Rect2(1053, 690, 310, 70), "CODEX  ·  %d discoveries" % _codex_count(), {"type": "title_codex"}, false, 16)
	_draw_label("Landscape first  ·  Touch or mouse  ·  No timer while you decide", 56, 745, 13, COLORS.muted)
	_draw_corner_marks(Rect2(47, 215, 1346, 450))

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
	if notice != "":
		_draw_toast(notice)

func _draw_player_card() -> void:
	var player: Dictionary = sim.get_player()
	var rect := Rect2(18, 18, 216, 444)
	_draw_panel(rect, "", COLORS.line)
	var level_label := "LV %d" % sim.run.get("level", 1)
	var level_width := ThemeDB.fallback_font.get_string_size(level_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13).x
	var name_width := 190.0 - level_width - 10.0
	_draw_label(_fit_text(String(player.get("name", "Adventurer")), name_width, 15), 31, 47, 15, COLORS.text)
	_draw_label(level_label, 221, 47, 13, COLORS.gold, HORIZONTAL_ALIGNMENT_RIGHT)
	_draw_label("%s  ·  %d / %d" % [sim.get_stage_name(), sim.run.get("stage_index", 0) + 1, 6], 31, 70, 10, COLORS.muted)
	_draw_bar(Rect2(31, 84, 190, 22), "HP", player.hp, player.max_hp, COLORS.red)
	var mana: Array = player.resources.Mana
	_draw_bar(Rect2(31, 111, 190, 21), "MP", mana[0], mana[1], COLORS.blue)
	var stamina: Array = player.resources.Stamina
	_draw_bar(Rect2(31, 137, 190, 21), "STA", stamina[0], stamina[1], COLORS.green)
	var blood: Array = player.resources.get("Blood", [0, 0])
	if int(blood[1]) > 0:
		_draw_bar(Rect2(31, 163, 190, 21), "BLD", blood[0], blood[1], COLORS.blood)
	var command: Array = player.resources.Command
	_draw_bar(Rect2(31, 189, 190, 21), "CMD", command[0], command[1], COLORS.purple)
	_draw_line(31, 220, 221, 220, COLORS.line_soft)
	var attributes: Dictionary = sim.run.attributes
	var names: Array = ["Might", "Dexterity", "Vitality", "Intelligence", "Willpower", "Perception"]
	for i in range(names.size()):
		var y := 242 + i * 25
		_draw_label(String(names[i]), 31, y, 12, COLORS.muted)
		_draw_label(str(attributes.get(names[i], 10)), 215, y, 13, COLORS.text, HORIZONTAL_ALIGNMENT_RIGHT)
	_draw_line(31, 398, 221, 398, COLORS.line_soft)
	_draw_label("ACTIVE EFFECTS", 31, 420, 11, COLORS.gold)
	var status_index := 0
	for status_id in player.get("statuses", {}):
		if status_index >= 4:
			break
		var status: Dictionary = player.statuses[status_id]
		_draw_label("✦  %s  (%d)" % [status_id, status.stacks], 34, 445 + status_index * 22, 12, COLORS.cyan if status_id in ["Haste", "Empowered"] else COLORS.orange)
		status_index += 1
	if status_index == 0:
		_draw_label("No active effects", 34, 446, 12, COLORS.muted)

func _draw_board() -> void:
	var origin := _board_origin()
	var tile := _tile_size()
	var board_panel_width := ArcanistSim.WIDTH * tile + 17.0
	var board_panel_height := ArcanistSim.HEIGHT * tile + 20.0
	_draw_panel(Rect2(origin.x - 8.0, 52, board_panel_width, board_panel_height), "", COLORS.line)
	var grid: Array = sim.run.grid
	var visible: Array = sim.run.visible
	var explored: Array = sim.run.explored
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
	_draw_targetable_cells(origin, tile)
	for object in sim.run.objects:
		if int(object.get("hp", 1)) <= 0:
			continue
		var cell := Vector2i(int(object.pos[0]), int(object.pos[1]))
		if not sim._cell_visible(cell):
			continue
		var center := _cell_center(cell)
		if object.get("kind") == "exit":
			draw_circle(center, 11, Color(0.2, 0.62, 0.9, 0.4))
			_draw_label("⇢", center.x, center.y + 7, 19, COLORS.cyan, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			draw_circle(center, 12, Color(0.59, 0.14, 0.2, 0.3))
			_draw_label("◆", center.x, center.y + 6, 15, COLORS.red, HORIZONTAL_ALIGNMENT_CENTER)
	for corpse in sim.run.corpses:
		var cell: Vector2i = Vector2i(int(corpse.pos[0]), int(corpse.pos[1]))
		if sim._cell_visible(cell) and sim._occupant(cell) == "":
			_draw_label("×", _cell_center(cell).x, _cell_center(cell).y + 5, 11, Color("#9b7378"), HORIZONTAL_ALIGNMENT_CENTER)
	for entity in sim.get_visible_entities():
		var cell: Vector2i = sim._pos(entity)
		var size := int(entity.get("footprint", 1))
		var entity_rect := Rect2(origin + Vector2(cell.x * tile + 3, cell.y * tile + 3), Vector2(tile * size - 7, tile * size - 7))
		var presentation: Dictionary = sim.get_entity_presentation(String(entity.id))
		var entity_color := _entity_presentation_color(String(presentation.color_key))
		if entity.id == selected_enemy:
			draw_rect(entity_rect.grow(2), COLORS.gold, false, 2)
		if target_mode != "" and entity.id != "player" and sim._is_hostile("player", entity.id) and _entity_is_legal_target(entity):
			draw_rect(entity_rect.grow(1), Color(0.9, 0.24, 0.3, 0.22), true)
			draw_rect(entity_rect.grow(1), COLORS.green, false, 2)
		var glyph := String(presentation.symbol)
		var center := entity_rect.get_center()
		_draw_label(glyph, center.x, center.y + 7, 20 if size == 1 else 26, entity_color, HORIZONTAL_ALIGNMENT_CENTER)
		if entity.id != "player":
			var hp_fraction := clampf(float(entity.hp) / maxf(1.0, float(entity.max_hp)), 0.0, 1.0)
			draw_rect(Rect2(entity_rect.position.x, entity_rect.end.y + 1, entity_rect.size.x, 3), Color("#151c22"))
			draw_rect(Rect2(entity_rect.position.x, entity_rect.end.y + 1, entity_rect.size.x * hp_fraction, 3), COLORS.red if entity.kind != "summon" else COLORS.cyan)
	if target_mode != "":
		_draw_label("TARGETING  ·  %s  ·  tap a highlighted target; tap the action again to cancel" % _target_action_name(), 260, 45, 10, COLORS.gold)
	else:
		_draw_label("%s  ·  %s" % [sim.get_stage_name().to_upper(), sim.get_objective_text()], 260, 45, 12, COLORS.text)
	if target_mode != "" and _point_in_board(press_current_position):
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

func _draw_timeline() -> void:
	var panel_x := 1150.0
	var panel_width := screen_size.x - panel_x - 18.0
	var panel_rect := Rect2(panel_x, 18, panel_width, 227)
	_draw_panel(panel_rect, "TURN TIMELINE", COLORS.line)
	var entries: Array = sim.get_timeline(6)
	var label_x := panel_x + 16.0
	var time_x := panel_rect.end.x - 15.0
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var y := 61 + i * 27
		var color := _entity_presentation_color(String(entry.color_key))
		_draw_label(String(entry.symbol), label_x, y, 14, color)
		_draw_label(String(entry.name).substr(0, 28 if _is_wide_layout() else 19), label_x + 24, y, 12, COLORS.text)
		_draw_label("NOW" if entry.id == "player" else str(int(entry.time) - int(sim.get_player().next_time)), time_x, y, 11, COLORS.gold if entry.id == "player" else COLORS.muted, HORIZONTAL_ALIGNMENT_RIGHT)
		active_hits.append({"rect": _touch_hit_rect(Rect2(panel_x + 8, y - 18, panel_width - 16, 24)), "action": {"type": "inspect_entity", "id": entry.id}})
	_draw_line(label_x, 223, time_x, 223, COLORS.line_soft)
	_draw_label("NO REAL-TIME TIMER", label_x, 239, 10, COLORS.muted)

func _draw_inspection_card() -> void:
	var panel_x := 1150.0
	var panel_width := screen_size.x - panel_x - 18.0
	var rect := Rect2(panel_x, 258, panel_width, 360)
	var content_x := panel_x + 16.0
	var content_width := panel_width - 32.0
	_draw_panel(rect, "FIELD INTELLIGENCE", COLORS.line)
	var enemy: Dictionary = sim.run.entities.get(selected_enemy, {})
	var object: Dictionary = _selected_object()
	if not object.is_empty():
		_draw_label(String(object.get("name", "Field object")), content_x, 300, 18, COLORS.cyan if object.get("kind") == "exit" else COLORS.gold)
		_draw_label("%s  ·  %d / %d HP" % [String(object.get("kind", "object")).capitalize(), int(object.get("hp", 1)), int(object.get("max_hp", 1))], content_x, 334, 13, COLORS.text)
		var object_cell := Vector2i(int(object.pos[0]), int(object.pos[1]))
		_draw_label("Distance  ·  %d tiles" % sim._dist(sim._pos(sim.get_player()), object_cell), content_x, 364, 13, COLORS.muted)
		var object_action := {"type": "interact"} if object.get("kind") == "exit" else {"type": "target_object"}
		var object_label := "INTERACT" if object.get("kind") == "exit" else "TARGET WARD"
		_draw_button(Rect2(content_x, 408, content_width, TOUCH_TARGET), object_label, object_action, false, 13)
	elif enemy.is_empty() or not enemy.get("alive", true) or not sim._cell_visible(sim._pos(enemy)):
		_draw_label("OBJECTIVE", content_x, 300, 11, COLORS.gold)
		var objective_lines := _wrap(sim.get_objective_text(), 31)
		for i in range(objective_lines.size()):
			_draw_label(objective_lines[i], content_x, 328 + i * 19, 14, COLORS.text)
		_draw_label("ENCOUNTER", content_x, 389, 11, COLORS.gold)
		_draw_label("%d / 6" % [int(sim.run.stage_index) + 1], content_x, 415, 14, COLORS.text)
		_draw_label("%d hostiles remain" % sim._hostile_count(), content_x, 439, 13, COLORS.muted)
		_draw_label("%d XP  ·  level %d" % [sim.run.xp, sim.run.level], content_x, 464, 13, COLORS.muted)
		_draw_label("RECENT EVENTS", content_x, 502, 11, COLORS.gold)
		var logs: Array = sim.run.get("log", [])
		for i in range(mini(4, logs.size())):
			_draw_label(String(logs[logs.size() - 1 - i]).substr(0, 32 if not _is_wide_layout() else 64), content_x, 526 + i * 20, 10, COLORS.muted)
	else:
		_draw_label(String(enemy.get("name", "Creature")), content_x, 300, 18, COLORS.red if enemy.faction in ["Undead", "Demons"] else COLORS.gold)
		_draw_label("HP  %d / %d" % [enemy.hp, enemy.max_hp], content_x, 333, 14, COLORS.text)
		draw_rect(Rect2(content_x, 345, content_width, 8), Color("#202a30"))
		draw_rect(Rect2(content_x, 345, content_width * clampf(float(enemy.hp) / maxf(1.0, float(enemy.max_hp)), 0.0, 1.0), 8), COLORS.red)
		_draw_label("%s  ·  %s" % ["Large 2×2" if int(enemy.footprint) > 1 else "Standard", String(enemy.faction)], content_x, 379, 13, COLORS.muted)
		_draw_label("Attack  %d  ·  %s" % [enemy.damage, enemy.damage_type], content_x, 404, 13, COLORS.text)
		for damage_type in enemy.get("resist", {}):
			_draw_label("Resist  %s  %d%%" % [damage_type, int(float(enemy.resist[damage_type]) * 100)], content_x, 431, 12, COLORS.cyan)
		if enemy.get("resist", {}).is_empty():
			_draw_label("No known resistances", content_x, 431, 12, COLORS.muted)
		var status_line := "Clear"
		if not enemy.get("statuses", {}).is_empty():
			status_line = ", ".join(enemy.statuses.keys())
		_draw_label("Effects  %s" % status_line, content_x, 458, 12, COLORS.orange if status_line != "Clear" else COLORS.muted)
		_draw_button(Rect2(content_x, 478, content_width, TOUCH_TARGET), "INSPECT CREATURE", {"type": "inspect", "id": selected_enemy}, false, 13)
	var transition_ready: bool = sim.run.get("stage_completed", false)
	var transition_action := {"type": "next_stage"} if transition_ready else {"type": "overlay", "id": "map"}
	_draw_button(Rect2(content_x, 550, content_width, TOUCH_TARGET), "%s" % ("NEXT STAGE" if transition_ready and sim.run.get("stage_index", 0) < 5 else "VICTORY" if sim.run.get("outcome") == "victory" else "ROUTE MAP"), transition_action, transition_ready, 15)

func _draw_side_controls() -> void:
	_draw_label("GOAL  ·  REACH THE TYRANT", 22, 484, 11, COLORS.gold)
	_draw_label("PATH  %d / 5 ENCOUNTERS" % mini(int(sim.run.get("stage_index", 0)), 5), 22, 504, 10, COLORS.muted)
	_draw_dpad_button(Rect2(98, 510, TOUCH_TARGET, TOUCH_TARGET), "▲", Vector2i(0, -1))
	_draw_dpad_button(Rect2(38, 570, TOUCH_TARGET, TOUCH_TARGET), "◀", Vector2i(-1, 0))
	_draw_dpad_button(Rect2(98, 570, TOUCH_TARGET, TOUCH_TARGET), "▼", Vector2i(0, 1))
	_draw_dpad_button(Rect2(158, 570, TOUCH_TARGET, TOUCH_TARGET), "▶", Vector2i(1, 0))

func _draw_action_bar() -> void:
	_draw_panel(Rect2(18, 644, screen_size.x - 36, 148), "", COLORS.line)
	var targeting_text := "TAP A TILE TO MOVE  ·  HOLD TO INSPECT  ·  WAITING NEVER ADVANCES TIME"
	if target_mode != "":
		targeting_text = "TARGETING  ·  %s  ·  TAP THE SAME ACTION AGAIN, BACK OR × TO CANCEL" % _target_action_name()
	_draw_label(targeting_text, 32, 661, 9, COLORS.gold if target_mode != "" else COLORS.muted)
	var y := 671.0
	var h := 73.0
	var x := 28.0
	var gap := 5.0
	_draw_action_slot(Rect2(x, y, 60, h), _ui_glyph("move"), "MOVE", "100", {"type": "target_mode", "mode": "move"}, target_mode == "move", COLORS.cyan)
	x += 60 + gap
	var weapon_id: String = sim.run.equipment.get("Weapon", "sword")
	var weapon: Dictionary = sim.content.weapons.get(weapon_id, sim.content.weapons.get("sword", {}))
	var weapon_meta := "%d · %d" % [int(weapon.get("time", 100)), int(weapon.get("stamina", 0))]
	_draw_action_slot(Rect2(x, y, 60, h), _ui_glyph("attack"), "ATTACK", weapon_meta, {"type": "target_mode", "mode": "attack"}, target_mode == "attack", COLORS.gold)
	x += 60 + gap
	var known: Array = sim.get_available_abilities()
	var page_count := maxi(1, int(ceil(float(known.size()) / 6.0)))
	quickbar_page = clampi(quickbar_page, 0, page_count - 1)
	var first_index := quickbar_page * 6
	var ability_slot_count := mini(first_index + 6, known.size()) - first_index
	var quick_items: Array = ["healing_potion", "mana_potion", "bomb", "fireball_scroll"]
	var visible_item_count := 0
	for quick_item_id in quick_items:
		if sim.run.inventory.has(quick_item_id):
			visible_item_count += 1
	var fixed_width := 2 * (60 + gap)
	if page_count > 1: fixed_width += 50 + gap
	fixed_width += ability_slot_count * (60 + gap)
	if page_count > 1: fixed_width += 50 + gap
	fixed_width += 60 + gap + visible_item_count * (54 + gap) + 5 + 4 * (54 + 4) + 3 + 78 + 5
	if target_mode != "": fixed_width += 50
	var available_width := screen_size.x - 56
	var flex_group_count := 4 if target_mode != "" else 3
	var flex_gap := maxf(0.0, (available_width - fixed_width) / float(flex_group_count))
	if page_count > 1:
		_draw_action_slot(Rect2(x, y, 50, h), _ui_glyph("previous"), "PREV", "%d/%d" % [quickbar_page + 1, page_count], {"type": "quickbar_page", "delta": -1}, false, COLORS.line)
		x += 50 + gap
	for i in range(first_index, mini(first_index + 6, known.size())):
		var ability_id: String = known[i]
		var ability: Dictionary = sim.content.abilities[ability_id]
		var color := _school_color(String(ability.school))
		var affordable := sim._can_pay(ability.get("costs", {}))
		var cost_text := _cost_text(ability.get("costs", {}))
		_draw_action_slot(Rect2(x, y, 60, h), _ability_glyph(ability), _fit_text(String(ability.name), 55, 8), cost_text, {"type": "ability", "id": ability_id}, target_mode == ability_id, COLORS.red if not affordable else color)
		x += 60 + gap
	if page_count > 1:
		_draw_action_slot(Rect2(x, y, 50, h), _ui_glyph("next"), "NEXT", "%d/%d" % [quickbar_page + 1, page_count], {"type": "quickbar_page", "delta": 1}, false, COLORS.line)
		x += 50 + gap
	_draw_action_slot(Rect2(x, y, 60, h), _ui_glyph("more"), "MORE", "%d known" % known.size(), {"type": "open_action_palette"}, false, COLORS.cyan)
	x += 60 + gap
	x += flex_gap
	for item_id in quick_items:
		var item_index: int = sim.run.inventory.find(item_id)
		if item_index < 0:
			continue
		var glyph := _item_glyph(item_id, sim.content.items[item_id])
		var quick_name := "HEAL" if item_id == "healing_potion" else "MANA" if item_id == "mana_potion" else "BOMB" if item_id == "bomb" else "SCROLL"
		_draw_action_slot(Rect2(x, y, 54, h), glyph, quick_name, "USE", {"type": "quick_item", "index": item_index}, target_mode == "item:%d" % item_index, COLORS.orange)
		x += 54 + gap
	x += 5 + flex_gap
	for utility in [["pack", "PACK", "inventory", COLORS.gold], ["web", "WEB", "abilities", COLORS.cyan], ["map", "MAP", "map", COLORS.green], ["codex", "CODEX", "codex", COLORS.purple]]:
		_draw_utility_slot(Rect2(x, y, 54, h), String(utility[0]), String(utility[1]), {"type": "overlay", "id": String(utility[2])}, Color(utility[3]))
		x += 54 + 4
	x += 3 + flex_gap
	_draw_action_slot(Rect2(x, y, 78, h), _ui_glyph("wait"), "END TURN", "100", {"type": "wait"}, false, COLORS.green)
	x += 78 + 5
	if target_mode != "":
		x += flex_gap
		_draw_action_slot(Rect2(x, y, 50, h), _ui_glyph("cancel"), "CANCEL", "BACK", {"type": "cancel_target"}, true, COLORS.gold)

func _draw_action_slot(rect: Rect2, glyph: String, label: String, detail: String, action: Dictionary, active: bool, accent: Color) -> void:
	var fill := Color("#18352d") if active else Color("#0d1722")
	draw_rect(rect, fill)
	draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 3), accent)
	draw_rect(rect, accent if active else COLORS.line_soft, false, 1.2)
	draw_circle(Vector2(rect.get_center().x, rect.position.y + 25), 16, Color(accent.r, accent.g, accent.b, 0.12))
	_draw_label(glyph, rect.get_center().x, rect.position.y + 31, 22, accent, HORIZONTAL_ALIGNMENT_CENTER)
	_draw_label(_fit_text(label.to_upper(), rect.size.x - 4, 8), rect.get_center().x, rect.position.y + 52, 8, COLORS.text, HORIZONTAL_ALIGNMENT_CENTER)
	_draw_label(_fit_text(detail, rect.size.x - 4, 7), rect.get_center().x, rect.position.y + 66, 7, COLORS.muted, HORIZONTAL_ALIGNMENT_CENTER)
	active_hits.append({"rect": _touch_hit_rect(rect), "action": action})

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
		draw_set_transform(draw_offset + Vector2(overlay_offset_x * draw_scale, 0.0), 0.0, Vector2(draw_scale, draw_scale))
	var rect := Rect2(100, 61, 1240, 690)
	_draw_panel(rect, "", COLORS.gold)
	overlay_hit_start = active_hits.size()
	if overlay == "inventory":
		_draw_inventory(rect)
	elif overlay == "abilities":
		_draw_abilities(rect)
	elif overlay == "action_palette":
		_draw_action_palette(rect)
	elif overlay == "map":
		_draw_map(rect)
	elif overlay == "rewards":
		_draw_rewards(rect)
	elif overlay == "codex":
		_draw_codex(rect)
	elif overlay == "codex_book":
		_draw_spellbook_codex(rect)
	elif overlay == "inspect":
		_draw_inspect(rect)
	elif overlay == "pause":
		_draw_pause(rect)
	_draw_button(Rect2(1272, 67, TOUCH_TARGET, TOUCH_TARGET), "×", {"type": "close"}, false, 21)
	_draw_corner_marks(rect)
	if not is_zero_approx(overlay_offset_x):
		_shift_active_hits(overlay_hit_start_local, overlay_offset_x)
		draw_set_transform(draw_offset, 0.0, Vector2(draw_scale, draw_scale))

func _draw_inventory(rect: Rect2) -> void:
	_draw_label("INVENTORY  /  EQUIPMENT", 131, 103, 20, COLORS.text)
	_draw_label("A compact pack, worn gear and contextual item actions", 132, 127, 12, COLORS.muted)
	_draw_panel(Rect2(124, 150, 280, 546), "EQUIPMENT  ·  3 × 3", COLORS.line_soft)
	var slots: Array = ["Head", "Body", "Hands", "Feet", "Weapon", "Offhand", "Ring 1", "Ring 2", "Amulet"]
	for i in range(slots.size()):
		var slot: String = slots[i]
		var item_id: String = sim.run.equipment.get(slot, "")
		var item: Dictionary = sim.content.items.get(item_id, {})
		var slot_rect := Rect2(136 + (i % 3) * 87, 190 + int(i / 3) * 91, 82, 82)
		var occupied := item_id not in ["", "occupied"]
		_draw_panel(slot_rect, "", COLORS.gold if occupied else COLORS.line_soft)
		_draw_label(slot.to_upper(), slot_rect.get_center().x, slot_rect.position.y + 14, 8, COLORS.gold, HORIZONTAL_ALIGNMENT_CENTER)
		_draw_label("⊕" if item_id == "occupied" else _item_glyph(item_id, item) if occupied else "·", slot_rect.get_center().x, slot_rect.position.y + 48, 22, COLORS.cyan if item_id == "occupied" else COLORS.gold if occupied else COLORS.muted, HORIZONTAL_ALIGNMENT_CENTER)
		var slot_item_name := "Two-hand" if item_id == "occupied" else String(item.get("name", "Empty"))
		_draw_label(_fit_text(slot_item_name, 74, 8), slot_rect.get_center().x, slot_rect.position.y + 72, 8, COLORS.text if occupied else COLORS.muted, HORIZONTAL_ALIGNMENT_CENTER)
		if occupied:
			active_hits.append({"rect": _touch_hit_rect(slot_rect), "action": {"type": "unequip", "slot": slot}})
	_draw_label("Tap worn gear to unequip", 136, 496, 10, COLORS.muted)
	_draw_panel(Rect2(414, 150, 514, 546), "PACK  ·  %d / 30" % sim.run.inventory.size(), COLORS.line_soft)
	for i in range(30):
		var item_rect := Rect2(425 + (i % 6) * 80, 190 + int(i / 6) * 82, 75, 75)
		if i >= sim.run.inventory.size():
			_draw_panel(item_rect, "", Color("#18232c"))
			continue
		var item_id: String = sim.run.inventory[i]
		var item: Dictionary = sim.content.items.get(item_id, {})
		var rarity := String(item.get("rarity", "Common"))
		var rarity_color := COLORS.purple if rarity in ["Rare", "Epic", "Legendary"] else COLORS.gold if rarity == "Uncommon" else COLORS.line_soft
		var active := selected_inventory_index == i
		_draw_panel(item_rect, "", COLORS.gold if active else rarity_color)
		_draw_label(_item_glyph(item_id, item), item_rect.get_center().x, item_rect.position.y + 45, 27, _item_color(String(item.get("type", "item")), rarity), HORIZONTAL_ALIGNMENT_CENTER)
		_draw_label("✦" if rarity in ["Rare", "Epic", "Legendary"] else "·", item_rect.position.x + 7, item_rect.position.y + 14, 10, rarity_color)
		_draw_label(_fit_text(String(item.get("name", item_id)), item_rect.size.x - 8, 8), item_rect.get_center().x, item_rect.position.y + 68, 8, COLORS.text, HORIZONTAL_ALIGNMENT_CENTER)
		active_hits.append({"rect": _touch_hit_rect(item_rect), "action": {"type": "select_item", "index": i}})
	_draw_panel(Rect2(940, 150, 373, 546), "ITEM DETAILS", COLORS.line_soft)
	if selected_inventory_index >= 0 and selected_inventory_index < sim.run.inventory.size():
		var selected_id: String = sim.run.inventory[selected_inventory_index]
		var selected: Dictionary = sim.content.items.get(selected_id, {})
		_draw_label(_fit_text(String(selected.get("name", selected_id)), 332, 17), 960, 202, 17, COLORS.text)
		_draw_label("%s  ·  %s" % [String(selected.get("type", "item")).capitalize(), String(selected.get("rarity", "Common"))], 960, 226, 11, COLORS.cyan if selected.get("type") == "spellbook" else COLORS.gold)
		var detail_y := 260.0
		for line in _wrap(String(selected.get("description", "A useful object from the March.")), 39).slice(0, 3):
			_draw_label(String(line), 960, detail_y, 10, COLORS.muted)
			detail_y += 17.0
		if selected.get("type") == "equipment":
			_draw_label("EQUIPMENT  ·  %s" % selected.get("slot", ""), 960, 321, 11, COLORS.gold)
			if selected.has("weapon"):
				var weapon: Dictionary = sim.content.weapons.get(selected.weapon, {})
				_draw_label("%d %s damage  ·  %d reach" % [weapon.get("damage", 0), weapon.get("type", ""), weapon.get("range", 1)], 960, 348, 11, COLORS.text)
				_draw_label("%d action  ·  %d Stamina  ·  %d hand%s" % [weapon.get("time", 0), weapon.get("stamina", 0), weapon.get("hands", 1), "s" if weapon.get("hands", 1) != 1 else ""], 960, 372, 10, COLORS.muted)
			elif int(selected.get("armor", 0)) > 0:
				_draw_label("Armor  ·  %d" % int(selected.armor), 960, 348, 11, COLORS.text)
		elif selected.get("type") == "consumable":
			_draw_label("USE  ·  %s" % String(selected.get("effect", "item")).replace("_", " ").capitalize(), 960, 321, 11, COLORS.orange)
		elif selected.get("type") == "spellbook":
			_draw_spellbook_inventory_details(selected, selected_inventory_index, 960)
		var primary_label := "EQUIP" if selected.get("type") == "equipment" else "STUDY" if selected.get("type") == "spellbook" else "USE ITEM"
		var primary_action := "equip" if selected.get("type") == "equipment" else "study_book" if selected.get("type") == "spellbook" else "use_item"
		var study_ready := true
		if selected.get("type") == "spellbook":
			var study_options: Dictionary = sim.get_spellbook_options(selected_inventory_index)
			study_ready = not study_options.get("resolved", false) and (study_options.get("mode") != "choose" or selected_book_abilities.size() == int(study_options.get("choice_count", 0)))
		if study_ready:
			_draw_button(Rect2(958, 620, 164, TOUCH_TARGET), primary_label, {"type": primary_action}, true, 11, COLORS.green)
		else:
			draw_rect(Rect2(958, 620, 164, TOUCH_TARGET), Color("#111922"))
			draw_rect(Rect2(958, 620, 164, TOUCH_TARGET), COLORS.line_soft, false, 1)
			_draw_label("CHOOSE %d / %d" % [selected_book_abilities.size(), int(sim.get_spellbook_options(selected_inventory_index).get("choice_count", 0))], 1040, 651, 10, COLORS.muted, HORIZONTAL_ALIGNMENT_CENTER)
		_draw_button(Rect2(1130, 620, 164, TOUCH_TARGET), "DISCARD", {"type": "discard"}, false, 11, COLORS.red)
	else:
		_draw_label("Select a square slot to inspect the item and its available action.", 960, 210, 12, COLORS.muted)
		_draw_label("ARTIFACTS", 960, 278, 10, COLORS.gold)
		var artifacts_text := ", ".join(_artifact_names()) if not sim.run.artifacts.is_empty() else "None carried"
		for line in _wrap(artifacts_text, 39):
			_draw_label(line, 960, 301, 11, COLORS.text)
	_draw_button(Rect2(121, 710, 180, TOUCH_TARGET), "BACK TO BATTLE", {"type": "close"}, false, 11)
	_draw_label("Two-handed weapons reserve Offhand. Artifacts do not use pack slots.", 326, 741, 10, COLORS.muted)

func _draw_spellbook_inventory_details(selected: Dictionary, inventory_index: int, x: float) -> void:
	var options: Dictionary = sim.get_spellbook_options(inventory_index)
	_draw_label("CONTENTS  ·  %s" % String(options.get("school", "Knowledge")).to_upper(), x, 321, 10, COLORS.purple)
	var mode := String(options.get("mode", "all"))
	var required := int(options.get("choice_count", 0))
	if mode == "choose":
		_draw_label("CHOOSE %d  ·  %d SELECTED" % [required, selected_book_abilities.size()], x, 343, 9, COLORS.gold)
		var entries: Array = options.get("options", [])
		for i in range(entries.size()):
			var entry: Dictionary = entries[i]
			var button_rect := Rect2(x - 2, 352 + i * 59, 344, 49)
			var is_selected: bool = selected_book_abilities.has(i)
			_draw_button(button_rect, ("✓  " if is_selected else "◇  ") + String(entry.name), {"type": "toggle_book_choice", "index": i}, is_selected, 10, COLORS.purple)
			if entry.learned:
				_draw_label("ALREADY KNOWN", button_rect.end.x - 8, button_rect.position.y + 44, 7, COLORS.muted, HORIZONTAL_ALIGNMENT_RIGHT)
	elif mode == "all":
		var offered_count: int = options.get("options", []).size()
		_draw_label("STUDY TEACHES ALL %d OFFERED %s" % [offered_count, "ABILITY" if offered_count == 1 else "ABILITIES"], x, 344, 9, COLORS.gold)
		var row := 0
		for entry in options.get("options", []):
			_draw_label("✦  %s" % String(entry.name), x + 4, 371 + row * 21, 10, COLORS.text)
			row += 1
	else:
		_draw_label("STUDY UNLOCKS %s KNOWLEDGE" % String(options.get("school", "school")).to_upper(), x, 346, 10, COLORS.gold)
	if options.get("resolved", false):
		_draw_label("This copy has already been studied.", x, 435, 10, COLORS.muted)
	elif options.get("consume_on_study", false):
		_draw_label("The book is consumed after study. Contents are recorded in the Codex.", x, 558, 9, COLORS.muted)

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
				var connected: bool = selected_web_ability == String(node.id) or selected_web_ability == String(parent_id)
				draw_line(source_rect.get_center(), target_rect.get_center(), COLORS.gold if connected else COLORS.line, 2.0 if connected else 1.0)
	for node in visible_nodes:
		var node_rect: Rect2 = node_rects[node.id]
		if not graph_rect.intersects(node_rect):
			continue
		var selected_node: bool = selected_web_ability == node.id
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
	var chosen_id := selected_web_ability
	if chosen_id == "" or not sim.content.abilities.has(chosen_id):
		for known_id in sim.run.known:
			if sim.content.abilities.has(known_id):
				chosen_id = String(known_id)
				break
	if chosen_id != "" and sim.content.abilities.has(chosen_id):
		selected_web_ability = chosen_id
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
			_draw_button(Rect2(972, 611, 320, TOUCH_TARGET), "SELECT FOR TARGETING", {"type": "ability", "id": chosen_id}, false, 11, _school_color(ability.school))
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
		_draw_button(Rect2(972, 611, 320, TOUCH_TARGET), "CHOOSE THIS ABILITY", {"type": "palette_cast", "id": selected_ability}, true, 11, _school_color(String(ability.school)))
	_draw_button(Rect2(121, 710, 180, TOUCH_TARGET), "BACK TO BATTLE", {"type": "close"}, false, 12)

func _draw_map(rect: Rect2) -> void:
	_draw_label("WORLD MAP  /  THE FRACTURED MARCH", 131, 103, 20, COLORS.text)
	_draw_label("Each branch leads to a different fight, terrain and reward.", 132, 128, 13, COLORS.muted)
	_draw_panel(Rect2(128, 158, 1185, 150), "YOUR ROUTE", COLORS.line_soft)
	var route: Array = sim.run.get("route", [])
	var nodes: Array = route.duplicate()
	var node_x := 183.0
	for i in range(6):
		var node_stage: String = nodes[i] if i < nodes.size() else ""
		var node_name := "Grave Tyrant" if node_stage == "grave_tyrant" or (node_stage == "" and i == 5) else "Encounter %d" % (i + 1)
		if node_stage != "" and node_stage != "grave_tyrant":
			node_name = sim.content.stages.get(node_stage, {}).get("name", node_name)
		var fill := COLORS.green if i < int(sim.run.stage_index) else COLORS.gold if i == int(sim.run.stage_index) else Color("#526574")
		draw_circle(Vector2(node_x, 227), 13, fill)
		_draw_label(str(i + 1), node_x, 231, 10, COLORS.ink, HORIZONTAL_ALIGNMENT_CENTER)
		_draw_label(String(node_name).substr(0, 17), node_x, 264, 11, COLORS.text if i <= int(sim.run.stage_index) else COLORS.muted, HORIZONTAL_ALIGNMENT_CENTER)
		if i < 5:
			draw_line(Vector2(node_x + 16, 227), Vector2(node_x + 176, 227), COLORS.line, 2)
		node_x += 215
	_draw_panel(Rect2(128, 326, 1185, 300), "CHOOSE A DESTINATION", COLORS.line_soft)
	if int(sim.run.stage_index) < 4:
		for i in range(sim.run.route_choices.size()):
			var stage_id: String = sim.run.route_choices[i]
			var stage: Dictionary = sim.content.stages[stage_id]
			var card := Rect2(157 + i * 563, 379, 518, 205)
			_draw_panel(card, "", COLORS.line)
			_draw_label(stage.name, card.position.x + 20, card.position.y + 34, 21, COLORS.text)
			_draw_label(String(stage.subtitle), card.position.x + 20, card.position.y + 57, 14, COLORS.muted)
			_draw_label("HOSTILES", card.position.x + 20, card.position.y + 84, 10, COLORS.gold)
			_draw_label(", ".join(stage.enemies.map(func(id: String) -> String: return String(sim.content.enemies[id].name))), card.position.x + 20, card.position.y + 108, 13, COLORS.text)
			_draw_label("TERRAIN  ·  %s" % ", ".join(stage.terrain.keys()), card.position.x + 20, card.position.y + 132, 11, COLORS.cyan)
			_draw_button(Rect2(card.position.x + 17, card.position.y + 146, card.size.x - 34, TOUCH_TARGET), "TRAVEL HERE", {"type": "route", "id": stage_id}, true, 12)
	else:
		_draw_label("The final road leads to the Old Graveyard. The Grave Tyrant is waiting.", 176, 402, 17, COLORS.text)
		_draw_label("Bring every spell, summon and weapon you have learned.", 176, 437, 14, COLORS.muted)
		_draw_button(Rect2(175, 488, 470, 72), "ENTER THE BARROW", {"type": "boss"}, true, 17)
	_draw_button(Rect2(129, 651, 180, TOUCH_TARGET), "BACK TO BATTLE", {"type": "close"}, false, 12)

func _draw_rewards(rect: Rect2) -> void:
	_draw_label("ENCOUNTER COMPLETE", 131, 105, 23, COLORS.text)
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
	_draw_label("%d XP  ·  %d KILLS  ·  %d / 6 ENCOUNTERS" % [sim.run.xp, sim.run.kills, sim.run.encounters_completed], 155, 616, 13, COLORS.gold)
	_draw_button(Rect2(128, 640, 205, TOUCH_TARGET), "KEEP EXPLORING", {"type": "close"}, false, 12)
	_draw_button(Rect2(1042, 640, 270, TOUCH_TARGET), "NEXT STAGE  →", {"type": "next_stage"}, true, 13)

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
	_draw_panel(Rect2(128, 158, 1185, 456), "RECORDED CONTENTS", COLORS.line_soft)
	_draw_label("DESCRIPTION", 158, 204, 10, COLORS.gold)
	var desc_y := 229.0
	for line in _wrap(String(book.get("description", "A recorded work of recovered knowledge.")), 96).slice(0, 3):
		_draw_label(String(line), 158, desc_y, 12, COLORS.text)
		desc_y += 21
	_draw_label("FULL CONTENTS", 158, 307, 10, COLORS.gold)
	var contents: Array = book.get("contents", [])
	var left_x := 158.0
	for i in range(contents.size()):
		var column := int(i / 8)
		var row := i % 8
		if column > 1: break
		_draw_label("%02d  ·  %s" % [i + 1, String(contents[i])], left_x + column * 350, 335 + row * 25, 11, COLORS.text)
	var offered: Array = book.get("learning", {}).get("abilities", book.get("learns", []))
	_draw_label("LEARNING", 980, 204, 10, COLORS.gold)
	var learn_mode := String(book.get("learning", {}).get("mode", "all"))
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
	var victory: bool = sim.run.get("outcome", "") == "victory"
	_draw_label("THE TYRANT IS FALLEN" if victory else "THE MARCH CLAIMS YOU", 260, 209, 34, COLORS.gold if victory else COLORS.red)
	_draw_label("A run is a story made from the choices that survive it.", 262, 246, 17, COLORS.muted)
	_draw_panel(Rect2(257, 286, 926, 250), "RUN RECORD", COLORS.line)
	var summary: Dictionary = sim.get_summary()
	_draw_label(String(summary.character), 294, 350, 22, COLORS.text)
	_draw_label("LEVEL  %d     KILLS  %d     ENCOUNTERS  %d / 6" % [summary.level, summary.kills, summary.encounters], 294, 395, 17, COLORS.cyan)
	_draw_label("XP remaining  %d     Simulated time  %d" % [sim.run.xp, sim.run.time], 294, 433, 14, COLORS.muted)
	_draw_label("Codex discoveries remain after this run; carried power does not.", 294, 478, 14, COLORS.gold)
	_draw_button(Rect2(417, 594, 278, 70), "CHOOSE A NEW WANDERER", {"type": "title"}, true, 14)
	_draw_button(Rect2(724, 594, 278, 70), "FIELD CODEX", {"type": "title_codex"}, false, 14)

func _draw_toast(text: String) -> void:
	var width := minf(750, maxf(300, text.length() * 9.0))
	var rect := Rect2((1440 - width) * 0.5, 602, width, 34)
	draw_rect(rect, Color("#172936"))
	draw_rect(rect, COLORS.line, false, 1.0)
	_draw_label(text, 720, 625, 13, COLORS.text, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_panel(rect: Rect2, title: String, border: Color) -> void:
	draw_rect(rect, COLORS.panel)
	draw_rect(rect, border, false, 1.4)
	if title != "":
		_draw_label(title, rect.position.x + 14, rect.position.y + 25, 11, COLORS.gold)
		draw_line(Vector2(rect.position.x + 12, rect.position.y + 35), Vector2(rect.end.x - 12, rect.position.y + 35), COLORS.line_soft, 1.0)

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
	active_hits.append({"rect": _touch_hit_rect(rect), "action": action})

func _touch_hit_rect(rect: Rect2) -> Rect2:
	var target_size := Vector2(maxf(rect.size.x, TOUCH_TARGET), maxf(rect.size.y, TOUCH_TARGET))
	return Rect2(rect.get_center() - target_size * 0.5, target_size)

func _draw_dpad_button(rect: Rect2, glyph: String, direction: Vector2i) -> void:
	draw_rect(rect, COLORS.panel_2)
	draw_rect(rect, COLORS.line, false, 1)
	_draw_label(glyph, rect.get_center().x, rect.get_center().y + 5, 14, COLORS.text, HORIZONTAL_ALIGNMENT_CENTER)
	active_hits.append({"rect": _touch_hit_rect(rect), "action": {"type": "dpad", "direction": [direction.x, direction.y]}})

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

func _board_origin() -> Vector2:
	return BASE_BOARD_ORIGIN

func _tile_size() -> float:
	return WIDE_TILE if _is_wide_layout() else BASE_TILE

func _board_rect() -> Rect2:
	var origin := _board_origin()
	return Rect2(origin, Vector2(ArcanistSim.WIDTH * _tile_size(), ArcanistSim.HEIGHT * _tile_size()))

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
	var draw_x := x
	if alignment != HORIZONTAL_ALIGNMENT_LEFT:
		var measured: Vector2 = ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size)
		if alignment == HORIZONTAL_ALIGNMENT_CENTER:
			draw_x -= measured.x * 0.5
		elif alignment == HORIZONTAL_ALIGNMENT_RIGHT:
			draw_x -= measured.x
	draw_string(ThemeDB.fallback_font, Vector2(draw_x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)

func _fit_text(text: String, max_width: float, size: int) -> String:
	if ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x <= max_width:
		return text
	var shortened := text
	while not shortened.is_empty():
		shortened = shortened.substr(0, shortened.length() - 1).strip_edges()
		var candidate := shortened + "…"
		if ThemeDB.fallback_font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x <= max_width:
			return candidate
	return "…"

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
	elif event is InputEventMouseMotion and mouse_press_active:
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
	match String(action.get("type", "")):
		"select_character":
			selected_character = String(action.id)
		"start":
			var seed_value := int(Time.get_unix_time_from_system())
			sim.start_run(seed_value, selected_character)
			sim.save_run()
			page = "battle"
			overlay = ""
			selected_enemy = ""
			selected_object_index = -1
			target_mode = ""
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
		"overlay":
			if target_mode != "": _cancel_targeting()
			overlay = String(action.id)
			selected_inventory_index = -1
			selected_object_index = -1
			selected_enemy = "" if action.id != "inspect" else selected_enemy
			if overlay == "abilities":
				var known: Array = sim.run.get("known", [])
				selected_web_ability = String(known.back()) if not known.is_empty() else ""
				ability_filter = String(sim.content.abilities.get(selected_web_ability, {}).get("school", "All"))
				ability_filter_page = 0
				web_zoom = 0.86
				_center_web_on(selected_web_ability)
			elif overlay == "action_palette":
				palette_page = 0
				palette_filter = "All"
		"close":
			overlay = "pause" if overlay == "exit_confirm" else "codex" if overlay == "codex_book" else ""
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
			overlay = "inspect"
		"dpad":
			var pos: Vector2i = sim._pos(sim.get_player()) + Vector2i(int(action.direction[0]), int(action.direction[1]))
			_commit_action(sim.act({"type": "move", "target": [pos.x, pos.y]}))
		"wait":
			_commit_action(sim.act({"type": "wait"}))
		"quick_item":
			var item_index := int(action.index)
			var item_id: String = sim.run.inventory[item_index]
			var item: Dictionary = sim.content.items[item_id]
			if item.get("effect") == "bomb" or item.get("type") == "scroll":
				_set_target_mode("item:%d" % item_index)
			else:
				target_mode = ""
				_commit_action(sim.use_item(item_index))
		"use_item":
			if selected_inventory_index >= 0:
				var item_id: String = sim.run.inventory[selected_inventory_index]
				var item: Dictionary = sim.content.items[item_id]
				if item.get("effect") == "bomb" or item.get("type") == "scroll":
					_set_target_mode("item:%d" % selected_inventory_index)
					overlay = ""
					_show_notice("Choose a visible target on the battlefield.")
				else:
					_commit_action(sim.use_item(selected_inventory_index))
					overlay = "inventory"
		"equip":
			if sim.equip_item(selected_inventory_index):
				selected_inventory_index = -1
				_show_notice("Equipment updated.")
		"discard":
			if sim.discard_item(selected_inventory_index):
				selected_inventory_index = -1
				_show_notice("Item discarded.")
		"unequip":
			if sim.unequip_item(String(action.get("slot", ""))):
				_show_notice("Equipment moved into the pack.")
		"select_item":
			selected_inventory_index = int(action.index)
			selected_book_abilities.clear()
		"study_book":
			var book_id: String = sim.run.inventory[selected_inventory_index] if selected_inventory_index >= 0 and selected_inventory_index < sim.run.inventory.size() else ""
			if sim.study_spellbook(selected_inventory_index, selected_book_abilities):
				var resolution: Dictionary = sim.run.spellbook_resolutions.get(book_id, {})
				var chosen_names: Array[String] = []
				for ability_id in resolution.get("abilities", []):
					chosen_names.append(String(sim.content.abilities[ability_id].name))
				selected_inventory_index = -1 if sim.content.items.get(book_id, {}).get("learning", {}).get("consume_on_study", false) else selected_inventory_index
				selected_book_abilities.clear()
				_show_notice("Knowledge recorded: %s." % (", ".join(chosen_names) if not chosen_names.is_empty() else "school unlocked"))
		"toggle_book_choice":
			var option_index := int(action.index)
			if selected_book_abilities.has(option_index):
				selected_book_abilities.erase(option_index)
			else:
				var book_options: Dictionary = sim.get_spellbook_options(selected_inventory_index)
				var required_choices := int(book_options.get("choice_count", 0))
				if selected_book_abilities.size() >= required_choices:
					if required_choices == 1:
						selected_book_abilities.clear()
					else:
						_show_notice("Choose exactly %d abilities; remove one before adding another." % required_choices)
						return
				selected_book_abilities.append(option_index)
		"select_web_node":
			selected_web_ability = String(action.id)
		"web_filter":
			ability_filter = String(action.get("school", "All"))
			var focus_id := sim.get_progression_focus_id(ability_filter) if ability_filter != "All" else selected_web_ability
			if focus_id != "": selected_web_ability = focus_id
			_center_web_on(focus_id if focus_id != "" else selected_web_ability)
		"web_filter_page":
			ability_filter_page = maxi(0, ability_filter_page + int(action.get("delta", 0)))
		"web_zoom":
			_zoom_ability_web(float(action.get("factor", 1.0)), _ability_graph_rect().get_center())
		"web_center":
			_center_web_on(selected_web_ability)
		"web_center_root":
			var root_school := ability_filter
			if root_school == "All": root_school = String(sim.content.abilities.get(selected_web_ability, {}).get("school", ""))
			_center_web_on(sim.get_progression_root_id(root_school))
		"open_action_palette":
			overlay = "action_palette"
			palette_page = 0
			palette_filter = "All"
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
				overlay = ""
				selected_enemy = ""
				selected_object_index = -1
		"boss":
			if sim.start_boss():
				overlay = ""
				selected_enemy = ""
				selected_object_index = -1
		"next_stage":
			if sim.run.get("outcome", "") == "victory":
				page = "outcome"
				overlay = ""
			elif sim.run.get("stage_completed", false):
				overlay = "map"
		"claim_reward":
			if sim.claim_reward(int(action.index)):
				_show_notice("Your one reward choice is secured. You may keep exploring.")
		"learn":
			if sim.learn_ability(String(action.id)):
				selected_web_ability = String(action.id)
				_center_web_on(selected_web_ability)
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
				overlay = "inspect"
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

func _battlefield_tap(cell: Vector2i) -> void:
	if not sim._inside(cell):
		return
	if target_mode.begins_with("item:"):
		var item_index := int(target_mode.trim_prefix("item:"))
		_commit_action(sim.use_item(item_index, Vector2i(cell.x, cell.y)))
		target_mode = ""
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
			overlay = "inspect"
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
			_show_notice("%s tile  ·  %s" % [sim.get_stage_name(), sim._terrain_at(cell)])
	queue_redraw()

func _selected_object() -> Dictionary:
	if selected_object_index < 0 or selected_object_index >= sim.run.get("objects", []).size():
		return {}
	var object: Dictionary = sim.run.objects[selected_object_index]
	return object if int(object.get("hp", 1)) > 0 else {}

func _handle_key(event: InputEventKey) -> void:
	if event.keycode == KEY_ESCAPE:
		# Android also delivers Back through NOTIFICATION_WM_GO_BACK_REQUEST.
		# Ignore its Escape key alias so one physical Back cannot dismiss a
		# context and then continue into the pause menu as a second action.
		if OS.get_name() == "Android":
			return
		if target_mode != "":
			_cancel_targeting()
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
	elif event.keycode == KEY_I:
		overlay = "inventory"
	elif event.keycode == KEY_K:
		overlay = "abilities"
	elif event.keycode == KEY_M:
		overlay = "map"
	elif event.keycode >= KEY_1 and event.keycode <= KEY_6:
		var index := int(event.keycode - KEY_1)
		var known: Array = sim.get_available_abilities()
		if index < known.size():
			_handle_action({"type": "ability", "id": known[index]})
	queue_redraw()

func _commit_action(result: Dictionary) -> void:
	if result.get("ok", false):
		if sim.run.get("outcome", "") != "":
			page = "outcome"
			overlay = ""
		elif sim.run.get("stage_completed", false) and overlay == "":
			overlay = "rewards"
	else:
		_show_notice(String(result.get("message", "That action could not be completed.")))
	queue_redraw()

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
	var origin := sim._pos(sim.get_player())
	if target_mode == "attack":
		var weapon_id: String = sim.run.equipment.get("Weapon", "sword")
		var weapon: Dictionary = sim.content.weapons.get(weapon_id, sim.content.weapons.sword)
		return sim._distance_to_entity(origin, entity) <= int(weapon.range) and sim._line_of_sight(origin, sim._pos(entity))
	if target_mode.begins_with("item:"):
		var item_index := int(target_mode.trim_prefix("item:"))
		if item_index >= 0 and item_index < sim.run.inventory.size():
			var item: Dictionary = sim.content.items.get(sim.run.inventory[item_index], {})
			if item.get("effect") == "bomb":
				return sim._dist(origin, sim._pos(entity)) <= 5 and sim._cell_visible(sim._pos(entity))
	var ability := _target_ability()
	if ability.is_empty() or ability.get("target", "enemy") != "enemy" or not sim._can_pay(ability.get("costs", {})):
		return false
	return sim._dist(origin, sim._pos(entity)) <= int(ability.get("range", 0)) and sim._cell_visible(sim._pos(entity)) and sim._line_of_sight(origin, sim._pos(entity))

func _cell_is_legal_target(cell: Vector2i) -> bool:
	if not sim._inside(cell):
		return false
	var origin := sim._pos(sim.get_player())
	if target_mode == "attack":
		var entity := sim.get_enemy_at(cell)
		if not entity.is_empty():
			return _entity_is_legal_target(entity)
		var object_index := sim._object_index_at(cell)
		return object_index >= 0 and sim.run.objects[object_index].get("kind") == "ward" and sim._dist(origin, cell) <= 1
	if target_mode == "move":
		return sim._terrain_at(cell) != "wall" and sim._next_step(origin, cell, "player") != origin
	if target_mode.begins_with("item:"):
		var item_index := int(target_mode.trim_prefix("item:"))
		if item_index >= 0 and item_index < sim.run.inventory.size():
			var item: Dictionary = sim.content.items.get(sim.run.inventory[item_index], {})
			if item.get("effect") == "bomb":
				return sim._dist(origin, cell) <= 5 and sim._cell_visible(cell)
	var ability := _target_ability()
	if ability.is_empty() or not sim._can_pay(ability.get("costs", {})):
		return false
	if ability.get("target", "enemy") == "self":
		return false
	if sim._dist(origin, cell) > int(ability.get("range", 0)) or not sim._cell_visible(cell) or not sim._line_of_sight(origin, cell):
		return false
	if ability.get("target", "enemy") == "enemy":
		return not sim.get_enemy_at(cell).is_empty()
	if ability.get("target", "enemy") == "tile":
		return sim._terrain_at(cell) != "wall"
	return true

func _draw_targetable_cells(origin: Vector2, tile: float) -> void:
	if target_mode == "":
		return
	var ability := _target_ability()
	var target_kind := String(ability.get("target", ""))
	var show_cell_candidates := target_mode == "move" or target_mode.begins_with("item:") or target_kind in ["area", "tile"]
	if not show_cell_candidates:
		return
	if target_mode == "move" and _point_in_board(press_current_position):
		var move_cell := _cell_from_point(press_current_position)
		if _cell_is_legal_target(move_cell):
			var move_rect := Rect2(origin + Vector2(move_cell.x * tile, move_cell.y * tile), Vector2(tile - 1, tile - 1))
			draw_rect(move_rect, Color(0.33, 0.9, 0.53, 0.24), true)
			draw_rect(move_rect, COLORS.green, false, 2.0)
		return
	for y in range(ArcanistSim.HEIGHT):
		for x in range(ArcanistSim.WIDTH):
			var cell := Vector2i(x, y)
			if not _cell_is_legal_target(cell):
				continue
			var rect := Rect2(origin + Vector2(x * tile, y * tile), Vector2(tile - 1, tile - 1))
			draw_rect(rect, Color(0.35, 0.83, 0.93, 0.12), true)
			draw_rect(rect, Color(0.35, 0.83, 0.93, 0.55), false, 1.0)

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
	var image := offscreen.get_texture().get_image()
	var absolute_path := ProjectSettings.globalize_path(capture_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var error := image.save_png(absolute_path)
	if error != OK:
		push_error("Could not save visual QA image: %s" % error_string(error))
	get_tree().quit()
