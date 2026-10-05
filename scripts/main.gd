extends Control

const SimScript = preload("res://scripts/game_sim.gd")
const LOGICAL_SIZE := Vector2(1440, 810)
const BOARD_ORIGIN := Vector2(250, 62)
const TILE := 35.0
const BOARD_RECT := Rect2(BOARD_ORIGIN, Vector2(875, 560))

var sim: ArcanistSim
var page := "title"
var overlay := ""
var selected_character := "jim"
var selected_enemy := ""
var selected_inventory_index := -1
var selected_ability := ""
var target_mode := ""
var selected_book_ability := 0
var selected_ward := ""
var press_position := Vector2.ZERO
var press_started := 0
var is_touch_press := false
var active_hits: Array = []
var overlay_hit_start := 0
var notice := ""
var notice_until := 0
var capture_path := ""
var capture_requested := false
var capture_size := Vector2i.ZERO

const COLORS := {
	"ink": Color("#071018"), "panel": Color("#0d1722"), "panel_2": Color("#111f2c"),
	"line": Color("#3d586b"), "line_soft": Color("#233746"), "text": Color("#edf3f5"),
	"muted": Color("#91a6b4"), "gold": Color("#e8c96f"), "cyan": Color("#5fdcff"),
	"green": Color("#74dc89"), "red": Color("#ef5c64"), "blue": Color("#488ef0"),
	"purple": Color("#c078ed"), "orange": Color("#ff984c"), "blood": Color("#b94753")
}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	sim = SimScript.new()
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--capture="):
			var dimensions: PackedStringArray = arg.trim_prefix("--capture=").split("x")
			if dimensions.size() == 2:
				capture_size = Vector2i(int(dimensions[0]), int(dimensions[1]))
				capture_path = "res://screenshots/%dx%d.png" % [capture_size.x, capture_size.y]
				capture_requested = true
				page = "battle"
				sim.start_run(912041, "mara")
				sim.save_run()
	if not capture_requested:
		if sim.has_saved_run():
			page = "title"
	if capture_requested:
		call_deferred("_capture_after_draw")
	queue_redraw()

func _process(_delta: float) -> void:
	if notice != "" and Time.get_ticks_msec() > notice_until:
		notice = ""
		queue_redraw()

func _draw() -> void:
	active_hits.clear()
	var viewport := get_viewport_rect().size
	var scale_factor := minf(viewport.x / LOGICAL_SIZE.x, viewport.y / LOGICAL_SIZE.y)
	var offset := (viewport - LOGICAL_SIZE * scale_factor) * 0.5
	draw_set_transform(offset, 0.0, Vector2(scale_factor, scale_factor))
	draw_rect(Rect2(Vector2.ZERO, LOGICAL_SIZE), COLORS.ink)
	_draw_backdrop()
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
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_backdrop() -> void:
	for i in range(9):
		var alpha := 0.035 - float(i) * 0.003
		draw_rect(Rect2(Vector2(0, i * 101), Vector2(1440, 102)), Color(0.08, 0.17, 0.23, alpha))
	for x in range(0, 1440, 80):
		draw_line(Vector2(x, 0), Vector2(x, 810), Color(0.22, 0.39, 0.48, 0.035), 1.0)
	for y in range(0, 810, 80):
		draw_line(Vector2(0, y), Vector2(1440, y), Color(0.22, 0.39, 0.48, 0.035), 1.0)

func _draw_title() -> void:
	_draw_label("PROJECT", 56, 72, 18, COLORS.cyan)
	_draw_label("ARCANIST", 56, 129, 48, COLORS.text)
	_draw_label("THE FRACTURED MARCH", 58, 158, 15, COLORS.gold)
	_draw_label("A tactical roguelike of steel, spellcraft and hard choices", 58, 187, 17, COLORS.muted)
	_draw_panel(Rect2(47, 215, 1346, 450), "CHOOSE YOUR BEGINNING", COLORS.line)
	var characters: Array = ["jim", "aldren", "mara"]
	var card_x := 70.0
	for character_id in characters:
		var definition: Dictionary = sim.content.characters[character_id]
		var rect := Rect2(card_x, 270, 414, 334)
		var active: bool = character_id == selected_character
		_draw_panel(rect, "", COLORS.gold if active else COLORS.line_soft)
		_draw_label(definition.name, rect.position.x + 25, rect.position.y + 48, 22, COLORS.text)
		_draw_label(definition.subtitle, rect.position.x + 25, rect.position.y + 77, 14, COLORS.muted)
		_draw_line(rect.position.x + 25, rect.position.y + 96, rect.position.x + rect.size.x - 25, rect.position.y + 96, COLORS.line_soft)
		_draw_label("AURA", rect.position.x + 25, rect.position.y + 123, 11, COLORS.gold)
		_draw_label(definition.aura if definition.aura != "None" else "None — open progression", rect.position.x + 25, rect.position.y + 149, 16, COLORS.cyan if active else COLORS.text)
		_draw_label("STARTING IDENTITY", rect.position.x + 25, rect.position.y + 187, 11, COLORS.gold)
		_draw_label("%s  ·  %s" % [definition.discipline, definition.weapon.capitalize()], rect.position.x + 25, rect.position.y + 213, 16, COLORS.text)
		var schools: Array = definition.schools
		_draw_label("MAGIC  ·  %s" % (", ".join(schools) if not schools.is_empty() else "None"), rect.position.x + 25, rect.position.y + 250, 14, COLORS.muted)
		_draw_label("HEALTH  %d      MANA  %d      STAMINA  %d" % [definition.resources.Health[1], definition.resources.Mana[1], definition.resources.Stamina[1]], rect.position.x + 25, rect.position.y + 286, 12, COLORS.text)
		active_hits.append({"rect": rect, "action": {"type": "select_character", "id": character_id}})
		_draw_button(Rect2(rect.position.x + 15, rect.position.y + 302, rect.size.x - 30, 23), "SELECTED" if active else "SELECT CHARACTER", {"type": "select_character", "id": character_id}, active, 10)
		card_x += 437
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
	_draw_label(String(player.get("name", "Adventurer")), 31, 47, 15, COLORS.text)
	_draw_label("LV %d" % sim.run.get("level", 1), 221, 47, 13, COLORS.gold, HORIZONTAL_ALIGNMENT_RIGHT)
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
	_draw_panel(Rect2(242, 52, 892, 580), "", COLORS.line)
	var grid: Array = sim.run.grid
	var visible: Array = sim.run.visible
	var explored: Array = sim.run.explored
	for y in range(ArcanistSim.HEIGHT):
		for x in range(ArcanistSim.WIDTH):
			var cell := Vector2i(x, y)
			var rect := Rect2(BOARD_ORIGIN + Vector2(x * TILE, y * TILE), Vector2(TILE - 1, TILE - 1))
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
				_draw_label(glyph, rect.position.x + TILE * 0.5, rect.position.y + 24, 15, glyph_color, HORIZONTAL_ALIGNMENT_CENTER)
			if not lit:
				draw_rect(rect, Color(0.015, 0.025, 0.035, 0.28 if seen else 0.78))
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
		var entity_rect := Rect2(BOARD_ORIGIN + Vector2(cell.x * TILE + 3, cell.y * TILE + 3), Vector2(TILE * size - 7, TILE * size - 7))
		var faction: String = entity.get("faction", "")
		var entity_color := COLORS.cyan if entity.id == "player" else COLORS.green if faction == "Adventurers" else COLORS.red if faction in ["Undead", "Demons"] else COLORS.gold
		if entity.id == selected_enemy:
			draw_rect(entity_rect.grow(2), COLORS.gold, false, 2)
		if target_mode != "" and entity.id != "player" and sim._is_hostile("player", entity.id):
			draw_rect(entity_rect.grow(1), Color(0.9, 0.24, 0.3, 0.22), true)
			draw_rect(entity_rect.grow(1), COLORS.red, false, 2)
		var glyph: String = "@" if entity.id == "player" else String(entity.get("symbol", "?"))
		if entity.get("kind") == "summon":
			glyph = "✦" if entity.get("enemy_id") == "phantom_blade" else "s"
		var center := entity_rect.get_center()
		_draw_label(glyph, center.x, center.y + 7, 20 if size == 1 else 26, entity_color, HORIZONTAL_ALIGNMENT_CENTER)
		if entity.id != "player":
			var hp_fraction := clampf(float(entity.hp) / maxf(1.0, float(entity.max_hp)), 0.0, 1.0)
			draw_rect(Rect2(entity_rect.position.x, entity_rect.end.y + 1, entity_rect.size.x, 3), Color("#151c22"))
			draw_rect(Rect2(entity_rect.position.x, entity_rect.end.y + 1, entity_rect.size.x * hp_fraction, 3), COLORS.red if entity.kind != "summon" else COLORS.cyan)
	if target_mode != "":
		_draw_label("TARGETING  ·  tap a valid tile  ·  Esc to cancel", 260, 45, 12, COLORS.gold)
	else:
		_draw_label("%s  ·  %s" % [sim.get_stage_name().to_upper(), sim.get_objective_text()], 260, 45, 12, COLORS.text)
	if capture_requested and Time.get_ticks_msec() < 1200:
		_draw_label("", 0, 0, 1, COLORS.text)

func _draw_timeline() -> void:
	_draw_panel(Rect2(1150, 18, 272, 227), "TURN TIMELINE", COLORS.line)
	var entries: Array = sim.get_timeline(6)
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var y := 61 + i * 27
		var color := COLORS.cyan if entry.id == "player" else COLORS.green if entry.faction == "Adventurers" else COLORS.red if entry.faction in ["Undead", "Demons"] else COLORS.gold
		_draw_label("@" if entry.id == "player" else "✦" if entry.kind == "summon" else String(entry.name.substr(0, 1)), 1166, y, 14, color)
		_draw_label(String(entry.name).substr(0, 19), 1190, y, 12, COLORS.text)
		_draw_label("NOW" if entry.id == "player" else str(int(entry.time) - int(sim.get_player().next_time)), 1407, y, 11, COLORS.gold if entry.id == "player" else COLORS.muted, HORIZONTAL_ALIGNMENT_RIGHT)
	_draw_line(1165, 223, 1407, 223, COLORS.line_soft)
	_draw_label("NO REAL-TIME TIMER", 1166, 239, 10, COLORS.muted)

func _draw_inspection_card() -> void:
	var rect := Rect2(1150, 258, 272, 360)
	_draw_panel(rect, "FIELD INTELLIGENCE", COLORS.line)
	var enemy: Dictionary = sim.run.entities.get(selected_enemy, {})
	if enemy.is_empty() or not enemy.get("alive", true) or not sim._cell_visible(sim._pos(enemy)):
		_draw_label("OBJECTIVE", 1166, 300, 11, COLORS.gold)
		var objective_lines := _wrap(sim.get_objective_text(), 31)
		for i in range(objective_lines.size()):
			_draw_label(objective_lines[i], 1166, 328 + i * 19, 14, COLORS.text)
		_draw_label("ENCOUNTER", 1166, 389, 11, COLORS.gold)
		_draw_label("%d / 6" % [int(sim.run.stage_index) + 1], 1166, 415, 14, COLORS.text)
		_draw_label("%d hostiles remain" % sim._hostile_count(), 1166, 439, 13, COLORS.muted)
		_draw_label("%d XP  ·  level %d" % [sim.run.xp, sim.run.level], 1166, 464, 13, COLORS.muted)
		_draw_label("RECENT EVENTS", 1166, 502, 11, COLORS.gold)
		var logs: Array = sim.run.get("log", [])
		for i in range(mini(4, logs.size())):
			_draw_label(String(logs[logs.size() - 1 - i]).substr(0, 32), 1166, 526 + i * 20, 10, COLORS.muted)
	else:
		_draw_label(String(enemy.get("name", "Creature")), 1166, 300, 18, COLORS.red if enemy.faction in ["Undead", "Demons"] else COLORS.gold)
		_draw_label("HP  %d / %d" % [enemy.hp, enemy.max_hp], 1166, 333, 14, COLORS.text)
		draw_rect(Rect2(1166, 345, 240, 8), Color("#202a30"))
		draw_rect(Rect2(1166, 345, 240 * clampf(float(enemy.hp) / maxf(1.0, float(enemy.max_hp)), 0.0, 1.0), 8), COLORS.red)
		_draw_label("%s  ·  %s" % ["Large 2×2" if int(enemy.footprint) > 1 else "Standard", String(enemy.faction)], 1166, 379, 13, COLORS.muted)
		_draw_label("Attack  %d  ·  %s" % [enemy.damage, enemy.damage_type], 1166, 404, 13, COLORS.text)
		for damage_type in enemy.get("resist", {}):
			_draw_label("Resist  %s  %d%%" % [damage_type, int(float(enemy.resist[damage_type]) * 100)], 1166, 431, 12, COLORS.cyan)
		if enemy.get("resist", {}).is_empty():
			_draw_label("No known resistances", 1166, 431, 12, COLORS.muted)
		var status_line := "Clear"
		if not enemy.get("statuses", {}).is_empty():
			status_line = ", ".join(enemy.statuses.keys())
		_draw_label("Effects  %s" % status_line, 1166, 458, 12, COLORS.orange if status_line != "Clear" else COLORS.muted)
		_draw_button(Rect2(1166, 478, 240, 45), "INSPECT CREATURE", {"type": "inspect", "id": selected_enemy}, false, 13)
	var transition_ready: bool = sim.run.get("stage_completed", false)
	var transition_action := {"type": "next_stage"} if transition_ready else {"type": "overlay", "id": "map"}
	_draw_button(Rect2(1166, 550, 240, 49), "%s" % ("NEXT STAGE" if transition_ready and sim.run.get("stage_index", 0) < 5 else "VICTORY" if sim.run.get("outcome") == "victory" else "ROUTE MAP"), transition_action, transition_ready, 15)

func _draw_side_controls() -> void:
	_draw_label("GOAL  ·  REACH THE TYRANT", 22, 484, 11, COLORS.gold)
	_draw_label("PATH  %d / 5 ENCOUNTERS" % mini(int(sim.run.get("stage_index", 0)), 5), 22, 505, 11, COLORS.muted)
	var dpad_center := Vector2(125, 560)
	_draw_dpad_button(Rect2(dpad_center.x - 18, dpad_center.y - 48, 36, 31), "▲", Vector2i(0, -1))
	_draw_dpad_button(Rect2(dpad_center.x - 57, dpad_center.y - 10, 36, 31), "◀", Vector2i(-1, 0))
	_draw_dpad_button(Rect2(dpad_center.x + 21, dpad_center.y - 10, 36, 31), "▶", Vector2i(1, 0))
	_draw_dpad_button(Rect2(dpad_center.x - 18, dpad_center.y + 28, 36, 31), "▼", Vector2i(0, 1))
	_draw_label("TAP A TILE OR USE ARROWS", 23, 630, 9, COLORS.muted)

func _draw_action_bar() -> void:
	_draw_panel(Rect2(18, 644, 1404, 148), "", COLORS.line)
	var y := 665.0
	var h := 99.0
	_draw_button(Rect2(28, y, 90, h), "MOVE\n(100)", {"type": "target_mode", "mode": "move"}, target_mode == "move", 13)
	_draw_button(Rect2(125, y, 94, h), "WEAPON\nATTACK", {"type": "target_mode", "mode": "attack"}, target_mode == "attack", 12)
	var known: Array = sim.get_available_abilities()
	for i in range(mini(6, known.size())):
		var ability_id: String = known[i]
		var ability: Dictionary = sim.content.abilities[ability_id]
		var color := _school_color(String(ability.school))
		var ability_name: String = String(ability.name)
		if ability_name == "Raise Skeleton": ability_name = "Raise Skel."
		elif ability_name == "Phantom Blade": ability_name = "Phantom"
		_draw_button(Rect2(226 + i * 101, y, 96, h), "%s\n%s" % [ability_name, _cost_text(ability.costs)], {"type": "ability", "id": ability_id}, target_mode == ability_id, 9, color)
	var quick_items: Array = ["healing_potion", "mana_potion", "bomb", "fireball_scroll"]
	var quick_slot := mini(6, known.size())
	for item_id in quick_items:
		if quick_slot >= 6:
			break
		var item_index: int = sim.run.inventory.find(item_id)
		if item_index < 0:
			continue
		var quick_name := "HEAL" if item_id == "healing_potion" else "MANA" if item_id == "mana_potion" else "BOMB" if item_id == "bomb" else "SCROLL"
		_draw_button(Rect2(226 + quick_slot * 101, y, 96, h), quick_name, {"type": "quick_item", "index": item_index}, target_mode == "item:%d" % item_index, 11, COLORS.orange)
		quick_slot += 1
	_draw_button(Rect2(839, y, 91, h), "PACK\n%d / 30" % sim.run.inventory.size(), {"type": "overlay", "id": "inventory"}, false, 11)
	_draw_button(Rect2(937, y, 91, h), "ABILITY\nWEB", {"type": "overlay", "id": "abilities"}, false, 11)
	_draw_button(Rect2(1035, y, 91, h), "WORLD\nMAP", {"type": "overlay", "id": "map"}, false, 11)
	_draw_button(Rect2(1133, y, 91, h), "FIELD\nCODEX", {"type": "overlay", "id": "codex"}, false, 11)
	_draw_button(Rect2(1232, y, 178, h), "END TURN\n(100)", {"type": "wait"}, true, 16)
	_draw_label("E / END TURN WAITS  ·  ESC CANCELS TARGETING  ·  NUMBER KEYS USE ABILITIES  ·  RIGHT CLICK INSPECTS", 242, 784, 9, COLORS.muted)

func _draw_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, LOGICAL_SIZE), Color(0.005, 0.012, 0.02, 0.74))
	var rect := Rect2(100, 61, 1240, 690)
	_draw_panel(rect, "", COLORS.gold)
	overlay_hit_start = active_hits.size()
	if overlay == "inventory":
		_draw_inventory(rect)
	elif overlay == "abilities":
		_draw_abilities(rect)
	elif overlay == "map":
		_draw_map(rect)
	elif overlay == "rewards":
		_draw_rewards(rect)
	elif overlay == "codex":
		_draw_codex(rect)
	elif overlay == "inspect":
		_draw_inspect(rect)
	elif overlay == "pause":
		_draw_pause(rect)
	_draw_button(Rect2(1277, 72, 44, 43), "×", {"type": "close"}, false, 21)
	_draw_corner_marks(rect)

func _draw_inventory(rect: Rect2) -> void:
	_draw_label("PACK  /  EQUIPMENT", 131, 103, 20, COLORS.text)
	_draw_label("Thirty field slots · two-handed arms fill both hands", 132, 127, 12, COLORS.muted)
	_draw_panel(Rect2(124, 150, 295, 550), "WORN", COLORS.line_soft)
	var slots: Array = ["Weapon", "Offhand", "Head", "Body", "Hands", "Feet", "Ring 1", "Ring 2", "Amulet"]
	for i in range(slots.size()):
		var slot: String = slots[i]
		var y := 189 + i * 49
		_draw_label(slot.to_upper(), 145, y, 10, COLORS.gold)
		var equipment_id: String = sim.run.equipment.get(slot, "")
		var item_name: String = "Empty" if equipment_id in ["", "occupied"] else String(sim.content.items.get(equipment_id, {}).get("name", equipment_id))
		if equipment_id == "occupied":
			item_name = "Occupied by two-handed weapon"
		_draw_label(String(item_name).substr(0, 26), 145, y + 22, 13, COLORS.text if equipment_id != "" else COLORS.muted)
	_draw_panel(Rect2(433, 150, 880, 385), "PACK  ·  %d / 30" % sim.run.inventory.size(), COLORS.line_soft)
	for i in range(sim.run.inventory.size()):
		var item_id: String = sim.run.inventory[i]
		var item: Dictionary = sim.content.items.get(item_id, {})
		var col := i % 6
		var row := int(i / 6)
		var item_rect := Rect2(448 + col * 142, 185 + row * 65, 132, 56)
		var active := selected_inventory_index == i
		_draw_panel(item_rect, "", COLORS.gold if active else COLORS.line_soft)
		_draw_label(String(item.get("name", item_id)).substr(0, 21), item_rect.position.x + 9, item_rect.position.y + 22, 11, COLORS.text)
		_draw_label(String(item.get("type", "item")).to_upper(), item_rect.position.x + 9, item_rect.position.y + 42, 9, COLORS.cyan if item.get("type") == "spellbook" else COLORS.muted)
		active_hits.append({"rect": item_rect, "action": {"type": "select_item", "index": i}})
	if selected_inventory_index >= 0 and selected_inventory_index < sim.run.inventory.size():
		var selected_id: String = sim.run.inventory[selected_inventory_index]
		var selected: Dictionary = sim.content.items.get(selected_id, {})
		_draw_panel(Rect2(433, 550, 880, 146), "ITEM DETAILS", COLORS.line_soft)
		_draw_label(String(selected.name), 451, 586, 18, COLORS.text)
		_draw_label(String(selected.get("description", "A useful object from the March.")), 451, 612, 13, COLORS.muted)
		if selected.get("type") == "spellbook":
			_draw_label("Contents:  %s" % ", ".join(selected.contents), 451, 638, 12, COLORS.purple)
			_draw_label("Study: %s" % sim.content.abilities[selected.learns[selected_book_ability]].name, 451, 664, 11, COLORS.purple)
			_draw_button(Rect2(1040, 568, 122, 48), "STUDY", {"type": "study_book"}, true, 12)
			for book_index in range(selected.learns.size()):
				var book_button := Rect2(738 + book_index * 94, 652, 87, 32)
				_draw_button(book_button, String(sim.content.abilities[selected.learns[book_index]].name).substr(0, 11), {"type": "select_book_ability", "index": book_index}, selected_book_ability == book_index, 9)
		elif selected.get("type") == "equipment":
			_draw_button(Rect2(1040, 568, 122, 48), "EQUIP", {"type": "equip"}, true, 13)
		elif selected.get("type") in ["consumable", "scroll"]:
			_draw_button(Rect2(1040, 568, 122, 48), "USE ITEM", {"type": "use_item"}, true, 12)
		_draw_button(Rect2(1172, 568, 122, 48), "DISCARD", {"type": "discard"}, false, 12)
	else:
		_draw_label("Choose a pack item to see its use, details or equipment action.", 455, 615, 14, COLORS.muted)
	_draw_button(Rect2(121, 710, 180, 30), "BACK TO BATTLE", {"type": "close"}, false, 10)
	_draw_label("ARTIFACTS  ·  %s" % (", ".join(_artifact_names()) if not sim.run.artifacts.is_empty() else "None carried"), 326, 732, 10, COLORS.gold)

func _draw_abilities(rect: Rect2) -> void:
	_draw_label("CHARACTER  /  ABILITY WEB", 131, 103, 20, COLORS.text)
	_draw_label("Ability points  %d  ·  XP %d  ·  Level %d" % [sim.run.skill_points, sim.run.xp, sim.run.level], 132, 128, 12, COLORS.gold)
	_draw_panel(Rect2(124, 151, 720, 546), "KNOWN · TAP TO TARGET", COLORS.line_soft)
	var known: Array = sim.get_available_abilities()
	for i in range(known.size()):
		var ability_id: String = known[i]
		var ability: Dictionary = sim.content.abilities[ability_id]
		var col := i % 2
		var row := int(i / 2)
		var item_rect := Rect2(141 + col * 350, 187 + row * 57, 328, 48)
		_draw_panel(item_rect, "", COLORS.line_soft)
		_draw_label(String(ability.name), item_rect.position.x + 11, item_rect.position.y + 20, 13, _school_color(ability.school))
		_draw_label("%s  ·  %d time  ·  %s" % [ability.school, ability.time, _cost_text(ability.costs)], item_rect.position.x + 11, item_rect.position.y + 38, 10, COLORS.muted)
		active_hits.append({"rect": item_rect, "action": {"type": "ability", "id": ability_id}})
	_draw_panel(Rect2(864, 151, 449, 546), "AVAILABLE PATHS", COLORS.line_soft)
	var candidates: Array = ["firebolt", "fireball", "frostbolt", "frozen_ground", "lightning_bolt", "blink", "cleave", "aimed_shot", "parry", "dagger_flurry", "mend"]
	var shown := 0
	for ability_id in candidates:
		if sim.run.known.has(ability_id):
			continue
		var ability: Dictionary = sim.content.abilities[ability_id]
		var prereqs: Array = ability.get("requires", [])
		var can_meet := true
		for required in prereqs:
			if not sim.run.known.has(required):
				can_meet = false
		var school := String(ability.get("school", ""))
		var school_ok: bool = school in ["Swordsmanship", "Defense", "Mobility", "Heavy Weapons", "Daggers", "Archery"] or sim.run.schools.has(school) or sim.run.character_id == "jim"
		if ability.get("discovery_required", false) and not sim.run.schools.has(school):
			school_ok = false
		var unlocked: bool = can_meet and school_ok and int(sim.run.skill_points) > 0
		var item_rect := Rect2(881, 187 + shown * 43, 414, 37)
		_draw_label(String(ability.name), item_rect.position.x, item_rect.position.y + 16, 12, COLORS.text if unlocked else COLORS.muted)
		var label := "LEARN" if unlocked else "LOCKED"
		_draw_label(label, item_rect.end.x - 6, item_rect.position.y + 16, 9, COLORS.green if unlocked else Color("#60707a"), HORIZONTAL_ALIGNMENT_RIGHT)
		_draw_label("%s%s" % [school, " · needs " + ", ".join(prereqs) if not can_meet else ""], item_rect.position.x, item_rect.position.y + 32, 9, COLORS.muted)
		if unlocked:
			active_hits.append({"rect": item_rect, "action": {"type": "learn", "id": ability_id}})
		shown += 1
		if shown >= 11:
			break
	_draw_button(Rect2(121, 651, 180, 43), "BACK TO BATTLE", {"type": "close"}, false, 12)

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
			_draw_label(stage.name, card.position.x + 20, card.position.y + 40, 21, COLORS.text)
			_draw_label(String(stage.subtitle), card.position.x + 20, card.position.y + 68, 14, COLORS.muted)
			_draw_label("HOSTILES", card.position.x + 20, card.position.y + 107, 10, COLORS.gold)
			_draw_label(", ".join(stage.enemies.map(func(id: String) -> String: return String(sim.content.enemies[id].name))), card.position.x + 20, card.position.y + 132, 13, COLORS.text)
			_draw_label("TERRAIN  ·  %s" % ", ".join(stage.terrain.keys()), card.position.x + 20, card.position.y + 158, 11, COLORS.cyan)
			_draw_button(Rect2(card.position.x + 17, card.position.y + 170, card.size.x - 34, 25), "TRAVEL HERE", {"type": "route", "id": stage_id}, true, 10)
	else:
		_draw_label("The final road leads to the Old Graveyard. The Grave Tyrant is waiting.", 176, 402, 17, COLORS.text)
		_draw_label("Bring every spell, summon and weapon you have learned.", 176, 437, 14, COLORS.muted)
		_draw_button(Rect2(175, 488, 470, 72), "ENTER THE BARROW", {"type": "boss"}, true, 17)
	_draw_button(Rect2(129, 651, 180, 43), "BACK TO BATTLE", {"type": "close"}, false, 12)

func _draw_rewards(rect: Rect2) -> void:
	_draw_label("ENCOUNTER COMPLETE", 131, 105, 23, COLORS.text)
	_draw_label("Gather a reward, or return to the field and keep exploring.", 132, 131, 13, COLORS.muted)
	_draw_panel(Rect2(127, 164, 1185, 411), "CHOOSE ONE REWARD", COLORS.line_soft)
	for i in range(sim.run.reward_choices.size()):
		var reward: Dictionary = sim.run.reward_choices[i]
		var entry: Dictionary = sim.content.artifacts[reward.id] if reward.type == "artifact" else sim.content.items[reward.id]
		var card := Rect2(153 + i * 376, 213, 350, 292)
		_draw_panel(card, "", COLORS.gold if reward.get("claimed", false) else COLORS.line)
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
		_draw_button(Rect2(card.position.x + 19, card.position.y + 232, card.size.x - 38, 43), "CLAIMED" if reward.get("claimed", false) else "CLAIM REWARD", {"type": "claim_reward", "index": i}, not reward.get("claimed", false), 12)
	_draw_label("%d XP  ·  %d KILLS  ·  %d / 6 ENCOUNTERS" % [sim.run.xp, sim.run.kills, sim.run.encounters_completed], 155, 616, 13, COLORS.gold)
	_draw_button(Rect2(128, 651, 205, 43), "KEEP EXPLORING", {"type": "close"}, false, 12)
	_draw_button(Rect2(1042, 651, 270, 43), "NEXT STAGE  →", {"type": "next_stage"}, true, 13)

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
			for j in range(mini(7, values.size())):
				var value_name := _content_display_name(String(values[j]))
				_draw_label("✦  %s" % value_name, x + 18, y + 66 + j * 19, 12, COLORS.text)
	_draw_button(Rect2(128, 651, 180, 43), "BACK TO BATTLE" if page == "battle" else "RETURN", {"type": "close"}, false, 12)

func _draw_inspect(rect: Rect2) -> void:
	var enemy: Dictionary = sim.run.entities.get(selected_enemy, {})
	_draw_label("CREATURE RECORD", 131, 103, 20, COLORS.text)
	if enemy.is_empty():
		_draw_label("No creature is selected.", 145, 180, 15, COLORS.muted)
	else:
		_draw_label(String(enemy.get("name", "Creature")), 147, 180, 25, COLORS.red)
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
	_draw_button(Rect2(128, 651, 180, 43), "RETURN", {"type": "close"}, false, 12)

func _draw_pause(rect: Rect2) -> void:
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
	_draw_label("%d / %d" % [current, maximum], rect.end.x - 4, rect.position.y + 15, 10, COLORS.text, HORIZONTAL_ALIGNMENT_RIGHT)

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
	active_hits.append({"rect": rect, "action": action})

func _draw_dpad_button(rect: Rect2, glyph: String, direction: Vector2i) -> void:
	draw_rect(rect, COLORS.panel_2)
	draw_rect(rect, COLORS.line, false, 1)
	_draw_label(glyph, rect.get_center().x, rect.get_center().y + 5, 14, COLORS.text, HORIZONTAL_ALIGNMENT_CENTER)
	active_hits.append({"rect": rect, "action": {"type": "dpad", "direction": [direction.x, direction.y]}})

func _draw_label(text: String, x: float, y: float, size: int, color: Color, alignment: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var draw_x := x
	if alignment != HORIZONTAL_ALIGNMENT_LEFT:
		var measured: Vector2 = ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size)
		if alignment == HORIZONTAL_ALIGNMENT_CENTER:
			draw_x -= measured.x * 0.5
		elif alignment == HORIZONTAL_ALIGNMENT_RIGHT:
			draw_x -= measured.x
	draw_string(ThemeDB.fallback_font, Vector2(draw_x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)

func _draw_line(x1: float, y1: float, x2: float, y2: float, color: Color) -> void:
	draw_line(Vector2(x1, y1), Vector2(x2, y2), color, 1.0)

func _cell_center(cell: Vector2i) -> Vector2:
	return BOARD_ORIGIN + Vector2(cell.x * TILE + TILE * 0.5, cell.y * TILE + TILE * 0.5)

func _logical_position(point: Vector2) -> Vector2:
	var viewport := get_viewport_rect().size
	var scale_factor := minf(viewport.x / LOGICAL_SIZE.x, viewport.y / LOGICAL_SIZE.y)
	var offset := (viewport - LOGICAL_SIZE * scale_factor) * 0.5
	return (point - offset) / scale_factor

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var right_pos := _logical_position(event.position)
			if page == "battle" and _point_in_board(right_pos):
				_inspect_cell(_cell_from_point(right_pos), true)
				accept_event()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				press_position = _logical_position(event.position)
				press_started = Time.get_ticks_msec()
				is_touch_press = false
			else:
				var point := _logical_position(event.position)
				if Time.get_ticks_msec() - press_started >= 500:
					if page == "battle" and _point_in_board(point):
						_inspect_cell(_cell_from_point(point), true)
				else:
					_handle_tap(point)
				accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:
			press_position = _logical_position(event.position)
			press_started = Time.get_ticks_msec()
			is_touch_press = true
		else:
			var point := _logical_position(event.position)
			if Time.get_ticks_msec() - press_started >= 500:
				if page == "battle" and _point_in_board(point):
					_inspect_cell(_cell_from_point(point), true)
			else:
				_handle_tap(point)
			accept_event()
	elif event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event)
		accept_event()

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
		"resume":
			if sim.resume_run():
				page = "battle" if sim.run.get("outcome", "") == "" else "outcome"
				overlay = ""
			else:
				_show_notice("The saved expedition could not be opened.")
		"title_codex":
			sim._load_codex()
			page = "title"
			overlay = "codex"
		"overlay":
			overlay = String(action.id)
			selected_inventory_index = -1
			selected_enemy = "" if action.id != "inspect" else selected_enemy
		"close":
			overlay = ""
		"target_mode":
			target_mode = String(action.mode)
			selected_enemy = ""
		"ability":
			var ability_id: String = action.id
			var ability: Dictionary = sim.content.abilities[ability_id]
			if ability.get("target", "enemy") == "self":
				_commit_action(sim.act({"type": "cast", "id": ability_id, "target": sim.get_player().pos}))
			else:
				target_mode = ability_id
				overlay = ""
		"inspect":
			selected_enemy = String(action.id)
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
				target_mode = "item:%d" % item_index
			else:
				_commit_action(sim.use_item(item_index))
		"use_item":
			if selected_inventory_index >= 0:
				var item_id: String = sim.run.inventory[selected_inventory_index]
				var item: Dictionary = sim.content.items[item_id]
				if item.get("effect") == "bomb":
					target_mode = "item:%d" % selected_inventory_index
					overlay = ""
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
		"select_item":
			selected_inventory_index = int(action.index)
		"study_book":
			if sim.study_spellbook(selected_inventory_index, selected_book_ability):
				_show_notice("%s studied. Knowledge is recorded in your Codex." % sim.content.abilities[sim.run.known.back()].name)
		"select_book_ability":
			selected_book_ability = int(action.index)
		"route":
			if sim.choose_route(String(action.id)):
				overlay = ""
				selected_enemy = ""
		"boss":
			if sim.start_boss():
				overlay = ""
				selected_enemy = ""
		"next_stage":
			if sim.run.get("outcome", "") == "victory":
				page = "outcome"
				overlay = ""
			elif sim.run.get("stage_completed", false):
				overlay = "map"
		"claim_reward":
			if sim.claim_reward(int(action.index)):
				_show_notice("Reward secured. You may keep exploring.")
		"learn":
			if sim.learn_ability(String(action.id)):
				_show_notice("Ability learned.")
		"save":
			sim.save_run()
			_show_notice("Run saved.")
		"title":
			page = "title"
			overlay = ""
			selected_enemy = ""
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
		_show_notice("%s · tap Weapon Attack or an ability to act." % entity.name)
		return
	if not sim._cell_visible(cell):
		_show_notice("That tile is still hidden by fog of war.")
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
		_show_notice("%s tile  ·  %s" % [sim.get_stage_name(), sim._terrain_at(cell)])
	queue_redraw()

func _handle_key(event: InputEventKey) -> void:
	if event.keycode == KEY_ESCAPE:
		if target_mode != "":
			target_mode = ""
		elif overlay != "":
			overlay = ""
		else:
			overlay = "pause"
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
	return Vector2i(int(floor((point.x - BOARD_ORIGIN.x) / TILE)), int(floor((point.y - BOARD_ORIGIN.y) / TILE)))

func _point_in_board(point: Vector2) -> bool:
	return BOARD_RECT.has_point(point)

func _show_notice(message: String) -> void:
	notice = message
	notice_until = Time.get_ticks_msec() + 2800
	queue_redraw()

func _school_color(school: String) -> Color:
	if school in ["Fire", "Demonology"]: return COLORS.orange
	if school in ["Frost", "Storm", "Arcane"]: return COLORS.cyan
	if school in ["Blood", "Necromancy", "Shadow"]: return COLORS.blood
	if school in ["Nature", "Summoning"]: return COLORS.green
	return COLORS.gold

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
