extends RefCounted

var host

const SLOT_NAMES := ["Head", "Body", "Hands", "Feet", "Weapon", "Offhand", "Ring 1", "Ring 2", "Amulet"]
const SECTION_NAMES := ["World Map", "Character / Abilities", "Inventory / Equipment", "Spellbook / Discovery"]
const SECTION_IDS := ["world_map", "character", "inventory", "spellbook"]
const SECTION_GLYPHS := ["⌖", "✦", "▦", "▤"]
const SECTION_COLORS := ["green", "cyan", "gold", "purple"]

func draw() -> void:
	if host._is_mobile_layout():
		_draw_mobile()
		return
	_draw_desktop()

func _draw_mobile() -> void:
	var layout: Dictionary = host._battle_layout()
	var screen_width: float = host.screen_size.x
	var column_gap := 6.0
	var column_width := (screen_width - 36.0 - column_gap * 3.0) / 4.0
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
		"spellbook": _draw_spellbook(body)
	host.active_hit_clip_rect = Rect2()

func _draw_desktop() -> void:
	var layout: Dictionary = host._battle_layout()
	var screen_width: float = host.screen_size.x
	var column_gap := 6.0
	var column_width := (screen_width - 36.0 - column_gap * 3.0) / 4.0
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
			"spellbook": _draw_spellbook(body)
		host.active_hit_clip_rect = Rect2()

func _draw_world_map_desktop(rect: Rect2) -> void:
	var sim = host.sim
	var history: Array = sim.run.get("route", [])
	var current_id := String(sim.run.get("stage_id", ""))
	var history_count := history.size()
	var mobile: bool = host._is_mobile_layout()
	var left := rect.position.x + 38.0
	var right := rect.end.x - 10.0
	var route_y := rect.position.y + (18.0 if mobile else 32.0)
	var step := minf(56.0, (right - left) / maxf(1.0, float(history_count - 1)))
	for i in range(history_count):
		var stage_id := String(history[i])
		var point := Vector2(left + float(i) * step, route_y)
		if i > 0:
			var previous := Vector2(left + float(i - 1) * step, route_y)
			host.draw_line(previous + Vector2(5.0, 0.0), point - Vector2(5.0, 0.0), host.COLORS.line, 1.5)
		var is_current := stage_id == current_id and i == history_count - 1
		var color: Color = host.COLORS.gold if is_current else host.COLORS.cyan
		host.draw_circle(point, 5.0 if is_current else 3.5, color)
		host.draw_arc(point, 8.0, 0.0, TAU, 18, color, 1.1)
		var stage_name := String(sim.content.stages.get(stage_id, {}).get("name", stage_id))
		host._draw_label(host._fit_text(stage_name, 58.0, 6), point.x, route_y + (20.0 if mobile else 22.0), 6, host.COLORS.text if is_current else host.COLORS.muted, HORIZONTAL_ALIGNMENT_CENTER)
	var current: Dictionary = sim.content.stages.get(current_id, {})
	host._draw_label(host._fit_text(String(current.get("subtitle", "Current encounter")), rect.size.x - 8.0, 7), rect.position.x + 2.0, rect.position.y + (49.0 if mobile else 62.0), 7, host.COLORS.muted)
	var choice_y := rect.position.y + (56.0 if mobile else 82.0)
	var choices: Array = sim.run.get("route_choices", [])
	var boss_ready := int(sim.run.get("stage_index", 0)) >= ArcanistSim.STAGE_ORDER.size() - 1 and bool(sim.run.get("stage_completed", false))
	var selectable: Array[String] = []
	if boss_ready:
		selectable.append("grave_tyrant")
	else:
		for choice in choices:
			selectable.append(String(choice))
	if selectable.is_empty():
		var hint := "Complete this encounter to reveal connected routes." if not sim.run.get("stage_completed", false) else "No connected route is currently available."
		host._draw_label(host._fit_text(hint, rect.size.x - 8.0, 7), rect.position.x + 2.0, choice_y + 12.0, 7, host.COLORS.muted)
		return
	var selected_id := String(host.ui_state.selected_map_node_id)
	if not selectable.has(selected_id):
		selected_id = selectable[0]
		host.ui_state.selected_map_node_id = selected_id
	var node_gap := 6.0
	var node_width := (rect.size.x - 4.0 - node_gap * float(selectable.size() - 1)) / float(selectable.size())
	for i in range(selectable.size()):
		var stage_id := selectable[i]
		var stage: Dictionary = sim.content.enemies.get(stage_id, {}) if stage_id == "grave_tyrant" else sim.content.stages.get(stage_id, {})
		var node_rect := Rect2(rect.position.x + 2.0 + float(i) * (node_width + node_gap), choice_y, node_width, 44.0)
		var active := selected_id == stage_id
		host._draw_panel(node_rect, "", host.COLORS.gold if active else host.COLORS.line_soft)
		var title := String(stage.get("name", "Grave Tyrant" if stage_id == "grave_tyrant" else stage_id))
		var glyph := "T" if stage_id == "grave_tyrant" else "◇"
		host._draw_label(glyph, node_rect.position.x + 8.0, node_rect.position.y + 17.0, 12, host.COLORS.red if stage_id == "grave_tyrant" else host.COLORS.green)
		host._draw_label(host._fit_text(title, node_width - 27.0, 7), node_rect.position.x + 25.0, node_rect.position.y + 16.0, 7, host.COLORS.text)
		host._draw_label("BOSS" if stage_id == "grave_tyrant" else "COMBAT", node_rect.position.x + 25.0, node_rect.position.y + 33.0, 6, host.COLORS.muted)
		host.active_hits.append({"rect": host._panel_hit_rect(node_rect), "action": {"type": "select_map_node", "id": stage_id}})
	var detail_y := choice_y + (52.0 if mobile else 58.0)
	var selected_stage: Dictionary = sim.content.enemies.get(selected_id, {}) if selected_id == "grave_tyrant" else sim.content.stages.get(selected_id, {})
	var description := String(selected_stage.get("subtitle", selected_stage.get("description", "A connected destination")))
	host._draw_label(host._fit_text(description, rect.size.x - 94.0, 7), rect.position.x + 2.0, detail_y + 10.0, 7, host.COLORS.muted)
	if bool(sim.run.get("stage_completed", false)):
		var travel_action := {"type": "boss"} if selected_id == "grave_tyrant" else {"type": "route", "id": selected_id}
		var travel_rect := Rect2(rect.end.x - 82.0, detail_y if mobile else detail_y - 3.0, 82.0, 54.0 if mobile else 32.0)
		host._draw_button(travel_rect, "TRAVEL", travel_action, true, 7, host.COLORS.green)
	else:
		host._draw_label(host._fit_text("LOCKED  ·  COMPLETE ENCOUNTER TO TRAVEL", rect.size.x - 8.0, 6), rect.position.x + 2.0, detail_y + 17.0, 6, host.COLORS.gold)

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
	var categories: Dictionary = sim.content.get("ability_categories", {})
	var category_ids: Array = categories.keys()
	category_ids.sort_custom(func(a: String, b: String) -> bool: return int(categories[a].get("order", 99)) < int(categories[b].get("order", 99)))
	if host.ui_state.character_tab == "Passives":
		category_ids = []
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
		host._draw_label(host._ability_glyph(ability), item_rect.position.x + 9.0, item_rect.position.y + 19.0, 11, color)
		host._draw_label(host._fit_text(String(ability.get("name", ability_id)), item_rect.size.x - 21.0, 7), item_rect.position.x + 19.0, item_rect.position.y + 18.0, 7, host.COLORS.text if unlocked else host.COLORS.muted)
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
	var grid_top := rect.position.y + 1.0
	var cell_w := grid_width / 5.0
	for i in range(mini(30, inventory.size())):
		var item_id := String(inventory[i])
		var item: Dictionary = sim.content.items.get(item_id, {})
		var row := int(i / 5)
		var column := i % 5
		var item_rect := Rect2(grid_x + float(column) * cell_w, grid_top + float(row) * 22.0, cell_w - 2.0, 20.0)
		var selected := int(host.ui_state.selected_inventory_index) == i
		host._draw_panel(item_rect, "", host.COLORS.gold if selected else host._item_color("equipment", String(item.get("rarity", "Common"))))
		host._draw_label(host._item_glyph(item_id, item), item_rect.get_center().x, item_rect.position.y + 15.0, 11, host._item_color("equipment", String(item.get("rarity", "Common"))), HORIZONTAL_ALIGNMENT_CENTER)
		host.active_hits.append({"rect": item_rect, "action": {"type": "select_item", "index": i}})
	var selected_slot := String(host.ui_state.selected_equipment_slot)
	var equipped_id := String(sim.run.equipment.get(selected_slot, ""))
	var equipped: Dictionary = sim.content.items.get(equipped_id, {})
	var action_y := rect.end.y - 24.0
	var selected_index := int(host.ui_state.selected_inventory_index)
	var selected_item: Dictionary = {}
	var selected_id := ""
	if selected_index >= 0 and selected_index < inventory.size():
		selected_id = String(inventory[selected_index])
		selected_item = sim.content.items.get(selected_id, {})
	var summary := "%s  ·  %s" % [selected_slot, String(equipped.get("name", "Empty"))] if not selected_slot.is_empty() else "Select a slot or item."
	if not selected_item.is_empty():
		summary = "%s  →  %s" % [String(selected_item.get("name", selected_id)), String(selected_item.get("slot", selected_item.get("type", "Item")))]
	var summary_x := grid_x + (74.0 if selected_item.get("type", "") == "equipment" else 0.0)
	var summary_width := grid_width - (74.0 if selected_item.get("type", "") == "equipment" else 0.0) - (72.0 if not selected_slot.is_empty() and equipped_id not in ["", "occupied"] else 0.0)
	host._draw_label(host._fit_text(summary, summary_width, 6), summary_x, action_y + 14.0, 6, host.COLORS.muted)
	if not selected_slot.is_empty() and equipped_id not in ["", "occupied"]:
		host._draw_button(Rect2(rect.end.x - 70.0, action_y, 70.0, 22.0), "UNEQUIP", {"type": "unequip", "slot": selected_slot}, false, 6, host.COLORS.gold)
	if selected_index >= 0 and selected_index < inventory.size():
		if selected_item.get("type", "") == "equipment":
			var slot_name := String(selected_item.get("slot", ""))
			var slot_now := String(sim.run.equipment.get(slot_name, ""))
			var compatible := selected_slot.is_empty() or selected_slot == slot_name or (slot_name == "Offhand" and selected_slot == "Weapon" and int(sim.content.weapons.get(selected_item.get("weapon", ""), {}).get("hands", 1)) == 2)
			if slot_now == selected_id:
				host._draw_label("EQUIPPED", grid_x, action_y + 14.0, 6, host.COLORS.green)
			elif compatible:
				host._draw_button(Rect2(grid_x, action_y, 68.0, 22.0), "EQUIP", {"type": "equip"}, false, 6, host.COLORS.green)

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
		host._draw_label(host._ability_glyph(ability), card.position.x + 14.0, card.position.y + 23.0, 15, color)
		host._draw_label(host._fit_text(String(ability.get("name", ability_id)), card.size.x - 28.0, 7), card.position.x + 27.0, card.position.y + 17.0, 7, host.COLORS.text)
		host._draw_label(state, card.position.x + 27.0, card.position.y + 33.0, 6, host.COLORS.green if equipped or learned else host.COLORS.gold if progress.get("learnable", false) else host.COLORS.muted)
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
	# Ability Web remains available from the Character tab, away from the four management tabs.

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
	host._draw_label("CARRIED ITEMS  ·  %d / 30" % inventory.size(), grid_x, rect.position.y + 10.0, 8, host.COLORS.gold)
	for i in range(inventory.size()):
		var item_id := String(inventory[i])
		var item: Dictionary = sim.content.items.get(item_id, {})
		var row := int(i / columns)
		var column := i % columns
		var item_rect := Rect2(grid_x + float(column) * cell_width + 1.0, grid_top + 18.0 + float(row) * 32.0, cell_width - 3.0, 28.0)
		var selected := int(host.ui_state.selected_inventory_index) == i
		host._draw_panel(item_rect, "", host.COLORS.gold if selected else host._item_color(String(item.get("type", "item")), String(item.get("rarity", "Common"))))
		host._draw_label(host._item_glyph(item_id, item), item_rect.get_center().x, item_rect.position.y + 20.0, 16, host._item_color(String(item.get("type", "item")), String(item.get("rarity", "Common"))), HORIZONTAL_ALIGNMENT_CENTER)
		var quantity: int = inventory.count(item_id)
		if quantity > 1: host._draw_label("×%d" % quantity, item_rect.end.x - 3.0, item_rect.position.y + 9.0, 7, host.COLORS.text, HORIZONTAL_ALIGNMENT_RIGHT)
		host.active_hits.append({"rect": item_rect, "action": {"type": "select_item", "index": i}})
	var selected_slot := String(host.ui_state.selected_equipment_slot)
	var equipped_id := String(sim.run.equipment.get(selected_slot, ""))
	var selected_index := int(host.ui_state.selected_inventory_index)
	var selected_id := String(inventory[selected_index]) if selected_index >= 0 and selected_index < inventory.size() else ""
	var selected_item: Dictionary = sim.content.items.get(selected_id, {})
	host._draw_label("SELECTED GEAR", detail_x, rect.position.y + 12.0, 8, host.COLORS.gold)
	if not selected_item.is_empty():
		host._draw_label(host._fit_text(String(selected_item.get("name", selected_id)), detail_width - 6.0, 8), detail_x, rect.position.y + 31.0, 8, host.COLORS.text)
		host._draw_label("Slot  ·  %s" % String(selected_item.get("slot", selected_item.get("type", "Item"))), detail_x, rect.position.y + 48.0, 7, host.COLORS.muted)
	else:
		var equipped: Dictionary = sim.content.items.get(equipped_id, {})
		host._draw_label(host._fit_text("%s  ·  %s" % [selected_slot if selected_slot != "" else "No slot selected", String(equipped.get("name", "Empty"))], detail_width - 6.0, 7), detail_x, rect.position.y + 31.0, 7, host.COLORS.text)
	var action_rect := Rect2(detail_x, rect.end.y - 48.0, detail_width, 35.0)
	if selected_item.get("type", "") == "equipment":
		var item_slot := String(selected_item.get("slot", ""))
		var compatible := selected_slot == "" or selected_slot == item_slot or (item_slot == "Offhand" and selected_slot == "Weapon" and int(sim.content.weapons.get(selected_item.get("weapon", ""), {}).get("hands", 1)) == 2)
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
