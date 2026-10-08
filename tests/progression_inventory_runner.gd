extends SceneTree

const SimScript = preload("res://scripts/game_sim.gd")
const MainScene = preload("res://scenes/main.tscn")

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_suite")

func run_suite() -> void:
	var sim = SimScript.new()
	_check(sim.validate_content().is_empty(), "expanded content validates against the shared simulation schema")
	_check(sim.content.abilities.size() == 34, "foundation adds only the two basic starter abilities to existing content")
	_check(sim.content.progression.disciplines.size() == 10 and sim.content.progression.schools.size() == 12 and not sim.content.progression.schools.has("Arcane"), "Arcane remains school-less while the specialized spell schools stay registered")

	sim.start_run(301, "jim")
	var category_probe = SimScript.new()
	category_probe.start_run(300, "jim")
	var starting_categories: Array[String] = []
	for category in category_probe.get_visible_ability_categories(): starting_categories.append(String(category.id))
	_check(starting_categories.has("swordsmanship") and not starting_categories.has("defense") and not starting_categories.has("mobility") and not starting_categories.has("pyromancy") and not starting_categories.has("frost"), "the Mundane sees its basic sword path while the rest of the build stays empty")
	category_probe.run.schools.append("Fire")
	var earned_categories: Array[String] = []
	for category in category_probe.get_visible_ability_categories(): earned_categories.append(String(category.id))
	_check(earned_categories.has("pyromancy") and not earned_categories.has("frost") and category_probe.content.ability_categories.has("frost"), "a newly discovered school reveals its category while global category data remains intact")
	sim.run.skill_points = 12
	_check(not sim.run.schools.has("Fire") and not sim.get_progression_graph().any(func(node: Dictionary) -> bool: return node.id == "firebolt"), "undiscovered magic stays out of Jim's natural ability web")
	sim.run.schools.append("Fire")
	_check(not sim.learn_ability("fireball"), "a simple prerequisite blocks Fireball before Firebolt")
	_check(sim.learn_ability("firebolt") and sim.learn_ability("fireball"), "natural fire progression reveals and learns connected successors")
	_check(sim.learn_ability("greater_fireball") and sim.learn_ability("meteor"), "school-rank gates support progression beyond the first ability")
	_check(sim.get_progression_graph().any(func(node: Dictionary) -> bool: return node.id == "flame_wave" and not node.learned), "branching progression exposes siblings without a single-chain restriction")

	var hybrid = SimScript.new()
	_allow_character(hybrid, "aldren")
	hybrid.start_run(302, "aldren")
	hybrid.run.skill_points = 2
	_check(not hybrid.get_ability_progress("flaming_blade").visible, "hybrid fire knowledge stays hidden until the school is discovered")
	hybrid.run.schools.append("Fire")
	_check(hybrid.get_ability_progress("flaming_blade").learnable and hybrid.learn_ability("flaming_blade"), "Aldren can learn a true Swordsmanship plus Fire hybrid")

	var jim = SimScript.new()
	jim.start_run(310, "jim")
	jim.run.skill_points = 3
	jim.run.inventory.append("greatsword")
	jim.run.known.append("lunge")
	_check(jim.equip_item(jim.run.inventory.find("greatsword")) and jim.run.disciplines.has("Heavy Weapons") and jim.get_ability_progress("cleave").learnable, "Jim can open a nonmagical Heavy Weapons path by training with its weapon")
	_check(jim.run.schools.is_empty() and jim.run.known.all(func(ability_id: String) -> bool: return not String(jim.content.abilities[ability_id].school).is_empty()), "Jim retains his school-free starting identity while building martial skills")

	var mara = SimScript.new()
	_allow_character(mara, "mara")
	mara.start_run(311, "mara")
	mara.run.skill_points = 2
	_check(mara.learn_ability("dagger_flurry") and mara.get_ability_progress("knife_dancer").learnable, "Mara's dagger path naturally reveals a mobility passive alongside Blood magic")
	_check(mara.learn_ability("knife_dancer") and not mara.get_available_abilities().has("knife_dancer"), "passive techniques apply as passives instead of occupying active action slots")

	var orin = SimScript.new()
	_allow_character(orin, "orin")
	orin.start_run(312, "orin")
	_check(int(orin.get_player().resources.Command[1]) == 4 and orin.run.schools.has("Necromancy"), "Orin's build identity preserves extra Command and Necromancy access")

	var hidden = SimScript.new()
	hidden.start_run(303, "jim")
	var hidden_graph: Array = hidden.get_progression_graph()
	_check(not hidden_graph.any(func(node: Dictionary) -> bool: return String(node.school) == "Demonology"), "Demonology is absent before a discovery source is found")
	hidden.run.inventory.append("lesser_key_of_ash")
	var book_index: int = hidden.run.inventory.find("lesser_key_of_ash")
	_check(hidden.study_spellbook(book_index, [0]), "spellbook choice is resolved through its shared simulation command")
	var revealed_graph: Array = hidden.get_progression_graph()
	_check(hidden.run.schools.has("Demonology") and revealed_graph.any(func(node: Dictionary) -> bool: return node.id == "hellfire_pact"), "book discovery unlocks its school and reveals inspectable contents")
	_check(hidden.run.discoveries.has("spellbook:lesser_key_of_ash"), "specific spellbook provenance persists as a discovery flag")

	var condition = SimScript.new()
	condition.start_run(304, "jim")
	condition.run.skill_points = 2
	condition.run.known.append_array(["lunge", "guard"])
	condition.content.abilities["web_condition_probe"] = {"name": "Web Condition Probe", "school": "Swordsmanship", "time": 50, "range": 1, "target": "enemy", "costs": {}, "effects": [{"type": "damage", "amount": 2, "damage": "Slashing"}], "prerequisites": {"all_of": ["lunge"], "any_of": ["parry", "guard"], "discipline_ranks": {"Swordsmanship": 2}, "characters": ["jim"]}}
	_check(condition.get_ability_progress("web_condition_probe").learnable, "graph prerequisites support AND, OR, discipline rank and character conditions")
	condition.run.artifacts.append("copper_hare")
	condition.content.abilities["resource_probe"] = {"name": "Resource Probe", "school": "Swordsmanship", "time": 50, "range": 1, "target": "enemy", "costs": {}, "effects": [{"type": "damage", "amount": 2, "damage": "Slashing"}], "prerequisites": {"artifacts": ["copper_hare"], "resources": {"Stamina": 10}}}
	_check(condition.get_ability_progress("resource_probe").learnable, "graph prerequisites support artifact and current-resource conditions")

	var brakka = SimScript.new()
	_allow_character(brakka, "brakka")
	brakka.start_run(305, "brakka")
	_check(brakka.get_player().armor == 4 and brakka.get_passive_modifier("damage_reduction") > 0.0, "Brakka's passive modifies the equipped heavy armor and damage rules")
	var hp_before: int = brakka.get_player().hp
	brakka._damage("player", 20, "Slashing", "test strike")
	_check(int(brakka.get_player().hp) > hp_before - 16, "learned passives have a measurable deterministic combat effect")

	var graph_probe = SimScript.new()
	graph_probe.start_run(306, "jim")
	for index in range(80):
		graph_probe.content.abilities["viewport_probe_%03d" % index] = {"name": "Viewport Probe %d" % index, "school": "Swordsmanship", "kind": "passive", "target": "passive", "time": 0, "costs": {}, "effects": [], "modifiers": {}, "web_position": [float(index % 4) * 260.0, float(index / 4) * 126.0]}
	var large_graph: Array = graph_probe.get_progression_graph()
	var graph_bounds: Rect2 = graph_probe.get_progression_graph_bounds(large_graph)
	_check(large_graph.size() >= 80 and graph_bounds.end.x > 782.0 and graph_bounds.end.y > 414.0, "80-node progression web expands beyond its viewport without a logical node cap")

	var save_source = SimScript.new()
	_allow_character(save_source, "aldren")
	save_source.start_run(307, "aldren")
	save_source.run.schools.append("Fire")
	save_source.run.discoveries.append("spellbook:cinder_primer")
	save_source.run.skill_points = 1
	_check(save_source.learn_ability("flaming_blade"), "hybrid learning records progression before save")
	var saved_graph: Array = save_source.get_progression_graph()
	var saved_digest: String = save_source.state_digest()
	var save_loaded = SimScript.new()
	_check(save_loaded.resume_run() and save_loaded.state_digest() == saved_digest, "save and resume preserve discoveries, disciplines and learned hybrids deterministically")
	_check(JSON.stringify(save_loaded.get_progression_graph()) == JSON.stringify(saved_graph), "resumed progression web matches the original learned state")

	var inventory = SimScript.new()
	inventory.start_run(308, "jim")
	var armor_before: int = inventory.get_player().armor
	inventory.run.inventory.append("scale_armor")
	var scale_index: int = inventory.run.inventory.find("scale_armor")
	_check(inventory.equip_item(scale_index) and inventory.run.equipment.Body == "scale_armor" and int(inventory.get_player().armor) > armor_before, "equipment replacement moves the selected armor onto its documented slot")
	inventory.run.inventory.append("greatsword")
	var greatsword_index: int = inventory.run.inventory.find("greatsword")
	_check(inventory.equip_item(greatsword_index) and inventory.run.equipment.Offhand == "occupied", "two-handed weapons reserve the Offhand equipment slot")
	_check(inventory.unequip_item("Weapon") and inventory.run.equipment.Offhand == "" and inventory.run.inventory.has("greatsword"), "unequipping a two-handed weapon releases both hand slots")
	while inventory.run.inventory.size() < 30:
		inventory.run.inventory.append("bomb")
	inventory.run.stage_completed = true
	inventory.run.reward_choices = [{"type": "item", "id": "bomb", "claimed": false}]
	_check(not inventory.claim_reward(0) and inventory.run.inventory.size() == 30, "ordinary pack capacity remains exactly 30 items")
	_check(not inventory.unequip_item("Body"), "full pack cannot silently overfill when unequipping gear")

	var main = MainScene.instantiate()
	main.playback_mode = "Instant"
	main.mobile_layout_override = true
	root.add_child(main)
	await process_frame
	await process_frame
	main.sim.start_run(309, "jim")
	main.page = "battle"
	main._open_lower_panel("inventory", false)
	main._handle_action({"type": "lower_inventory_tab", "id": "Inventory"})
	main.queue_redraw()
	await process_frame
	await process_frame
	var inventory_hits := 0
	for hit in main.active_hits:
		if hit.action.get("type", "") == "select_item": inventory_hits += 1
	_check(inventory_hits == main.sim.run.inventory.size(), "compact inventory grid renders every carried item as an individual touch slot")
	await _mouse_action(main, "select_item", 0)
	_check(main.ui_state.selected_inventory_index == 0, "mouse selects a compact inventory slot")
	await _touch_action(main, "select_item", 1)
	_check(main.ui_state.selected_inventory_index == 1, "touch selects another inventory slot through the same UI command")
	var ui_item: Dictionary = main.sim.content.items[main.sim.run.inventory[1]]
	_check(not String(ui_item.get("description", "")).is_empty(), "selected inventory item exposes player-facing inspection details")
	main.sim.get_player().hp = int(main.sim.get_player().max_hp) - 12
	await _touch_action(main, "select_item", 0)
	var hp_before_use: int = main.sim.get_player().hp
	var healing_id: String = String(main.sim.run.inventory[0])
	var initially_assigned: bool = main._is_quickbar_assigned("item", healing_id)
	var initial_item_action: String = "remove_quickbar_assignment" if initially_assigned else "begin_quickbar_assignment"
	_check(main.active_hits.any(func(hit: Dictionary) -> bool: return hit.action.get("type", "") == initial_item_action and hit.action.get("kind", "") == "item" and hit.action.get("id", "") == healing_id), "selected item exposes the action-bar control that matches its assignment state")
	if initially_assigned:
		await _touch_action(main, "remove_quickbar_assignment", healing_id)
		main.queue_redraw()
		await process_frame
		await process_frame
	_check(main.active_hits.any(func(hit: Dictionary) -> bool: return hit.action.get("type", "") == "begin_quickbar_assignment" and hit.action.get("kind", "") == "item" and hit.action.get("id", "") == healing_id), "removing a starting item assignment restores its add action")
	await _touch_action(main, "begin_quickbar_assignment", healing_id)
	await _touch_action(main, "quickbar_slot", 7)
	_check(main.sim.run.quickbar[7] == {"type": "item", "id": healing_id}, "inventory assigns a selected quick-use item to the action bar")
	var remove_assignment_visible := false
	for hit in main.active_hits:
		if hit.action.get("type", "") == "remove_quickbar_assignment" and hit.action.get("kind", "") == "item" and hit.action.get("id", "") == healing_id:
			remove_assignment_visible = true
	_check(remove_assignment_visible, "assigned inventory item exposes a remove action instead of add")
	await _touch_action(main, "remove_quickbar_assignment", healing_id)
	main.queue_redraw()
	await process_frame
	await process_frame
	var add_assignment_visible := false
	for hit in main.active_hits:
		if hit.action.get("type", "") == "begin_quickbar_assignment" and hit.action.get("kind", "") == "item" and hit.action.get("id", "") == healing_id:
			add_assignment_visible = true
	_check(add_assignment_visible, "removing an inventory item assignment restores its add action")
	await _touch_action(main, "begin_quickbar_assignment", healing_id)
	await _touch_action(main, "quickbar_slot", 7)
	await _touch_action(main, "quickbar_slot", 7)
	_check(main.sim.get_player().hp > hp_before_use and not main.sim.run.inventory.has("healing_potion"), "touch item inspection can use and consume a Healing Draught")
	while main.sim.run.inventory.size() < 30:
		main.sim.run.inventory.append("bomb")
	main.overlay = "abilities"
	main.sim.run.schools.append("Fire")
	main.sim.run.skill_points = 1
	main.ui_state.selected_ability_id = "firebolt"
	main.queue_redraw()
	await process_frame
	await process_frame
	var large_hit_targets := true
	var center_rect := Rect2()
	var close_rect := Rect2()
	for hit in main.active_hits:
		if hit.action.get("type", "") == "select_web_node":
			var hit_rect: Rect2 = hit.rect
			if hit_rect.size.x < 54.0:
				large_hit_targets = false
		elif hit.action.get("type", "") == "web_center":
			center_rect = hit.rect
		elif hit.action.get("type", "") == "close":
			close_rect = hit.rect
	_check(large_hit_targets and main.active_hits.any(func(hit: Dictionary) -> bool: return hit.action.get("type", "") == "learn"), "progression nodes and learn actions remain accessible touch targets")
	_check(not center_rect.intersects(close_rect), "web navigation controls remain separated from the close button")
	var original_pan: Vector2 = main.web_pan
	await _touch_drag(main, Vector2(400, 400), Vector2(465, 440))
	_check(main.web_pan != original_pan, "touch drag pans the ability web")
	var mouse_pan: Vector2 = main.web_pan
	await _mouse_drag(main, Vector2(400, 400), Vector2(450, 435))
	_check(main.web_pan != mouse_pan, "desktop mouse drag pans the same ability web")
	main._open_lower_panel("inventory", false)
	main._handle_action({"type": "lower_inventory_tab", "id": "Inventory"})
	main.queue_redraw()
	await process_frame
	for hit in main.active_hits:
		if hit.action.get("type", "") == "select_item":
			var hit_rect: Rect2 = hit.rect
			_check(hit_rect.size.x >= 28.0 and hit_rect.size.y >= 28.0, "inventory grid slots remain individually tappable")
			break
	main.sim.run.stage_completed = true
	main.sim.run.reward_choices = [{"type": "item", "id": "healing_potion", "claimed": false}]
	main.overlay = "rewards"
	main.queue_redraw()
	await process_frame
	var reward_hit_size := Vector2.ZERO
	for hit in main.active_hits:
		if hit.action.get("type", "") == "claim_reward": reward_hit_size = hit.rect.size
	_check(reward_hit_size.x >= 54.0 and reward_hit_size.y >= 54.0, "reward choice presents a full-size touch action")
	main.sim.run.stage_completed = true
	main.sim.run.reward_choices = []
	main.overlay = ""
	var actual_route_choices: Array = main.sim.run.route_choices.duplicate()
	main.sim.run.stage_index = 0
	main._open_lower_panel("world_map")
	main.queue_redraw()
	await process_frame
	await process_frame
	var persistent_journey: Dictionary = main.lower_dock._persistent_journey()
	var exposed_future_route: bool = main.active_hits.any(func(hit: Dictionary) -> bool: return actual_route_choices.has(String(hit.action.get("id", ""))))
	_check(not actual_route_choices.is_empty() and persistent_journey.history == main.sim.run.map_history and bool(persistent_journey.has_unknown) and not exposed_future_route and not main.active_hits.any(func(hit: Dictionary) -> bool: return hit.action.get("type", "") in ["route", "boss", "destination_route", "select_map_node"]), "the World Map shows visited journey history and an unknown next node without exposing generated branch choices")
	var next_stage_hit_size := Vector2.ZERO
	for hit in main.active_hits:
		if hit.action.get("type", "") == "next_stage": next_stage_hit_size = hit.rect.size
	main._handle_action({"type": "next_stage"})
	main.queue_redraw()
	await process_frame
	await process_frame
	_check(String(main.sim.run.map_depth) == "1" and int(main.sim.run.stage_index) == 1 and main.overlay == "" and next_stage_hit_size.x >= 54.0 and next_stage_hit_size.y >= 54.0, "the touch-safe stage action advances within the current map without opening a destination picker")
	main.queue_free()

	print("PROGRESSION + INVENTORY %d · FAILURES %d" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + failure)
	quit(1 if not failures.is_empty() else 0)

func _mouse_action(main: Control, action_type: String, action_value: int) -> void:
	for hit in main.active_hits:
		if String(hit.action.get("type", "")) == action_type and int(hit.action.get("index", -1)) == action_value:
			var rect: Rect2 = hit.rect
			await _mouse_tap(main, rect.get_center())
			return
	_check(false, "mouse action exists: %s %d" % [action_type, action_value])

func _touch_action(main: Control, action_type: String, action_value: Variant) -> void:
	for hit in main.active_hits:
		var value: Variant = hit.action.get("id", hit.action.get("index", -1))
		if String(hit.action.get("type", "")) == action_type and str(value) == str(action_value):
			var rect: Rect2 = hit.rect
			await _touch(main, rect.get_center())
			return
	_check(false, "touch action exists: %s %s" % [action_type, str(action_value)])

func _mouse_tap(main: Control, point: Vector2) -> void:
	var viewport_point: Vector2 = main.draw_offset + point * main.draw_scale
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = viewport_point
	press.pressed = true
	main._gui_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = viewport_point
	release.pressed = false
	main._gui_input(release)
	await process_frame

func _touch(main: Control, point: Vector2) -> void:
	var viewport_point: Vector2 = main.draw_offset + point * main.draw_scale
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.position = viewport_point
	press.pressed = true
	main._input(press)
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.position = viewport_point
	release.pressed = false
	main._input(release)
	await process_frame

func _touch_drag(main: Control, start: Vector2, finish: Vector2) -> void:
	var start_view: Vector2 = main.draw_offset + start * main.draw_scale
	var end_view: Vector2 = main.draw_offset + finish * main.draw_scale
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.position = start_view
	press.pressed = true
	main._input(press)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = end_view
	drag.relative = end_view - start_view
	main._input(drag)
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.position = end_view
	release.pressed = false
	main._input(release)
	await process_frame

func _mouse_drag(main: Control, start: Vector2, finish: Vector2) -> void:
	var start_view: Vector2 = main.draw_offset + start * main.draw_scale
	var end_view: Vector2 = main.draw_offset + finish * main.draw_scale
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = start_view
	press.pressed = true
	main._gui_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = end_view
	main._gui_input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = end_view
	release.pressed = false
	main._gui_input(release)
	await process_frame

func _check(condition: bool, title: String) -> void:
	checks += 1
	if not condition:
		failures.append(title)

func _allow_character(sim, character_id: String) -> void:
	var unlocked: Array = sim.profile.get("unlocked_character_ids", [])
	if not unlocked.has(character_id): unlocked.append(character_id)
	sim.profile["unlocked_character_ids"] = unlocked
