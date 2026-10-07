extends RefCounted

var host

const SLOT_NAMES := ["Head", "Body", "Hands", "Feet", "Weapon", "Offhand", "Ring 1", "Ring 2", "Amulet"]
const SECTION_NAMES := ["World Map", "Character / Abilities", "Inventory / Equipment"]
const SECTION_IDS := ["world_map", "character", "inventory"]
const SECTION_GLYPHS := ["⌖", "✦", "▦"]
const SECTION_COLORS := ["green", "cyan", "gold"]

func draw() -> void:
	if host._is_mobile_layout():
		_draw_mobile()
		return
	_draw_desktop()

func _draw_mobile() -> void:
	var layout: Dictionary = host._battle_layout()
	var screen_width: float = host.screen_size.x
	var column_gap := 6.0
	var column_width := (screen_width - 36.0 - column_gap * float(SECTION_IDS.size() - 1)) / float(SECTION_IDS.size())
	var dock_top: float = layout.dock_top
	var bottom: float = layout.dock_bottom
	var header_height: float = layout.dock_header_height
	var expanded: bool = host.ui_state.lower_dock_expanded
	var active_id := String(host.ui_state.active_lower_panel)
	if expanded:
		host._draw_panel(Rect2(18.0, dock_top, screen_width - 36.0, bottom - dock_top), "", _section_color(SECTION_IDS.find(active_id)))
	for index in range(SECTION_IDS.size()):
		var section_id: String = SECTION_IDS[index]
		var x := 18.0 + float(index) * (column_width + column_gap)
		var active := expanded and section_id == active_id
		var panel_height := bottom - dock_top if expanded else minf(72.0, bottom - dock_top)
		var panel_rect := Rect2(x, dock_top, column_width, panel_height)
		var accent: Color = _section_color(index)
		if not expanded:
			host._draw_panel(panel_rect, "", host.COLORS.line_soft)
		var header_rect := Rect2(x + 2.0, dock_top + 2.0, column_width - 4.0, header_height - 4.0)
		host._draw_panel(header_rect, "", accent if active else host.COLORS.line_soft)
		host.draw_rect(Rect2(header_rect.position.x, header_rect.position.y, 3.0, header_rect.size.y), accent)
		host._draw_label(SECTION_GLYPHS[index], x + 18.0, dock_top + header_height * 0.66, 15, accent)
		host._draw_label(host._fit_text(String(SECTION_NAMES[index]).to_upper(), column_width - 48.0, 9), x + 35.0, dock_top + header_height * 0.64, 9, host.COLORS.text)
		host.active_hits.append({"rect": host._touch_hit_rect(header_rect), "action": {"type": "lower_panel", "id": section_id}})
	if not expanded or active_id == "":
		return
	var active_index: int = SECTION_IDS.find(active_id)
	if active_index < 0:
		return
	var body := Rect2(26.0, dock_top + header_height + 16.0, screen_width - 52.0, bottom - dock_top - header_height - 24.0)
	host.active_hit_clip_rect = body
	match active_id:
		"world_map": _draw_world_map_desktop(body)
		"character": _draw_character(body)
		"inventory": _draw_inventory(body)
	host.active_hit_clip_rect = Rect2()

func _draw_desktop() -> void:
	var layout: Dictionary = host._battle_layout()
	var screen_width: float = host.screen_size.x
	var column_gap := 6.0
	var column_width := (screen_width - 36.0 - column_gap * float(SECTION_IDS.size() - 1)) / float(SECTION_IDS.size())
	var dock_top: float = layout.dock_top
	var panel_height: float = layout.dock_bottom - dock_top
	var header_height := float(layout.dock_header_height)
	for index in range(SECTION_IDS.size()):
		var section_id := String(SECTION_IDS[index])
		var x := 18.0 + float(index) * (column_width + column_gap)
		var rect := Rect2(x, dock_top, column_width, panel_height)
		var accent: Color = _section_color(index)
		host._draw_panel(rect, "", accent)
		host.draw_rect(Rect2(x + 8.0, dock_top + 7.0, 3.0, header_height - 11.0), accent)
		host._draw_label(SECTION_GLYPHS[index], x + 18.0, dock_top + 18.0, 13, accent)
		host._draw_label(host._fit_text(String(SECTION_NAMES[index]).to_upper(), column_width - 48.0, 9), x + 37.0, dock_top + 18.0, 9, host.COLORS.text)
		var header_rect := Rect2(x + 2.0, dock_top + 2.0, column_width - 4.0, header_height - 3.0)
		host.active_hits.append({"rect": header_rect, "action": {"type": "lower_panel", "id": section_id}})
		var body := Rect2(x + 8.0, dock_top + header_height + 4.0, column_width - 16.0, panel_height - header_height - 12.0)
		host.active_hit_clip_rect = body
		match section_id:
			"world_map": _draw_world_map_desktop(body)
			"character": _draw_character_desktop(body)
			"inventory": _draw_inventory_desktop(body)
		host.active_hit_clip_rect = Rect2()

func _draw_world_map_desktop(rect: Rect2) -> void:
	var journey := _persistent_journey()
	var history: Array = journey.history
	var entries: Array = journey.entries
	if entries.is_empty():
		return
	var current_name := String(entries[history.size() - 1].name)
	host._draw_label(host._fit_text("CURRENT  ·  %s  ·  %d / 6" % [current_name, int(host.sim.run.get("stage_index", 0)) + 1], rect.size.x - 8.0, 7), rect.position.x + 2.0, rect.position.y + 13.0, 7, host.COLORS.gold)
	var positions := _journey_positions(rect, entries.size())
	for index in range(1, entries.size()):
		var from_point: Vector2 = positions[index - 1]
		var to_point: Vector2 = positions[index]
		var direction := (to_point - from_point).normalized()
		var from_radius := 15.0 if index - 1 == history.size() - 1 else 12.0
		var to_radius := 12.0
		host.draw_line(from_point + direction * from_radius, to_point - direction * to_radius, host.COLORS.line, 2.0)
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		var point: Vector2 = positions[index]
		var is_unknown := bool(entry.get("unknown", false))
		var is_current := bool(entry.get("current", false))
		var color: Color = host.COLORS.muted if is_unknown else host.COLORS.gold if is_current else host.COLORS.cyan
		var radius := 15.0 if is_current else 12.0
		host.draw_circle(point, radius, Color(color.r, color.g, color.b, 0.16) if not is_unknown else Color(0.04, 0.08, 0.12, 0.95))
		host.draw_arc(point, radius, 0.0, TAU, 28, color, 2.5 if is_current else 1.5)
		if is_unknown:
			host._draw_label("?", point.x, point.y + 5.0, 12, color, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			host._draw_label(str(index + 1), point.x, point.y + 3.0, 6, color, HORIZONTAL_ALIGNMENT_CENTER)
		var name_lines: Array[String] = host._wrap_text_to_width(String(entry.name), maxf(48.0, rect.size.x / 3.0 - 16.0), 6, 2)
		var text_y: float
		if entries.size() <= 3:
			text_y = point.y + 27.0
		elif index < 3:
			text_y = point.y - 17.0 - float(name_lines.size() - 1) * 8.0
		else:
			text_y = point.y + 24.0
		for line_index in range(name_lines.size()):
			host._draw_label(name_lines[line_index], point.x, text_y + float(line_index) * 8.0, 6, color if is_current or is_unknown else host.COLORS.muted, HORIZONTAL_ALIGNMENT_CENTER)
	var journey_status := "NEXT LOCATION UNKNOWN" if bool(journey.has_unknown) else "JOURNEY COMPLETE" if String(host.sim.run.get("outcome", "")) == "victory" else "FINAL ENCOUNTER  ·  6 / 6"
	host._draw_label(journey_status, rect.position.x + 2.0, rect.end.y - 5.0, 6, host.COLORS.gold if not bool(journey.has_unknown) else host.COLORS.muted)

func _persistent_journey() -> Dictionary:
	var sim = host.sim
	var current_id := String(sim.run.get("stage_id", ""))
	var history: Array = sim.run.get("route", []).duplicate()
	if history.is_empty():
		history.append(current_id)
	elif String(history.back()) == "grave_tyrant" and current_id == "graveyard":
		# Older Prompt 6 saves stored the boss choice ID as if it were the map ID.
		history[history.size() - 1] = current_id
	elif String(history.back()) != current_id:
		history.append(current_id)
	var entries: Array = []
	for index in range(history.size()):
		var stage_id := String(history[index])
		if stage_id == "grave_tyrant":
			stage_id = "graveyard"
		var stage: Dictionary = sim.content.stages.get(stage_id, {})
		entries.append({"id": stage_id, "name": String(stage.get("name", stage_id.replace("_", " ").capitalize())), "current": index == history.size() - 1, "unknown": false})
	var has_unknown := int(sim.run.get("stage_index", 0)) < 5
	if has_unknown:
		entries.append({"id": "", "name": "UNKNOWN", "current": false, "unknown": true})
	return {"history": history, "entries": entries, "has_unknown": has_unknown}

func _journey_positions(rect: Rect2, count: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if count <= 0:
		return result
	if count <= 3:
		var spacing := rect.size.x / float(count + 1)
		var y := rect.position.y + rect.size.y * 0.54
		for index in range(count):
			result.append(Vector2(rect.position.x + spacing * float(index + 1), y))
		return result
	var top_y := rect.position.y + rect.size.y * 0.32
	var bottom_y := rect.position.y + rect.size.y * 0.69
	for index in range(count):
		var row := int(index / 3)
		var step := index % 3
		var column := step if row == 0 else 2 - step
		var x_fraction: float = [0.17, 0.5, 0.83][column]
		result.append(Vector2(rect.position.x + rect.size.x * x_fraction, top_y if row == 0 else bottom_y))
	return result

func _draw_character_desktop(rect: Rect2) -> void:
	var sim = host.sim
	var tabs := ["Character", "Abilities", "Passives", "Known"]
	var tab_width := rect.size.x / float(tabs.size())
	for i in range(tabs.size()):
		var tab := String(tabs[i])
		var tab_rect := Rect2(rect.position.x + float(i) * tab_width, rect.position.y, tab_width - 2.0, 20.0)
		host._draw_button(tab_rect, tab, {"type": "lower_character_tab", "id": tab}, host.ui_state.character_tab == tab, 6, host.COLORS.cyan)
	var content_top := rect.position.y + 25.0
	if host.ui_state.character_tab == "Character":
		var attrs: Dictionary = sim.run.get("attributes", {})
		host._draw_label("LEVEL %d  ·  %d XP  ·  %d AP" % [int(sim.run.get("level", 1)), int(sim.run.get("xp", 0)), int(sim.run.get("skill_points", 0))], rect.position.x + 2.0, content_top + 10.0, 8, host.COLORS.gold)
		var names := ["Might", "Dexterity", "Vitality", "Intelligence", "Willpower", "Perception"]
		for i in range(names.size()):
			var column := i % 2
			var row := int(i / 2)
			host._draw_label("%s  %d" % [String(names[i]).to_upper(), int(attrs.get(names[i], 10))], rect.position.x + float(column) * rect.size.x * 0.5, content_top + 36.0 + float(row) * 22.0, 8, host.COLORS.text)
		host._draw_label("WEAPON  ·  %s" % String(sim.content.items.get(sim.run.equipment.get("Weapon", ""), {}).get("name", "Unarmed")), rect.position.x + 2.0, content_top + 112.0, 7, host.COLORS.muted)
		host._draw_button(Rect2(rect.end.x - 92.0, rect.end.y - 31.0, 90.0, 27.0), "ABILITY WEB", {"type": "overlay", "id": "ability_web"}, false, 6, host.COLORS.cyan)
		return
	var visible_categories: Array = sim.get_visible_ability_categories()
	var categories: Dictionary = sim.content.get("ability_categories", {})
	var category_ids: Array = []
	for category in visible_categories:
		category_ids.append(String(category.id))
	if host.ui_state.character_tab == "Passives":
		category_ids = []
	if not category_ids.has(String(host.ui_state.selected_ability_category)):
		host.ui_state.selected_ability_category = String(category_ids[0]) if not category_ids.is_empty() else ""
	var categories_per_page := 10
	var category_pages := maxi(1, int(ceil(float(category_ids.size()) / float(categories_per_page))))
	host.ui_state.ability_category_page = clampi(int(host.ui_state.ability_category_page), 0, category_pages - 1)
	var category_start := int(host.ui_state.ability_category_page) * categories_per_page
	for local_index in range(mini(categories_per_page, category_ids.size() - category_start)):
		var category_id := String(category_ids[category_start + local_index])
		var column := local_index % 5
		var row := int(local_index / 5)
		var chip_width := (rect.size.x - 8.0) / 5.0
		var chip := Rect2(rect.position.x + 2.0 + float(column) * chip_width, content_top + float(row) * 19.0, chip_width - 2.0, 17.0)
		var category: Dictionary = categories[category_id]
		var active: bool = host.ui_state.selected_ability_category == category_id
		host._draw_button(chip, host._fit_text(String(category.get("name", category_id)), chip.size.x - 3.0, 6), {"type": "select_ability_category", "id": category_id}, active, 6, host.COLORS.cyan)
	if category_pages > 1:
		host._draw_button(Rect2(rect.position.x + 2.0, content_top + 39.0, 27.0, 18.0), "‹", {"type": "ability_category_page", "delta": -1}, true, 9)
		host._draw_label("%d / %d" % [int(host.ui_state.ability_category_page) + 1, category_pages], rect.position.x + 35.0, content_top + 52.0, 6, host.COLORS.muted)
		host._draw_button(Rect2(rect.end.x - 29.0, content_top + 39.0, 27.0, 18.0), "›", {"type": "ability_category_page", "delta": 1}, true, 9)
	var list_top := content_top + (62.0 if category_pages > 1 else 42.0)
	var entries: Array[String] = []
	if host.ui_state.character_tab == "Known":
		for node in sim.get_progression_graph():
			var ability: Dictionary = sim.content.abilities.get(String(node.id), {})
			if not String(host.ui_state.selected_ability_category).is_empty() and not ability.get("categories", []).has(host.ui_state.selected_ability_category): continue
			entries.append(String(node.id))
	else:
		for ability_id in sim.content.abilities:
			var ability: Dictionary = sim.content.abilities[ability_id]
			var is_passive: bool = ability.get("kind", "active") == "passive"
			if host.ui_state.character_tab == "Passives" and not is_passive: continue
			if host.ui_state.character_tab == "Abilities" and is_passive: continue
			if not String(host.ui_state.selected_ability_category).is_empty() and not ability.get("categories", []).has(host.ui_state.selected_ability_category): continue
			entries.append(String(ability_id))
	entries.sort_custom(func(a: String, b: String) -> bool: return String(sim.content.abilities[a].get("name", a)) < String(sim.content.abilities[b].get("name", b)))
	var page_size := 6
	var page_count := maxi(1, int(ceil(float(entries.size()) / float(page_size))))
	host.ui_state.ability_page = clampi(int(host.ui_state.ability_page), 0, page_count - 1)
	var card_width := (rect.size.x - 8.0) / 3.0
	for local_index in range(page_size):
		var index := int(host.ui_state.ability_page) * page_size + local_index
		if index >= entries.size(): continue
		var ability_id := entries[index]
		var ability: Dictionary = sim.content.abilities.get(ability_id, {})
		var progress: Dictionary = sim.get_ability_progress(ability_id)
		var known: bool = sim.run.get("known", []).has(ability_id)
		var unlocked := known or bool(progress.get("learnable", false))
		var color: Color = host._school_color(String(ability.get("school", "")))
		var column := local_index % 3
		var row := int(local_index / 3)
		var item_rect := Rect2(rect.position.x + 2.0 + float(column) * (card_width + 2.0), list_top + float(row) * 31.0, card_width, 28.0)
		host._draw_panel(item_rect, "", host.COLORS.gold if host.ui_state.selected_ability_id == ability_id else color if unlocked else host.COLORS.line_soft)
		var label_rect := _draw_ability_card_leading(host, item_rect, ability, color, 11, item_rect.position.y + 19.0)
		host._draw_label(host._fit_text(String(ability.get("name", ability_id)), label_rect.size.x, 7), label_rect.position.x, item_rect.position.y + 18.0, 7, host.COLORS.text if unlocked else host.COLORS.muted)
		host.active_hits.append({"rect": item_rect, "action": {"type": "select_lower_ability", "id": ability_id}})
	if page_count > 1:
		host._draw_button(Rect2(rect.position.x + 2.0, rect.end.y - 27.0, 27.0, 23.0), "‹", {"type": "lower_ability_page", "delta": -1}, true, 10)
		host._draw_label("%d / %d" % [int(host.ui_state.ability_page) + 1, page_count], rect.position.x + 34.0, rect.end.y - 11.0, 6, host.COLORS.muted)
		host._draw_button(Rect2(rect.position.x + 68.0, rect.end.y - 27.0, 27.0, 23.0), "›", {"type": "lower_ability_page", "delta": 1}, true, 10)
	var chosen_id := String(host.ui_state.selected_ability_id)
	var chosen: Dictionary = sim.content.abilities.get(chosen_id, {})
	if not chosen.is_empty():
		var footer_text := "%s  ·  %s  ·  %d" % [String(chosen.get("school", "Ability")), host._cost_text(chosen.get("costs", {})), int(chosen.get("time", 0))]
		host._draw_label(host._fit_text(footer_text, rect.size.x - 8.0, 6), rect.position.x + 2.0, rect.end.y - 34.0, 6, host.COLORS.muted)
		var learned: bool = sim.run.get("known", []).has(chosen_id)
		var passive: bool = chosen.get("kind", "active") == "passive"
		if learned and not passive:
			var assigned: bool = host._is_quickbar_assigned("ability", chosen_id)
			host._draw_button(Rect2(rect.end.x - 98.0, rect.end.y - 26.0, 96.0, 24.0), "REMOVE BAR" if assigned else "EQUIP SLOT", {"type": "remove_quickbar_assignment" if assigned else "begin_quickbar_assignment", "kind": "ability", "id": chosen_id}, assigned, 6, host.COLORS.gold)
		elif not learned and sim.get_ability_progress(chosen_id).get("learnable", false):
			host._draw_button(Rect2(rect.end.x - 98.0, rect.end.y - 26.0, 96.0, 24.0), "LEARN", {"type": "learn", "id": chosen_id}, true, 7, host.COLORS.green)

func _draw_inventory_desktop(rect: Rect2) -> void:
	var tabs := ["Inventory", "Equipment", "Artifacts", "Spellbooks"]
	var tab_width := rect.size.x / float(tabs.size())
	for i in range(tabs.size()):
		var tab := String(tabs[i])
		var tab_rect := Rect2(rect.position.x + float(i) * tab_width, rect.position.y, tab_width - 2.0, 20.0)
		host._draw_button(tab_rect, tab, {"type": "lower_inventory_tab", "id": tab}, host.ui_state.inventory_tab == tab, 6, host.COLORS.cyan)
	var body := Rect2(rect.position.x, rect.position.y + 24.0, rect.size.x, rect.size.y - 24.0)
	match host.ui_state.inventory_tab:
		"Inventory": _draw_pack(body)
		"Equipment": _draw_equipment_desktop(body)
		"Artifacts": _draw_artifacts(body)
		"Spellbooks": _draw_owned_books(body)

func _draw_equipment_desktop(rect: Rect2) -> void:
	var sim = host.sim
	var slot_width := 102.0
	var grid_x := rect.position.x + slot_width + 6.0
	var grid_width := rect.end.x - grid_x
	for i in range(SLOT_NAMES.size()):
		var slot := String(SLOT_NAMES[i])
		var item_id := String(sim.run.equipment.get(slot, ""))
		var item: Dictionary = sim.content.items.get(item_id, {})
		var occupied := item_id not in ["", "occupied"]
		var slot_rect := Rect2(rect.position.x, rect.position.y + float(i) * 19.0, slot_width, 17.0)
		var selected: bool = host.ui_state.selected_equipment_slot == slot
		host._draw_panel(slot_rect, "", host.COLORS.gold if selected else host.COLORS.cyan if occupied else host.COLORS.line_soft)
		host._draw_label(host._fit_text(slot, 44.0, 6), slot_rect.position.x + 4.0, slot_rect.position.y + 12.0, 6, host.COLORS.muted)
		host._draw_label(host._item_glyph(item_id, item) if occupied else "·", slot_rect.end.x - 7.0, slot_rect.position.y + 12.0, 9, host.COLORS.gold if occupied else host.COLORS.muted, HORIZONTAL_ALIGNMENT_RIGHT)
		host.active_hits.append({"rect": slot_rect, "action": {"type": "select_equipment_slot", "slot": slot}})
	var inventory: Array = sim.run.get("inventory", [])
	var selected_slot := String(host.ui_state.selected_equipment_slot)
	var candidates: Array[int] = []
	for index in range(inventory.size()):
		if sim.can_equip_item(index, selected_slot):
			candidates.append(index)
	var grid_top := rect.position.y + 24.0
	var cell_w := grid_width / 5.0
	host._draw_label(host._fit_text("%s GEAR  ·  %d" % [selected_slot.to_upper() if not selected_slot.is_empty() else "ALL", candidates.size()], grid_width - 64.0, 6), grid_x + 2.0, rect.position.y + 12.0, 6, host.COLORS.gold)
	host._draw_button(Rect2(rect.end.x - 55.0, rect.position.y + 1.0, 53.0, 20.0), "ALL", {"type": "select_equipment_slot", "slot": ""}, selected_slot == "", 6, host.COLORS.gold)
	for i in range(mini(30, candidates.size())):
		var inventory_index := candidates[i]
		var item_id := String(inventory[inventory_index])
		var item: Dictionary = sim.content.items.get(item_id, {})
		var row := int(i / 5)
		var column := i % 5
		var item_rect := Rect2(grid_x + float(column) * cell_w, grid_top + float(row) * 22.0, cell_w - 2.0, 20.0)
		var selected := int(host.ui_state.selected_inventory_index) == inventory_index
		host._draw_panel(item_rect, "", host.COLORS.gold if selected else host._item_color("equipment", String(item.get("rarity", "Common"))))
		host._draw_label(host._item_glyph(item_id, item), item_rect.get_center().x, item_rect.position.y + 15.0, 11, host._item_color("equipment", String(item.get("rarity", "Common"))), HORIZONTAL_ALIGNMENT_CENTER)
		host.active_hits.append({"rect": item_rect, "action": {"type": "select_item", "index": inventory_index}})
	if candidates.is_empty():
		host._draw_label("No compatible gear for this slot.", grid_x + 2.0, grid_top + 25.0, 7, host.COLORS.muted)
	var equipped_id := String(sim.run.equipment.get(selected_slot, ""))
	var equipped: Dictionary = sim.content.items.get(equipped_id, {})
	var action_y := rect.end.y - 27.0
	var selected_index := int(host.ui_state.selected_inventory_index)
	var selected_item: Dictionary = {}
	var selected_id := ""
	if selected_index >= 0 and selected_index < inventory.size():
		selected_id = String(inventory[selected_index])
		selected_item = sim.content.items.get(selected_id, {})
		if not sim.can_equip_item(selected_index, selected_slot):
			selected_index = -1
			selected_id = ""
			selected_item = {}
	var summary := "%s  ·  %s" % [selected_slot, String(equipped.get("name", "Empty"))] if not selected_slot.is_empty() else "%d compatible items" % candidates.size()
	if not selected_item.is_empty():
		summary = "%s  →  %s" % [String(selected_item.get("name", selected_id)), String(selected_item.get("slot", selected_item.get("type", "Item")))]
	var stats_id := selected_id if not selected_item.is_empty() else equipped_id
	var stats_line := _equipment_stats_text(sim, stats_id)
	var show_equip: bool = selected_index >= 0 and selected_item.get("type", "") == "equipment" and String(sim.run.equipment.get(String(selected_item.get("slot", "")), "")) != selected_id
	var show_unequip: bool = not selected_slot.is_empty() and equipped_id not in ["", "occupied"]
	var summary_x := grid_x + (76.0 if show_equip else 0.0)
	var summary_width := grid_width - (76.0 if show_equip else 0.0) - (72.0 if show_unequip else 0.0)
	host._draw_label(host._fit_text(summary, summary_width, 6), summary_x, rect.end.y - 8.0, 6, host.COLORS.muted)
	if stats_line != "":
		host._draw_label(host._fit_text(stats_line, grid_width - 4.0, 6), grid_x + 2.0, rect.end.y - 30.0, 6, host.COLORS.cyan)
	if show_unequip:
		host._draw_button(Rect2(rect.end.x - 70.0, action_y, 70.0, 22.0), "UNEQUIP", {"type": "unequip", "slot": selected_slot}, false, 6, host.COLORS.gold)
	if show_equip:
		host._draw_button(Rect2(grid_x, action_y, 68.0, 22.0), "EQUIP", {"type": "equip"}, false, 6, host.COLORS.green)

func _equipment_stats_text(sim, item_id: String) -> String:
	var stats: Dictionary = sim.get_equipment_item_stats(item_id)
	if stats.is_empty():
		return ""
	var parts: Array[String] = []
	if stats.has("damage"):
		parts.append("DMG %d %s" % [int(stats.damage), String(stats.damage_type)])
		parts.append("TIME %d" % int(stats.time))
		parts.append("RANGE %d" % int(stats.range))
		parts.append("STA %d" % int(stats.stamina))
	if int(stats.get("armor", 0)) > 0:
		parts.append("ARMOR %d" % int(stats.armor))
	for resistance in stats.get("resist", {}):
		parts.append("%s %d%% RESIST" % [String(resistance).to_upper(), int(stats.resist[resistance] * 100.0)])
	for modifier in stats.get("modifiers", {}):
		parts.append("%s %+d" % [String(modifier).replace("_", " ").to_upper(), int(stats.modifiers[modifier])])
	return "  ·  ".join(parts) if not parts.is_empty() else String(stats.get("description", "Equipment effect"))

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

func _draw_character(rect: Rect2) -> void:
	var sim = host.sim
	var tabs := ["Character", "Abilities", "Passives", "Known"]
	var tab_width := rect.size.x / float(tabs.size())
	for i in range(tabs.size()):
		var tab_rect := Rect2(rect.position.x + float(i) * tab_width, rect.position.y + 16.0, tab_width - 2.0, 25.0)
		var tab := String(tabs[i])
		host._draw_button(tab_rect, tab, {"type": "lower_character_tab", "id": tab}, host.ui_state.character_tab == tab, 7, host.COLORS.cyan)
	var y := rect.position.y + 46.0
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
		var card := Rect2(x + float(column) * (card_width + 6.0), y + float(row) * 58.0, card_width, 44.0)
		var active := String(host.ui_state.selected_ability_id) == ability_id
		host._draw_panel(card, "", host.COLORS.gold if active else color if learned or progress.get("learnable", false) else host.COLORS.line_soft)
		var label_rect := _draw_ability_card_leading(host, card, ability, color, 15, card.position.y + 23.0)
		host._draw_label(host._fit_text(String(ability.get("name", ability_id)), label_rect.size.x, 7), label_rect.position.x, card.position.y + 17.0, 7, host.COLORS.text)
		host._draw_label(host._fit_text(state, label_rect.size.x, 6), label_rect.position.x, card.position.y + 33.0, 6, host.COLORS.green if equipped or learned else host.COLORS.gold if progress.get("learnable", false) else host.COLORS.muted)
		var selection_rect := card
		if column == 1:
			selection_rect.size.x = minf(selection_rect.size.x, 60.0)
		host.active_hits.append({"rect": host._panel_hit_rect(selection_rect), "action": {"type": "select_lower_ability", "id": ability_id}})
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
			host._draw_button(Rect2(rect.end.x - 96.0, footer_y - 20.0, 94.0, 38.0), "REMOVE BAR" if assigned else "EQUIP SLOT", {"type": "remove_quickbar_assignment" if assigned else "begin_quickbar_assignment", "kind": "ability", "id": chosen_id}, assigned, 7, host.COLORS.gold)
		elif not chosen_learned and chosen_progress.get("learnable", false):
			host._draw_button(Rect2(rect.end.x - 96.0, footer_y - 20.0, 94.0, 38.0), "LEARN", {"type": "learn", "id": chosen_id}, true, 8, host.COLORS.green)
	if page_count > 1:
		host._draw_button(Rect2(x + 27.0, rect.end.y - 51.0, 54.0, 32.0), "‹", {"type": "lower_ability_page", "delta": -1}, true, 12)
		host._draw_label("%d / %d" % [int(host.ui_state.ability_page) + 1, page_count], x + 52.0, rect.end.y - 5.0, 7, host.COLORS.muted)
		host._draw_button(Rect2(x + 91.0, rect.end.y - 51.0, 54.0, 32.0), "›", {"type": "lower_ability_page", "delta": 1}, true, 12)
	# Ability Web remains available from the Character tab beside the three persistent sections.

func _draw_ability_card_leading(draw_host, card: Rect2, ability: Dictionary, color: Color, icon_font_size: int, icon_baseline: float) -> Rect2:
	var layout := _ability_card_icon_layout(draw_host, card, ability, icon_font_size)
	draw_host._draw_label(String(layout.glyph), float(layout.icon_x), icon_baseline, icon_font_size, color)
	return layout.text_rect

func _ability_card_icon_layout(draw_host, card: Rect2, ability: Dictionary, icon_font_size: int) -> Dictionary:
	var glyph: String = draw_host._ability_glyph(ability)
	var physical_size: int = draw_host._physical_font_size(icon_font_size)
	var measured_icon_width := ThemeDB.fallback_font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1.0, physical_size).x / maxf(0.1, draw_host.draw_scale)
	var icon_slot_width := maxf(float(icon_font_size) + 2.0, measured_icon_width + 1.0)
	var padding := 8.0
	var gap := maxf(5.0, ceil(float(icon_font_size) * 0.45))
	var text_x := card.position.x + padding + icon_slot_width + gap
	var text_right := card.end.x - padding
	return {
		"glyph": glyph,
		"icon_x": card.position.x + padding,
		"icon_right": card.position.x + padding + measured_icon_width,
		"gap": gap,
		"text_rect": Rect2(text_x, card.position.y, maxf(0.0, text_right - text_x), card.size.y)
	}

func _draw_inventory(rect: Rect2) -> void:
	var sim = host.sim
	var tabs := ["Inventory", "Equipment", "Artifacts", "Spellbooks"]
	var tab_width := rect.size.x / float(tabs.size())
	for i in range(tabs.size()):
		var tab := String(tabs[i])
		var tab_rect := Rect2(rect.position.x + float(i) * tab_width, rect.position.y + 16.0, tab_width - 2.0, 24.0)
		host._draw_button(tab_rect, tab, {"type": "lower_inventory_tab", "id": tab}, host.ui_state.inventory_tab == tab, 6, host.COLORS.cyan)
	var body := Rect2(rect.position.x, rect.position.y + 47.0, rect.size.x, rect.size.y - 47.0)
	match host.ui_state.inventory_tab:
		"Equipment": _draw_equipment_mobile(body)
		"Inventory": _draw_pack(body)
		"Artifacts": _draw_artifacts(body)
		"Spellbooks": _draw_owned_books(body)

func _draw_equipment_mobile(rect: Rect2) -> void:
	var sim = host.sim
	var slot_area_width := rect.size.x * 0.27
	var slot_gap := 5.0
	var slot_width := (slot_area_width - slot_gap * 2.0) / 3.0
	for i in range(SLOT_NAMES.size()):
		var slot := String(SLOT_NAMES[i])
		var item_id := String(sim.run.equipment.get(slot, ""))
		var item: Dictionary = sim.content.items.get(item_id, {})
		var occupied := item_id not in ["", "occupied"]
		var row := int(i / 3)
		var column := i % 3
		var slot_rect := Rect2(rect.position.x + float(column) * (slot_width + slot_gap), rect.position.y + 7.0 + float(row) * 54.0, slot_width, 40.0)
		var selected: bool = host.ui_state.selected_equipment_slot == slot
		host._draw_panel(slot_rect, "", host.COLORS.gold if selected else host.COLORS.cyan if occupied else host.COLORS.line_soft)
		host._draw_label(host._fit_text(slot, slot_width - 8.0, 7), slot_rect.position.x + 4.0, slot_rect.position.y + 11.0, 7, host.COLORS.muted)
		host._draw_label("⊕" if item_id == "occupied" else host._item_glyph(item_id, item) if occupied else "·", slot_rect.get_center().x, slot_rect.position.y + 31.0, 15, host.COLORS.gold if occupied else host.COLORS.muted, HORIZONTAL_ALIGNMENT_CENTER)
		host.active_hits.append({"rect": host._panel_hit_rect(slot_rect), "action": {"type": "select_equipment_slot", "slot": slot}})
	var detail_width := rect.size.x * 0.24
	var detail_x := rect.end.x - detail_width
	var grid_x := rect.position.x + slot_area_width + 12.0
	var grid_width := detail_x - grid_x - 10.0
	var columns := 8
	var cell_width := grid_width / float(columns)
	var grid_top := rect.position.y + 4.0
	var inventory: Array = sim.run.get("inventory", [])
	var selected_slot := String(host.ui_state.selected_equipment_slot)
	var candidates: Array[int] = []
	for index in range(inventory.size()):
		if sim.can_equip_item(index, selected_slot): candidates.append(index)
	host._draw_label("GEAR  ·  %d MATCHES" % candidates.size(), grid_x, rect.position.y + 10.0, 8, host.COLORS.gold)
	host._draw_button(Rect2(grid_x + grid_width - 61.0, rect.position.y - 1.0, 60.0, 22.0), "ALL GEAR", {"type": "select_equipment_slot", "slot": ""}, selected_slot == "", 6, host.COLORS.gold)
	for i in range(candidates.size()):
		var inventory_index := candidates[i]
		var item_id := String(inventory[inventory_index])
		var item: Dictionary = sim.content.items.get(item_id, {})
		var row := int(i / columns)
		var column := i % columns
		var item_rect := Rect2(grid_x + float(column) * cell_width + 1.0, grid_top + 18.0 + float(row) * 32.0, cell_width - 3.0, 28.0)
		var selected := int(host.ui_state.selected_inventory_index) == inventory_index
		host._draw_panel(item_rect, "", host.COLORS.gold if selected else host._item_color(String(item.get("type", "item")), String(item.get("rarity", "Common"))))
		host._draw_label(host._item_glyph(item_id, item), item_rect.get_center().x, item_rect.position.y + 20.0, 16, host._item_color(String(item.get("type", "item")), String(item.get("rarity", "Common"))), HORIZONTAL_ALIGNMENT_CENTER)
		var quantity: int = inventory.count(item_id)
		if quantity > 1: host._draw_label("×%d" % quantity, item_rect.end.x - 3.0, item_rect.position.y + 9.0, 7, host.COLORS.text, HORIZONTAL_ALIGNMENT_RIGHT)
		host.active_hits.append({"rect": item_rect, "action": {"type": "select_item", "index": inventory_index}})
	if candidates.is_empty():
		host._draw_label("No compatible gear.", grid_x, grid_top + 32.0, 8, host.COLORS.muted)
	var equipped_id := String(sim.run.equipment.get(selected_slot, ""))
	var selected_index := int(host.ui_state.selected_inventory_index)
	var selected_id := String(inventory[selected_index]) if selected_index >= 0 and selected_index < inventory.size() else ""
	var selected_item: Dictionary = sim.content.items.get(selected_id, {})
	host._draw_label("SELECTED GEAR", detail_x, rect.position.y + 12.0, 8, host.COLORS.gold)
	if not selected_item.is_empty():
		host._draw_label(host._fit_text(String(selected_item.get("name", selected_id)), detail_width - 6.0, 8), detail_x, rect.position.y + 31.0, 8, host.COLORS.text)
		host._draw_label("Slot  ·  %s" % String(selected_item.get("slot", selected_item.get("type", "Item"))), detail_x, rect.position.y + 48.0, 7, host.COLORS.muted)
		var stat_text := _equipment_stats_text(sim, selected_id)
		var stats_y := rect.position.y + 65.0
		for line in host._wrap(stat_text, maxi(12, int(detail_width / 5.0))).slice(0, 4):
			host._draw_label(host._fit_text(String(line), detail_width - 5.0, 7), detail_x, stats_y, 7, host.COLORS.cyan)
			stats_y += 14.0
	else:
		var equipped: Dictionary = sim.content.items.get(equipped_id, {})
		host._draw_label(host._fit_text("%s  ·  %s" % [selected_slot if selected_slot != "" else "No slot selected", String(equipped.get("name", "Empty"))], detail_width - 6.0, 7), detail_x, rect.position.y + 31.0, 7, host.COLORS.text)
		var equipped_stats := _equipment_stats_text(sim, equipped_id)
		var equipped_stats_y := rect.position.y + 48.0
		for line in host._wrap(equipped_stats, maxi(12, int(detail_width / 5.0))).slice(0, 4):
			host._draw_label(host._fit_text(String(line), detail_width - 5.0, 7), detail_x, equipped_stats_y, 7, host.COLORS.cyan)
			equipped_stats_y += 14.0
	var action_rect := Rect2(detail_x, rect.end.y - 48.0, detail_width, 35.0)
	if selected_item.get("type", "") == "equipment":
		var item_slot := String(selected_item.get("slot", ""))
		var compatible: bool = sim.can_equip_item(selected_index, selected_slot)
		if String(sim.run.equipment.get(item_slot, "")) == selected_id:
			host._draw_label("ALREADY EQUIPPED", detail_x, action_rect.position.y + 16.0, 7, host.COLORS.green)
		elif compatible:
			host._draw_button(action_rect, "EQUIP", {"type": "equip"}, false, 9, host.COLORS.green)
	elif not selected_slot.is_empty() and equipped_id not in ["", "occupied"]:
		host._draw_button(action_rect, "UNEQUIP  ·  %s" % selected_slot.to_upper(), {"type": "unequip", "slot": selected_slot}, false, 8, host.COLORS.gold)

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
		var selected: bool = host.ui_state.selected_equipment_slot == slot
		host._draw_panel(slot_rect, "", host.COLORS.gold if selected else host.COLORS.line_soft if not occupied else host.COLORS.cyan)
		host._draw_label(slot.to_upper(), slot_rect.position.x + 5.0, slot_rect.position.y + 11.0, 6, host.COLORS.gold)
		host._draw_label("⊕" if item_id == "occupied" else host._item_glyph(item_id, item) if occupied else "·", slot_rect.get_center().x, slot_rect.position.y + 31.0, 15, host.COLORS.cyan if item_id == "occupied" else host.COLORS.gold if occupied else host.COLORS.muted, HORIZONTAL_ALIGNMENT_CENTER)
		host._draw_label(host._fit_text("Two-hand" if item_id == "occupied" else String(item.get("name", "Empty")), width - 8.0, 6), slot_rect.get_center().x, slot_rect.position.y + 41.0, 6, host.COLORS.text if occupied else host.COLORS.muted, HORIZONTAL_ALIGNMENT_CENTER)
		host.active_hits.append({"rect": host._panel_hit_rect(slot_rect), "action": {"type": "select_equipment_slot", "slot": slot}})
	var selected_slot := String(host.ui_state.selected_equipment_slot)
	var selected_id := String(sim.run.equipment.get(selected_slot, ""))
	if selected_slot != "":
		var selected_item: Dictionary = sim.content.items.get(selected_id, {})
		host._draw_label(host._fit_text("%s  ·  %s" % [selected_slot, String(selected_item.get("name", "Empty"))], rect.size.x - 103.0, 6), rect.position.x + 2.0, rect.end.y - 4.0, 6, host.COLORS.muted)
		if selected_id not in ["", "occupied"]:
			host._draw_button(Rect2(rect.end.x - 98.0, rect.end.y - 34.0, 96.0, 30.0), "UNEQUIP", {"type": "unequip", "slot": selected_slot}, false, 7, host.COLORS.gold)

func _draw_pack(rect: Rect2) -> void:
	var sim = host.sim
	var grid_width := rect.size.x * 0.72
	var cell_width := grid_width / 6.0
	var grid_top := rect.position.y + 17.0
	host._draw_label("PACK  ·  %d / 30" % sim.run.inventory.size(), rect.position.x + 1.0, rect.position.y + 9.0, 7, host.COLORS.gold)
	for i in range(30):
		var row := int(i / 6)
		var column := i % 6
		var item_rect := Rect2(rect.position.x + float(column) * cell_width, grid_top + float(row) * 29.0, cell_width - 2.0, 28.0)
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
	var page_size := 18
	var pages := maxi(1, int(ceil(float(values.size()) / float(page_size))))
	host.ui_state.inventory_page = clampi(int(host.ui_state.inventory_page), 0, pages - 1)
	if values.is_empty():
		host._draw_label("No artifacts carried. Artifacts have no slot limit.", rect.position.x + 4.0, rect.position.y + 28.0, 7, host.COLORS.muted)
		return
	var start := int(host.ui_state.inventory_page) * page_size
	var columns := 6
	var cell_width := rect.size.x / float(columns)
	var grid_top := rect.position.y + 2.0
	for i in range(start, mini(start + page_size, values.size())):
		var artifact_id := String(values[i])
		var artifact: Dictionary = sim.content.artifacts.get(artifact_id, {})
		var local_index := i - start
		var column := local_index % columns
		var row_index := int(local_index / columns)
		var tile := Rect2(rect.position.x + float(column) * cell_width + 1.0, grid_top + float(row_index) * 35.0, cell_width - 3.0, 32.0)
		var selected := int(host.ui_state.selected_artifact_index) == i
		host._draw_panel(tile, "", host.COLORS.gold if selected else host.COLORS.purple)
		host._draw_label("◈", tile.get_center().x, tile.position.y + 22.0, 17, host.COLORS.purple, HORIZONTAL_ALIGNMENT_CENTER)
		host.active_hits.append({"rect": host._panel_hit_rect(tile), "action": {"type": "select_artifact", "index": i}})
	if int(host.ui_state.selected_artifact_index) < start or int(host.ui_state.selected_artifact_index) >= mini(start + page_size, values.size()):
		host.ui_state.selected_artifact_index = start
	var selected_id := String(values[int(host.ui_state.selected_artifact_index)])
	var selected_artifact: Dictionary = sim.content.artifacts.get(selected_id, {})
	var detail_y := grid_top + float(ceil(float(mini(page_size, values.size() - start)) / float(columns))) * 35.0 + 4.0
	host._draw_label(host._fit_text(String(selected_artifact.get("name", selected_id)), rect.size.x, 8), rect.position.x + 2.0, detail_y + 10.0, 8, host.COLORS.text)
	host._draw_label(host._fit_text(String(selected_artifact.get("description", "Persistent run modifier")), rect.size.x, 7), rect.position.x + 2.0, detail_y + 27.0, 7, host.COLORS.muted)
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
		var row := Rect2(rect.position.x + 4.0, rect.position.y + float(i) * 43.0, 42.0, 40.0)
		host._draw_button(row, "✦", {"type": "select_lower_book", "id": book_id}, host.ui_state.selected_spellbook_id == book_id, 13, host.COLORS.purple)
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
		var row := Rect2(rect.position.x + 4.0, rect.position.y + float(i) * 43.0, 42.0, 40.0)
		host._draw_button(row, "✦", {"type": "select_lower_book", "id": book_id}, host.ui_state.selected_spellbook_id == book_id, 13, host.COLORS.purple)
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
	var names: Array = learning.get("abilities", book.get("learns", [])) if mode != "school_only" else []
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
