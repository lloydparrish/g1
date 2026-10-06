extends RefCounted

var host

const SLOT_NAMES := ["Head", "Body", "Hands", "Feet", "Weapon", "Offhand", "Ring 1", "Ring 2", "Amulet"]
const SECTION_NAMES := ["World Map", "Character / Abilities", "Inventory / Equipment", "Spellbook / Discovery"]
const SECTION_IDS := ["world_map", "character", "inventory", "spellbook"]
const SECTION_GLYPHS := ["⌖", "✦", "▦", "▤"]
const SECTION_COLORS := ["green", "cyan", "gold", "purple"]

func draw() -> void:
	var layout: Dictionary = host._battle_layout()
	var screen_width: float = host.screen_size.x
	var column_gap := 6.0
	var column_width := (screen_width - 36.0 - column_gap * 3.0) / 4.0
	var dock_top: float = layout.dock_top
	var bottom: float = layout.dock_bottom
	var header_height: float = layout.dock_header_height
	var expanded: bool = host.ui_state.lower_dock_expanded
	var active_id := String(host.ui_state.active_lower_panel)
	for index in range(SECTION_IDS.size()):
		var section_id: String = SECTION_IDS[index]
		var x := 18.0 + float(index) * (column_width + column_gap)
		var active := expanded and section_id == active_id
		var panel_height := bottom - dock_top if active else minf(72.0, bottom - dock_top)
		var panel_rect := Rect2(x, dock_top, column_width, panel_height)
		var accent: Color = _section_color(index)
		host._draw_panel(panel_rect, "", accent if active else host.COLORS.line_soft)
		var header_rect := Rect2(x + 2.0, dock_top + 2.0, column_width - 4.0, header_height - 4.0)
		host.draw_rect(Rect2(header_rect.position.x, header_rect.position.y, 3.0, header_rect.size.y), accent)
		host._draw_label(SECTION_GLYPHS[index], x + 18.0, dock_top + header_height * 0.66, 15, accent)
		host._draw_label(host._fit_text(String(SECTION_NAMES[index]).to_upper(), column_width - 48.0, 9), x + 35.0, dock_top + header_height * 0.64, 9, host.COLORS.text)
		host.active_hits.append({"rect": host._touch_hit_rect(header_rect), "action": {"type": "lower_panel", "id": section_id}})
		if expanded and not active:
			host._draw_label(_section_summary(section_id), x + 12.0, dock_top + header_height + 21.0, 8, host.COLORS.muted)
	if not expanded or active_id == "":
		return
	var active_index: int = SECTION_IDS.find(active_id)
	if active_index < 0:
		return
	var active_x := 18.0 + float(active_index) * (column_width + column_gap)
	var body := Rect2(active_x + 8.0, dock_top + header_height + 4.0, column_width - 16.0, bottom - dock_top - header_height - 12.0)
	match active_id:
		"world_map": _draw_world_map(body)
		"character": _draw_character(body)
		"inventory": _draw_inventory(body)
		"spellbook": _draw_spellbook(body)

func _section_summary(section_id: String) -> String:
	var sim = host.sim
	match section_id:
		"world_map": return "%s  ·  %d / 6" % [sim.get_stage_name(), int(sim.run.get("stage_index", 0)) + 1]
		"character": return "Level %d  ·  %d known" % [int(sim.run.get("level", 1)), sim.run.get("known", []).size()]
		"inventory": return "%d / 30 items  ·  %d artifacts" % [sim.run.get("inventory", []).size(), sim.run.get("artifacts", []).size()]
		"spellbook": return "%d discoveries" % sim.run.get("discovered_books", []).size()
	return ""

func _section_color(index: int) -> Color:
	match SECTION_COLORS[index]:
		"green": return host.COLORS.green
		"cyan": return host.COLORS.cyan
		"gold": return host.COLORS.gold
		"purple": return host.COLORS.purple
	return host.COLORS.text

func _draw_world_map(rect: Rect2) -> void:
	var sim = host.sim
	var x := rect.position.x
	var y := rect.position.y
	var current_id := String(sim.run.get("stage_id", ""))
	var history: Array = sim.run.get("route", [])
	var history_count := mini(5, history.size())
	var track_y := y + 23.0
	host._draw_label("RUN PATH", x + 2.0, y + 11.0, 8, host.COLORS.gold)
	if history_count > 1:
		for i in range(history_count - 1):
			var left_x := x + 13.0 + float(i) * 42.0
			var right_x := x + 55.0 + float(i) * 42.0
			host.draw_line(Vector2(left_x, track_y), Vector2(right_x, track_y), host.COLORS.line, 1.5)
	for i in range(history_count):
		var stage_id := String(history[history.size() - history_count + i])
		var node_x := x + 13.0 + float(i) * 42.0
		var is_current := stage_id == current_id and i == history_count - 1
		var node_color: Color = host.COLORS.gold if is_current else host.COLORS.cyan
		host.draw_circle(Vector2(node_x, track_y), 6.0 if is_current else 4.0, node_color)
		host.draw_arc(Vector2(node_x, track_y), 8.0, 0.0, TAU, 20, node_color, 1.2)
		var node_name := String(sim.content.stages.get(stage_id, {}).get("name", "Boss" if stage_id == "grave_tyrant" else stage_id))
		host._draw_label(host._fit_text(node_name, 38.0, 6), node_x, track_y + 17.0, 6, host.COLORS.text if is_current else host.COLORS.muted, HORIZONTAL_ALIGNMENT_CENTER)
	var current_stage: Dictionary = sim.content.stages.get(current_id, {})
	host._draw_label("CURRENT  ·  %s" % host._fit_text(String(current_stage.get("name", sim.get_stage_name())), rect.size.x - 14.0, 8), x + 2.0, y + 57.0, 8, host.COLORS.text)
	var connector_x := x + 14.0
	var branch_y := y + 87.0
	host.draw_circle(Vector2(connector_x, branch_y), 5.0, host.COLORS.gold)
	var route_choices: Array = sim.run.get("route_choices", [])
	if int(sim.run.get("stage_index", 0)) >= 4 and sim.run.get("stage_completed", false):
		var boss_rect := Rect2(x + 31.0, y + 70.0, rect.size.x - 40.0, 50.0)
		host.draw_line(Vector2(connector_x + 6.0, branch_y), Vector2(boss_rect.position.x, boss_rect.get_center().y), host.COLORS.gold, 1.5)
		host._draw_button(boss_rect, "GRAVE TYRANT  ·  BOSS", {"type": "boss"}, true, 8, host.COLORS.red)
	elif route_choices.is_empty():
		for branch in range(2):
			var cy := y + 78.0 + float(branch) * 45.0
			host.draw_line(Vector2(connector_x + 5.0, branch_y), Vector2(x + 42.0, cy), host.COLORS.line, 1.0)
			host.draw_circle(Vector2(x + 47.0, cy), 5.0, host.COLORS.line)
			host._draw_label("?  DESTINATION REVEALED AFTER ENCOUNTER", x + 60.0, cy + 3.0, 7, host.COLORS.muted)
	else:
		for i in range(mini(2, route_choices.size())):
			var stage_id := String(route_choices[i])
			var stage: Dictionary = sim.content.stages.get(stage_id, {})
			var row_y := y + 63.0 + float(i) * 58.0
			var row := Rect2(x + 31.0, row_y, rect.size.x - 35.0, 58.0)
			host.draw_line(Vector2(connector_x + 5.0, branch_y), Vector2(row.position.x, row.get_center().y), host.COLORS.line, 1.0)
			var selected := String(host.ui_state.selected_map_node_id) == stage_id
			var glyph := "◇" if stage_id != "graveyard" else "☠"
			host._draw_panel(row, "", host.COLORS.gold if selected else host.COLORS.line_soft)
			host._draw_label(glyph, row.position.x + 11.0, row.position.y + 22.0, 14, host.COLORS.green if stage.get("objective", "") != "Boss" else host.COLORS.red)
			host._draw_label(host._fit_text(String(stage.get("name", stage_id)), row.size.x - 90.0, 8), row.position.x + 25.0, row.position.y + 20.0, 8, host.COLORS.text)
			host._draw_label("%s  ·  %s" % [String(stage.get("subtitle", "Connected route")), "EVENT" if stage_id == "shrine" else "COMBAT"], row.position.x + 25.0, row.position.y + 37.0, 6, host.COLORS.muted)
			host.active_hits.append({"rect": Rect2(row.position, Vector2(row.size.x - 67.0, row.size.y)), "action": {"type": "select_map_node", "id": stage_id}})
			host._draw_button(Rect2(row.end.x - 66.0, row.position.y + 2.0, 62.0, 54.0), "GO", {"type": "route", "id": stage_id}, true, 8, host.COLORS.green)
	if sim.run.get("stage_completed", false) and route_choices.is_empty() and int(sim.run.get("stage_index", 0)) < 4:
		host._draw_label("No connected route is available.", x + 32.0, rect.end.y - 9.0, 7, host.COLORS.muted)
	elif not sim.run.get("stage_completed", false):
		host._draw_label("Choose a connected destination after the encounter.", x + 2.0, rect.end.y - 8.0, 7, host.COLORS.muted)

func _draw_character(rect: Rect2) -> void:
	var sim = host.sim
	var tabs := ["Character", "Abilities", "Passives", "Known"]
	var tab_width := rect.size.x / float(tabs.size())
	for i in range(tabs.size()):
		var tab_rect := Rect2(rect.position.x + float(i) * tab_width, rect.position.y, tab_width - 2.0, 25.0)
		var tab := String(tabs[i])
		host._draw_button(tab_rect, tab, {"type": "lower_character_tab", "id": tab}, host.ui_state.character_tab == tab, 7, host.COLORS.cyan)
	var y := rect.position.y + 30.0
	var x := rect.position.x + 2.0
	if host.ui_state.character_tab == "Character":
		var player: Dictionary = host._display_player()
		host._draw_label("LEVEL %d  ·  %d XP  ·  %d ABILITY POINTS" % [int(sim.run.get("level", 1)), int(sim.run.get("xp", 0)), int(sim.run.get("skill_points", 0))], x, y + 8.0, 7, host.COLORS.gold)
		var attrs: Dictionary = sim.run.get("attributes", {})
		var names := ["Might", "Dexterity", "Vitality", "Intelligence", "Willpower", "Perception"]
		for i in range(names.size()):
			var column := i % 2
			var row := int(i / 2)
			host._draw_label("%s  %d" % [String(names[i]).substr(0, 3).to_upper(), int(attrs.get(names[i], 10))], x + float(column) * 150.0, y + 34.0 + float(row) * 19.0, 8, host.COLORS.text)
		host._draw_label("WEAPON  ·  %s" % String(sim.content.items.get(sim.run.equipment.get("Weapon", ""), {}).get("name", "Unarmed")), x, y + 98.0, 8, host.COLORS.muted)
		host._draw_button(Rect2(rect.end.x - 100.0, rect.end.y - 38.0, 92.0, 34.0), "OPEN WEB", {"type": "overlay", "id": "ability_web"}, false, 7, host.COLORS.cyan)
		return
	var entries: Array[String] = []
	if host.ui_state.character_tab == "Known":
		for node in sim.get_progression_graph(): entries.append(String(node.id))
	else:
		for ability_id in sim.run.get("known", []):
			if not sim.content.abilities.has(ability_id): continue
			var kind := String(sim.content.abilities[ability_id].get("kind", "active"))
			if host.ui_state.character_tab == "Passives" and kind == "passive": entries.append(String(ability_id))
			elif host.ui_state.character_tab == "Abilities" and kind != "passive": entries.append(String(ability_id))
	var page_size := 4
	var page_count := maxi(1, int(ceil(float(entries.size()) / float(page_size))))
	host.ui_state.ability_page = clampi(int(host.ui_state.ability_page), 0, page_count - 1)
	for local_index in range(page_size):
		var index := int(host.ui_state.ability_page) * page_size + local_index
		if index >= entries.size(): continue
		var ability_id := entries[index]
		var ability: Dictionary = sim.content.abilities.get(ability_id, {})
		var progress: Dictionary = sim.get_ability_progress(ability_id)
		var learned: bool = sim.run.get("known", []).has(ability_id)
		var equipped: bool = host._is_quickbar_assigned("ability", ability_id)
		var state := "EQUIPPED" if equipped else "KNOWN" if learned and ability.get("kind", "active") != "passive" else "PASSIVE" if learned else "READY" if progress.get("learnable", false) else "LOCKED"
		var color: Color = host._school_color(String(ability.get("school", "")))
		var card_width := (rect.size.x - 8.0) * 0.5
		var row := int(local_index / 2)
		var column := local_index % 2
		var card := Rect2(x + float(column) * (card_width + 6.0), y + float(row) * 47.0, card_width, 44.0)
		var active := String(host.ui_state.selected_ability_id) == ability_id
		host._draw_panel(card, "", host.COLORS.gold if active else color if learned or progress.get("learnable", false) else host.COLORS.line_soft)
		host._draw_label(host._ability_glyph(ability), card.position.x + 14.0, card.position.y + 23.0, 15, color)
		host._draw_label(host._fit_text(String(ability.get("name", ability_id)), card.size.x - 28.0, 7), card.position.x + 27.0, card.position.y + 17.0, 7, host.COLORS.text)
		host._draw_label(state, card.position.x + 27.0, card.position.y + 33.0, 6, host.COLORS.green if equipped or learned else host.COLORS.gold if progress.get("learnable", false) else host.COLORS.muted)
		host.active_hits.append({"rect": card, "action": {"type": "select_lower_ability", "id": ability_id}})
	var chosen_id := String(host.ui_state.selected_ability_id)
	var chosen: Dictionary = sim.content.abilities.get(chosen_id, {})
	var chosen_progress: Dictionary = sim.get_ability_progress(chosen_id) if not chosen.is_empty() else {}
	var chosen_learned: bool = sim.run.get("known", []).has(chosen_id)
	var footer_y := rect.end.y - 26.0
	if not chosen.is_empty():
		var action_kind := String(chosen.get("kind", "active"))
		var info := "%s  ·  %s" % [String(chosen.get("school", "Known")), "PASSIVE" if action_kind == "passive" else "%d  ·  %s" % [int(chosen.get("time", 0)), host._cost_text(chosen.get("costs", {}))]]
		host._draw_label(host._fit_text(info, rect.size.x - 102.0, 7), x, footer_y + 2.0, 7, host.COLORS.muted)
		if chosen_learned and action_kind != "passive":
			var assigned: bool = host._is_quickbar_assigned("ability", chosen_id)
			host._draw_button(Rect2(rect.end.x - 96.0, footer_y - 17.0, 94.0, 38.0), "REMOVE BAR" if assigned else "EQUIP SLOT", {"type": "remove_quickbar_assignment" if assigned else "begin_quickbar_assignment", "kind": "ability", "id": chosen_id}, assigned, 7, host.COLORS.gold)
		elif not chosen_learned and chosen_progress.get("learnable", false):
			host._draw_button(Rect2(rect.end.x - 96.0, footer_y - 17.0, 94.0, 38.0), "LEARN", {"type": "learn", "id": chosen_id}, true, 8, host.COLORS.green)
	if page_count > 1:
		host._draw_button(Rect2(x, rect.end.y - 35.0, 42.0, 32.0), "‹", {"type": "lower_ability_page", "delta": -1}, true, 12)
		host._draw_label("%d / %d" % [int(host.ui_state.ability_page) + 1, page_count], x + 52.0, rect.end.y - 5.0, 7, host.COLORS.muted)
		host._draw_button(Rect2(x + 91.0, rect.end.y - 35.0, 42.0, 32.0), "›", {"type": "lower_ability_page", "delta": 1}, true, 12)
	# Ability Web remains available from the Character tab, away from the four management tabs.

func _draw_inventory(rect: Rect2) -> void:
	var sim = host.sim
	var tabs := ["Equipment", "Inventory", "Artifacts", "Spellbooks"]
	var tab_width := rect.size.x / float(tabs.size())
	for i in range(tabs.size()):
		var tab := String(tabs[i])
		var tab_rect := Rect2(rect.position.x + float(i) * tab_width, rect.position.y, tab_width - 2.0, 24.0)
		host._draw_button(tab_rect, tab, {"type": "lower_inventory_tab", "id": tab}, host.ui_state.inventory_tab == tab, 6, host.COLORS.cyan)
	var body := Rect2(rect.position.x, rect.position.y + 31.0, rect.size.x, rect.size.y - 31.0)
	match host.ui_state.inventory_tab:
		"Equipment": _draw_equipment(body)
		"Inventory": _draw_pack(body)
		"Artifacts": _draw_artifacts(body)
		"Spellbooks": _draw_owned_books(body)

func _draw_equipment(rect: Rect2) -> void:
	var sim = host.sim
	var width := (rect.size.x - 8.0) / 3.0
	for i in range(SLOT_NAMES.size()):
		var slot := String(SLOT_NAMES[i])
		var item_id := String(sim.run.equipment.get(slot, ""))
		var item: Dictionary = sim.content.items.get(item_id, {})
		var occupied := item_id not in ["", "occupied"]
		var row := int(i / 3)
		var column := i % 3
		var slot_rect := Rect2(rect.position.x + float(column) * width, rect.position.y + float(row) * 54.0, width - 4.0, 48.0)
		host._draw_panel(slot_rect, "", host.COLORS.gold if occupied else host.COLORS.line_soft)
		host._draw_label(slot.to_upper(), slot_rect.position.x + 5.0, slot_rect.position.y + 11.0, 6, host.COLORS.gold)
		host._draw_label("⊕" if item_id == "occupied" else host._item_glyph(item_id, item) if occupied else "·", slot_rect.get_center().x, slot_rect.position.y + 31.0, 15, host.COLORS.cyan if item_id == "occupied" else host.COLORS.gold if occupied else host.COLORS.muted, HORIZONTAL_ALIGNMENT_CENTER)
		host._draw_label(host._fit_text("Two-hand" if item_id == "occupied" else String(item.get("name", "Empty")), width - 8.0, 6), slot_rect.get_center().x, slot_rect.position.y + 41.0, 6, host.COLORS.text if occupied else host.COLORS.muted, HORIZONTAL_ALIGNMENT_CENTER)
		if occupied:
			host.active_hits.append({"rect": host._touch_hit_rect(slot_rect), "action": {"type": "unequip", "slot": slot}})

func _draw_pack(rect: Rect2) -> void:
	var sim = host.sim
	var grid_width := rect.size.x * 0.72
	var cell_width := grid_width / 6.0
	var grid_top := rect.position.y + 17.0
	host._draw_label("PACK  ·  %d / 30" % sim.run.inventory.size(), rect.position.x + 1.0, rect.position.y + 9.0, 7, host.COLORS.gold)
	for i in range(30):
		var row := int(i / 6)
		var column := i % 6
		var item_rect := Rect2(rect.position.x + float(column) * cell_width, grid_top + float(row) * 34.0, cell_width - 2.0, 32.0)
		if i >= sim.run.inventory.size():
			host._draw_panel(item_rect, "", Color("#111a23"))
			continue
		var item_id := String(sim.run.inventory[i])
		var item: Dictionary = sim.content.items.get(item_id, {})
		var rarity := String(item.get("rarity", "Common"))
		var selected := int(host.ui_state.selected_inventory_index) == i
		var accent: Color = host._item_color(String(item.get("type", "item")), rarity)
		host._draw_panel(item_rect, "", host.COLORS.gold if selected else host.COLORS.line_soft if rarity == "Common" else accent)
		host._draw_label(host._item_glyph(item_id, item), item_rect.get_center().x, item_rect.position.y + 21.0, 14, accent, HORIZONTAL_ALIGNMENT_CENTER)
		var quantity: int = sim.run.inventory.count(item_id)
		if quantity > 1: host._draw_label("×%d" % quantity, item_rect.end.x - 3.0, item_rect.position.y + 9.0, 6, host.COLORS.text, HORIZONTAL_ALIGNMENT_RIGHT)
		host.active_hits.append({"rect": item_rect, "action": {"type": "select_item", "index": i}})
	var details_x := rect.position.x + grid_width + 5.0
	var details_width := rect.end.x - details_x
	if int(host.ui_state.selected_inventory_index) >= 0 and int(host.ui_state.selected_inventory_index) < sim.run.inventory.size():
		var item_id := String(sim.run.inventory[int(host.ui_state.selected_inventory_index)])
		var item: Dictionary = sim.content.items.get(item_id, {})
		host._draw_label(host._item_glyph(item_id, item), details_x + details_width * 0.5, grid_top + 24.0, 22, host._item_color(String(item.get("type", "item")), String(item.get("rarity", "Common"))), HORIZONTAL_ALIGNMENT_CENTER)
		host._draw_label(host._fit_text(String(item.get("name", item_id)), details_width, 7), details_x + details_width * 0.5, grid_top + 43.0, 7, host.COLORS.text, HORIZONTAL_ALIGNMENT_CENTER)
		var type := String(item.get("type", ""))
		if type in ["consumable", "scroll"]:
			var assigned: bool = host._is_quickbar_assigned("item", item_id)
			var label: String = "REMOVE BAR" if assigned else "EQUIP SLOT" if item.get("effect", "") == "bomb" or type == "scroll" else "ADD TO BAR"
			var action_type: String = "remove_quickbar_assignment" if assigned else "begin_quickbar_assignment"
			host._draw_button(Rect2(details_x, rect.end.y - 48.0, details_width, 42.0), label, {"type": action_type, "kind": "item", "id": item_id}, assigned, 6, host.COLORS.gold)
			var quantity: int = sim.run.inventory.count(item_id)
			host._draw_label("×%d" % quantity, details_x + details_width * 0.5, grid_top + 57.0, 7, host.COLORS.muted, HORIZONTAL_ALIGNMENT_CENTER)
		elif type == "equipment":
			host._draw_button(Rect2(details_x, rect.end.y - 48.0, details_width, 42.0), "EQUIP", {"type": "equip"}, false, 7, host.COLORS.green)
	else:
		host._draw_label("SELECT AN ITEM", details_x + details_width * 0.5, grid_top + 42.0, 7, host.COLORS.muted, HORIZONTAL_ALIGNMENT_CENTER)
	var assigned_slot := -1
	if host.quickbar_assign_mode:
		for i in range(sim.run.quickbar.size()):
			if sim.run.quickbar[i].get("type", "") == String(host.quickbar_pending.get("type", "")) and sim.run.quickbar[i].get("id", "") == String(host.quickbar_pending.get("id", "")):
				assigned_slot = i
		if assigned_slot >= 0:
			host._draw_label("ASSIGNING  ·  TAP A BAR SLOT", rect.position.x + 2.0, rect.end.y - 2.0, 6, host.COLORS.gold)

func _draw_artifacts(rect: Rect2) -> void:
	var sim = host.sim
	var values: Array = sim.run.get("artifacts", [])
	var page_size := 3
	var pages := maxi(1, int(ceil(float(values.size()) / float(page_size))))
	host.ui_state.inventory_page = clampi(int(host.ui_state.inventory_page), 0, pages - 1)
	if values.is_empty():
		host._draw_label("No artifacts carried. Artifacts have no slot limit.", rect.position.x + 4.0, rect.position.y + 28.0, 7, host.COLORS.muted)
		return
	var start := int(host.ui_state.inventory_page) * page_size
	for i in range(start, mini(start + page_size, values.size())):
		var artifact_id := String(values[i])
		var artifact: Dictionary = sim.content.artifacts.get(artifact_id, {})
		var row := Rect2(rect.position.x + 2.0, rect.position.y + float(i - start) * 46.0 + 4.0, rect.size.x - 4.0, 42.0)
		host._draw_panel(row, "", host.COLORS.purple)
		host._draw_label("◈", row.position.x + 14.0, row.position.y + 25.0, 16, host.COLORS.purple)
		host._draw_label(host._fit_text(String(artifact.get("name", artifact_id)), row.size.x - 34.0, 8), row.position.x + 29.0, row.position.y + 18.0, 8, host.COLORS.text)
		host._draw_label(host._fit_text(String(artifact.get("description", "Persistent run modifier")), row.size.x - 34.0, 6), row.position.x + 29.0, row.position.y + 33.0, 6, host.COLORS.muted)
	if pages > 1:
		host._draw_button(Rect2(rect.position.x + 3.0, rect.end.y - 31.0, 42.0, 30.0), "‹", {"type": "inventory_page", "delta": -1}, true, 11)
		host._draw_label("%d / %d  ·  NO SLOT CAP" % [int(host.ui_state.inventory_page) + 1, pages], rect.get_center().x, rect.end.y - 10.0, 6, host.COLORS.muted, HORIZONTAL_ALIGNMENT_CENTER)
		host._draw_button(Rect2(rect.end.x - 45.0, rect.end.y - 31.0, 42.0, 30.0), "›", {"type": "inventory_page", "delta": 1}, true, 11)

func _draw_owned_books(rect: Rect2) -> void:
	var sim = host.sim
	var books: Array[String] = []
	for item_id in sim.run.get("inventory", []):
		if sim.content.items.get(item_id, {}).get("type", "") == "spellbook" and not books.has(String(item_id)):
			books.append(String(item_id))
	if books.is_empty():
		host._draw_label("No spellbooks in the pack. Discovered books remain in the Codex.", rect.position.x + 3.0, rect.position.y + 28.0, 7, host.COLORS.muted)
		return
	host.ui_state.selected_spellbook_id = String(books[0]) if not books.has(String(host.ui_state.selected_spellbook_id)) else String(host.ui_state.selected_spellbook_id)
	var list_width := 106.0
	for i in range(mini(3, books.size())):
		var book_id := books[i]
		var book: Dictionary = sim.content.items[book_id]
		var row := Rect2(rect.position.x, rect.position.y + float(i) * 54.0, list_width, 48.0)
		host._draw_button(row, host._fit_text(String(book.get("name", book_id)), row.size.x - 8.0, 6), {"type": "select_lower_book", "id": book_id}, host.ui_state.selected_spellbook_id == book_id, 6, host.COLORS.purple)
	_draw_selected_book(rect, String(host.ui_state.selected_spellbook_id), true)

func _draw_spellbook(rect: Rect2) -> void:
	var sim = host.sim
	var books: Array[String] = []
	for item_id in sim.run.get("inventory", []):
		if sim.content.items.get(item_id, {}).get("type", "") == "spellbook" and not books.has(String(item_id)):
			books.append(String(item_id))
	for book_id in sim.codex.get("spellbooks", []):
		if sim.content.items.has(book_id) and not books.has(String(book_id)):
			books.append(String(book_id))
	if books.is_empty():
		host._draw_label("NO SPELLBOOKS DISCOVERED", rect.position.x + 3.0, rect.position.y + 24.0, 8, host.COLORS.muted)
		host._draw_label("Books reveal their contents before study and remain recorded after learning.", rect.position.x + 3.0, rect.position.y + 43.0, 7, host.COLORS.text)
		return
	if not books.has(String(host.ui_state.selected_spellbook_id)):
		host.ui_state.selected_spellbook_id = books[0]
	var list_width := 104.0
	for i in range(mini(3, books.size())):
		var book_id := books[i]
		var book: Dictionary = sim.content.items[book_id]
		var row := Rect2(rect.position.x, rect.position.y + float(i) * 54.0, list_width, 48.0)
		host._draw_button(row, host._fit_text(String(book.get("name", book_id)), row.size.x - 8.0, 6), {"type": "select_lower_book", "id": book_id}, host.ui_state.selected_spellbook_id == book_id, 6, host.COLORS.purple)
	_draw_selected_book(rect, String(host.ui_state.selected_spellbook_id), false)

func _draw_selected_book(rect: Rect2, book_id: String, inventory_mode: bool) -> void:
	var sim = host.sim
	var book: Dictionary = sim.content.items.get(book_id, {})
	if book.is_empty(): return
	var details_x := rect.position.x + 112.0
	var details_width := rect.end.x - details_x
	var book_index := int(sim.run.inventory.find(book_id))
	var options: Dictionary = sim.get_spellbook_options(book_index) if book_index >= 0 else {}
	host._draw_label(host._fit_text(String(book.get("name", book_id)), details_width, 8), details_x, rect.position.y + 9.0, 8, host.COLORS.text)
	host._draw_label("%s  ·  %s" % [String(book.get("school", "Knowledge")), String(book.get("rarity", "Common"))], details_x, rect.position.y + 23.0, 7, host.COLORS.purple)
	host._draw_label(host._fit_text(String(book.get("description", "Recorded knowledge.")), details_width, 6), details_x, rect.position.y + 38.0, 6, host.COLORS.muted)
	var learning: Dictionary = book.get("learning", {})
	var resolved := bool(options.get("resolved", sim.run.get("spellbook_resolutions", {}).has(book_id)))
	var mode := String(learning.get("mode", "all"))
	var state := "LEARNED  ·  RECORDED" if resolved else "CHOOSE %d" % int(learning.get("choice_count", 0)) if mode == "choose" else "STUDY  ·  TEACHES ALL" if book_index >= 0 else "DISCOVERED  ·  NOT CARRIED"
	host._draw_label(state, details_x, rect.position.y + 52.0, 6, host.COLORS.green if resolved else host.COLORS.gold)
	var names: Array = learning.get("abilities", book.get("learns", []))
	var content_y := rect.position.y + 67.0
	var option_entries: Array = options.get("options", []) if book_index >= 0 else []
	if mode == "choose" and not option_entries.is_empty():
		for i in range(mini(3, option_entries.size())):
			var entry: Dictionary = option_entries[i]
			var choice_rect := Rect2(details_x, content_y + float(i) * 23.0, details_width, 21.0)
			var selected: bool = host.selected_book_abilities.has(i)
			host._draw_button(choice_rect, ("✓ " if selected else "◇ ") + host._fit_text(String(entry.get("name", "Ability")), details_width - 18.0, 6), {"type": "toggle_book_choice", "index": i}, selected, 6, host.COLORS.purple)
	else:
		for i in range(mini(3, names.size())):
			var ability_id := String(names[i])
			var ability: Dictionary = sim.content.abilities.get(ability_id, {})
			var name := String(ability.get("name", ability_id.replace("_", " ")))
			host._draw_label("✦  %s" % host._fit_text(name, details_width - 14.0, 6), details_x, content_y + float(i) * 14.0, 6, host.COLORS.cyan)
	if book_index >= 0 and not resolved:
		var ready := mode != "choose" or int(host.selected_book_abilities.size()) == int(learning.get("choice_count", 0))
		var study_y := rect.end.y - 39.0
		if ready:
			host._draw_button(Rect2(details_x, study_y, details_width, 35.0), "STUDY BOOK", {"type": "study_book"}, true, 7, host.COLORS.green)
		else:
			host._draw_label("Choose the offered knowledge before study.", details_x, rect.end.y - 5.0, 6, host.COLORS.muted)
	elif resolved:
		host._draw_label("Contents are recorded in the Codex.", details_x, rect.end.y - 5.0, 6, host.COLORS.muted)
