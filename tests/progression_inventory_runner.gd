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
	_check(sim.content.abilities.size() == 32, "representative active and passive content remains within the milestone target")
	_check(sim.content.progression.disciplines.size() == 10 and sim.content.progression.schools.size() == 13, "all canonical discipline and school registries are present")

	sim.start_run(301, "jim")
	sim.run.skill_points = 12
	_check(not sim.run.schools.has("Fire") and not sim.get_progression_graph().any(func(node: Dictionary) -> bool: return node.id == "firebolt"), "undiscovered magic stays out of Jim's natural ability web")
	sim.run.schools.append("Fire")
	_check(not sim.learn_ability("fireball"), "a simple prerequisite blocks Fireball before Firebolt")
	_check(sim.learn_ability("firebolt") and sim.learn_ability("fireball"), "natural fire progression reveals and learns connected successors")
	_check(sim.learn_ability("greater_fireball") and sim.learn_ability("meteor"), "school-rank gates support progression beyond the first ability")
	_check(sim.get_progression_graph().any(func(node: Dictionary) -> bool: return node.id == "flame_wave" and not node.learned), "branching progression exposes siblings without a single-chain restriction")

	var hybrid = SimScript.new()
	hybrid.start_run(302, "aldren")
	hybrid.run.skill_points = 2
	_check(not hybrid.get_ability_progress("flaming_blade").visible, "hybrid fire knowledge stays hidden until the school is discovered")
	hybrid.run.schools.append("Fire")
	_check(hybrid.get_ability_progress("flaming_blade").learnable and hybrid.learn_ability("flaming_blade"), "Aldren can learn a true Swordsmanship plus Fire hybrid")

	var jim = SimScript.new()
	jim.start_run(310, "jim")
	jim.run.skill_points = 3
	jim.run.inventory.append("greatsword")
	_check(jim.equip_item(jim.run.inventory.find("greatsword")) and jim.run.disciplines.has("Heavy Weapons") and jim.get_ability_progress("cleave").learnable, "Jim can open a nonmagical Heavy Weapons path by training with its weapon")
	_check(jim.run.schools.is_empty() and jim.run.known.all(func(ability_id: String) -> bool: return not String(jim.content.abilities[ability_id].school).is_empty()), "Jim retains his school-free starting identity while building martial skills")

	var mara = SimScript.new()
	mara.start_run(311, "mara")
	mara.run.skill_points = 2
	_check(mara.learn_ability("dagger_flurry") and mara.get_ability_progress("knife_dancer").learnable, "Mara's dagger path naturally reveals a mobility passive alongside Blood magic")
	_check(mara.learn_ability("knife_dancer") and not mara.get_available_abilities().has("knife_dancer"), "passive techniques apply as passives instead of occupying active action slots")

	var orin = SimScript.new()
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
	condition.content.abilities["web_condition_probe"] = {"name": "Web Condition Probe", "school": "Swordsmanship", "time": 50, "range": 1, "target": "enemy", "costs": {}, "effects": [{"type": "damage", "amount": 2, "damage": "Slashing"}], "prerequisites": {"all_of": ["lunge"], "any_of": ["parry", "guard"], "discipline_ranks": {"Swordsmanship": 2}, "characters": ["jim"]}}
	_check(condition.get_ability_progress("web_condition_probe").learnable, "graph prerequisites support AND, OR, discipline rank and character conditions")
	condition.run.artifacts.append("copper_hare")
	condition.content.abilities["resource_probe"] = {"name": "Resource Probe", "school": "Swordsmanship", "time": 50, "range": 1, "target": "enemy", "costs": {}, "effects": [{"type": "damage", "amount": 2, "damage": "Slashing"}], "prerequisites": {"artifacts": ["copper_hare"], "resources": {"Stamina": 10}}}
	_check(condition.get_ability_progress("resource_probe").learnable, "graph prerequisites support artifact and current-resource conditions")

	var brakka = SimScript.new()
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
	root.add_child(main)
	await process_frame
	await process_frame
	main.sim.start_run(309, "jim")
	main.page = "battle"
	main._handle_action({"type": "overlay", "id": "inventory"})
	main.queue_redraw()
	await process_frame
	await process_frame
	var inventory_hits := 0
	for hit in main.active_hits:
		if hit.action.get("type", "") == "select_item": inventory_hits += 1
	_check(inventory_hits == main.sim.run.inventory.size(), "compact inventory grid renders every carried item as an individual touch slot")
	await _mouse_action(main, "select_item", 0)
	_check(main.selected_inventory_index == 0, "mouse selects a compact inventory slot")
	await _touch_action(main, "select_item", 1)
	_check(main.selected_inventory_index == 1, "touch selects another inventory slot through the same UI command")
	var ui_item: Dictionary = main.sim.content.items[main.sim.run.inventory[1]]
	_check(not String(ui_item.get("description", "")).is_empty(), "selected inventory item exposes player-facing inspection details")
	main.sim.get_player().hp = int(main.sim.get_player().max_hp) - 12
	await _touch_action(main, "select_item", 0)
	var hp_before_use: int = main.sim.get_player().hp
	await _touch_action(main, "use_item", -1)
	_check(main.sim.get_player().hp > hp_before_use and not main.sim.run.inventory.has("healing_potion"), "touch item inspection can use and consume a Healing Draught")
	while main.sim.run.inventory.size() < 30:
		main.sim.run.inventory.append("bomb")
	main.overlay = "abilities"
	main.sim.run.schools.append("Fire")
	main.sim.run.skill_points = 1
	main.selected_web_ability = "firebolt"
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
	main._handle_action({"type": "overlay", "id": "inventory"})
	main.queue_redraw()
	await process_frame
	for hit in main.active_hits:
		if hit.action.get("type", "") == "select_item":
			var hit_rect: Rect2 = hit.rect
			_check(hit_rect.size.x >= 54.0 and hit_rect.size.y >= 54.0, "inventory touch slot meets the minimum tap target")
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
	main.sim.run.stage_completed = false
	main.sim.run.reward_choices = []
	main.sim.run.route_choices = ["graveyard", "flooded_ruins"]
	main.overlay = "map"
	main.queue_redraw()
	await process_frame
	var route_hit_size := Vector2.ZERO
	for hit in main.active_hits:
		if hit.action.get("type", "") == "route": route_hit_size = hit.rect.size
	_check(route_hit_size.x >= 54.0 and route_hit_size.y >= 54.0, "route selection presents a full-size touch action")
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

func _touch_action(main: Control, action_type: String, action_value: int) -> void:
	for hit in main.active_hits:
		if String(hit.action.get("type", "")) == action_type and int(hit.action.get("index", -1)) == action_value:
			var rect: Rect2 = hit.rect
			await _touch(main, rect.get_center())
			return
	_check(false, "touch action exists: %s %d" % [action_type, action_value])

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
