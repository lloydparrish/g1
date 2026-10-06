extends SceneTree

const SimScript = preload("res://scripts/game_sim.gd")
const MainScene = preload("res://scenes/main.tscn")

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_suite")

func run_suite() -> void:
	var content_check = SimScript.new()
	_check(content_check.validate_content().is_empty(), "player-facing content and spellbook definitions validate")
	_check(content_check.content.abilities.size() == 32 and content_check.content.abilities.values().all(func(ability: Dictionary) -> bool: return not String(ability.get("description", "")).strip_edges().is_empty()), "all 32 playable abilities have authored descriptions")

	var rewards = SimScript.new()
	rewards.start_run(401, "jim")
	rewards.run.stage_completed = true
	rewards.run.reward_choices = [
		{"type": "item", "id": "scale_armor", "claimed": false, "available": true},
		{"type": "artifact", "id": "copper_hare", "claimed": false, "available": true}
	]
	_check(rewards.claim_reward(0), "one reward choice can be claimed")
	_check(not rewards.claim_reward(1) and int(rewards.run.reward_chosen_index) == 0 and bool(rewards.run.reward_choice_resolved), "claiming one reward invalidates every alternate choice")
	var saved_reward_digest: String = rewards.state_digest()
	var reward_resume = SimScript.new()
	_check(reward_resume.resume_run() and reward_resume.state_digest() == saved_reward_digest, "the selected reward and closed alternatives survive deterministic resume")

	var books = SimScript.new()
	books.start_run(402, "jim")
	books.run.inventory.append("lesser_key_of_ash")
	var lesser_index: int = books.run.inventory.size() - 1
	_check(not books.study_spellbook(lesser_index, []) and books.run.inventory.has("lesser_key_of_ash") and not books.run.schools.has("Demonology"), "a choose-one book cannot be studied before a choice is made")
	_check(books.study_spellbook(lesser_index, [0]), "The Lesser Key accepts exactly one selected ability")
	_check(books.run.known.has("summon_imp") and not books.run.known.has("hellfire_pact") and not books.run.inventory.has("lesser_key_of_ash"), "studying consumes the Lesser Key and teaches only the chosen entry")
	_check(books.run.spellbook_resolutions.lesser_key_of_ash.abilities == ["summon_imp"] and books.codex.spellbooks.has("lesser_key_of_ash"), "the choice and complete spellbook record remain available after consumption")
	books.run.inventory.append("lesser_key_of_ash")
	_check(not books.study_spellbook(books.run.inventory.size() - 1, [1]), "restoring or reopening a consumed book cannot grant a second choice")

	var all_book = SimScript.new()
	all_book.start_run(403, "jim")
	all_book.run.inventory.append("cinder_primer")
	_check(all_book.study_spellbook(all_book.run.inventory.size() - 1, []), "all-mode spellbooks grant their full defined ability list")
	_check(all_book.run.known.has("firebolt") and not all_book.run.inventory.has("cinder_primer"), "all-mode study unlocks and consumes according to its definition")
	var school_book: Dictionary = {"name": "Spirit Primer", "type": "spellbook", "school": "Spirit", "contents": ["Spirit Sight"], "learning": {"mode": "school_only", "abilities": [], "unlocks_school": true, "consume_on_study": true}}
	all_book.content.items["spirit_primer_probe"] = school_book
	all_book.run.inventory.append("spirit_primer_probe")
	_check(all_book.study_spellbook(all_book.run.inventory.size() - 1, []) and all_book.run.schools.has("Spirit"), "school-only books can reveal a school without granting an ability")
	var choice_book: Dictionary = {"name": "Choice Primer", "type": "spellbook", "school": "Fire", "contents": ["Frostbolt", "Lightning Bolt", "Arcane Bolt"], "learning": {"mode": "choose", "choice_count": 2, "abilities": ["frostbolt", "lightning_bolt", "arcane_bolt"], "consume_on_study": true}}
	all_book.content.items["choice_primer_probe"] = choice_book
	all_book.run.inventory.append("choice_primer_probe")
	_check(all_book.study_spellbook(all_book.run.inventory.size() - 1, [0, 2]) and all_book.run.known.has("frostbolt") and all_book.run.known.has("arcane_bolt") and not all_book.run.known.has("lightning_bolt"), "choose-N books support arbitrary exact selection counts")

	for character_id in ["jim", "aldren", "mara", "sylvi", "orin", "brakka"]:
		var summon_sim = SimScript.new()
		summon_sim.start_run(410, character_id)
		for entity_id in summon_sim.run.entities.keys():
			if entity_id != "player": summon_sim.run.entities[entity_id].alive = false
		if not summon_sim.run.schools.has("Demonology"): summon_sim.run.schools.append("Demonology")
		if not summon_sim.run.known.has("summon_imp"): summon_sim.run.known.append("summon_imp")
		var player: Dictionary = summon_sim.get_player()
		player.resources.Mana = [10, maxi(10, int(player.resources.Mana[1]))]
		var command: Array = player.resources.Command
		command[1] = maxi(1, int(command[1]))
		command[0] = int(command[1]) - 1
		player.resources.Command = command
		var player_pos: Vector2i = summon_sim._pos(player)
		var result: Dictionary = summon_sim.act({"type": "cast", "id": "summon_imp", "target": [player_pos.x, player_pos.y]})
		var imps: Array = summon_sim.run.entities.values().filter(func(entity: Dictionary) -> bool: return String(entity.get("enemy_id", "")) == "imp" and bool(entity.get("alive", false)))
		_check(result.get("ok", false) and imps.size() == 1 and int(player.resources.Command[0]) == int(player.resources.Command[1]), "%s can summon an Imp with exact Mana and one free Command slot" % String(summon_sim.content.characters[character_id].name))

	var low_mana = SimScript.new()
	low_mana.start_run(411, "jim")
	low_mana.run.schools.append("Demonology")
	low_mana.run.known.append("summon_imp")
	low_mana.get_player().resources.Mana = [9, 30]
	low_mana.get_player().resources.Command = [0, 2]
	var low_pos: Vector2i = low_mana._pos(low_mana.get_player())
	var low_result: Dictionary = low_mana.act({"type": "cast", "id": "summon_imp", "target": [low_pos.x, low_pos.y]})
	_check(not low_result.get("ok", false) and String(low_result.message).contains("9 / 10"), "low Mana feedback names the exact resource shortfall")
	var full_command = SimScript.new()
	full_command.start_run(412, "jim")
	full_command.run.schools.append("Demonology")
	full_command.run.known.append("summon_imp")
	full_command.get_player().resources.Mana = [30, 30]
	full_command.get_player().resources.Command = [2, 2]
	var full_pos: Vector2i = full_command._pos(full_command.get_player())
	var full_result: Dictionary = full_command.act({"type": "cast", "id": "summon_imp", "target": [full_pos.x, full_pos.y]})
	_check(not full_result.get("ok", false) and String(full_result.message).contains("Command capacity full") and String(full_result.message).contains("2 / 2 occupied"), "full Command feedback explains occupied capacity instead of a spendable resource")

	var presenter = SimScript.new()
	presenter.start_run(413, "jim")
	var archer_id: String = presenter._spawn_enemy("goblin_archer", Vector2i(13, 7), false)
	var archer_presentation: Dictionary = presenter.get_entity_presentation(archer_id)
	var timeline_entry: Dictionary = presenter.get_timeline(100).filter(func(entry: Dictionary) -> bool: return entry.id == archer_id)[0]
	_check(archer_presentation.symbol == "r" and timeline_entry.symbol == archer_presentation.symbol, "Goblin Archer uses one canonical glyph in the battlefield and timeline")

	var mouse_reward = MainScene.instantiate()
	var touch_reward = MainScene.instantiate()
	root.add_child(mouse_reward)
	root.add_child(touch_reward)
	await process_frame
	await process_frame
	for main in [mouse_reward, touch_reward]:
		main.sim.start_run(420, "jim")
		main.page = "battle"
		main.sim.run.stage_completed = true
		main.sim.run.reward_choices = [{"type": "item", "id": "scale_armor", "claimed": false}, {"type": "item", "id": "bomb", "claimed": false}]
		main.overlay = "rewards"
		main.queue_redraw()
	await _ui_action(mouse_reward, "claim_reward", "index", 0, false)
	await _ui_action(touch_reward, "claim_reward", "index", 0, true)
	_check(mouse_reward.sim.state_digest() == touch_reward.sim.state_digest(), "mouse and touch choose the same deterministic reward command")
	_check(mouse_reward.sim.run.get("reward_chosen_index", -1) == 0 and not _has_action(mouse_reward, "claim_reward"), "reward UI disables all options immediately after the single choice")

	var main = MainScene.instantiate()
	main.playback_mode = "Instant"
	root.add_child(main)
	await process_frame
	await process_frame
	main.sim.start_run(421, "aldren")
	main.page = "battle"
	main.queue_redraw()
	await process_frame
	await process_frame
	var initial_time: int = main.sim.run.time
	await _ui_action(main, "target_mode", "mode", "move", false)
	_check(main.target_mode == "move", "mouse movement action enters the same explicit targeting mode")
	await _ui_action(main, "target_mode", "mode", "move", false)
	_check(main.target_mode == "" and int(main.sim.run.time) == initial_time, "tapping the same move action again cancels without advancing the simulation")
	await _ui_action(main, "ability", "id", "arcane_bolt", true)
	_check(main.target_mode == "arcane_bolt", "touch ability selection starts its target mode")
	await _ui_action(main, "ability", "id", "arcane_bolt", true)
	_check(main.target_mode == "" and int(main.sim.run.time) == initial_time, "tapping the same ability again cancels without a turn cost")
	await _ui_action(main, "ability", "id", "arcane_bolt", false)
	await _ui_action(main, "target_mode", "mode", "attack", true)
	_check(main.target_mode == "attack", "a different action switches directly from ability targeting to weapon targeting")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	main._handle_key(escape)
	_check(main.target_mode == "", "Escape cancels the active targeting context")
	main.target_mode = "arcane_bolt"
	main._handle_back_request()
	_check(main.target_mode == "", "Android Back request cancels targeting before opening any menu")

	main.sim.run.inventory.append("lesser_key_of_ash")
	main._handle_action({"type": "lower_panel", "id": "inventory"})
	main._handle_action({"type": "lower_inventory_tab", "id": "Spellbooks"})
	main.queue_redraw()
	await process_frame
	await process_frame
	await _ui_action(main, "select_lower_book", "id", "lesser_key_of_ash", true)
	_check(not _has_action(main, "study_book"), "choose-one spellbook keeps Study disabled until its required selection is made")
	await _ui_action(main, "toggle_book_choice", "index", 0, false)
	await _ui_action(main, "toggle_book_choice", "index", 2, true)
	_check(main.selected_book_abilities == [2], "mouse and touch selection can change the single chosen spellbook ability")
	_check(_has_action(main, "study_book"), "Study becomes available when the selected choice count is valid")
	await _ui_action(main, "study_book", "", "", true)
	_check(main.sim.run.known.has("demonic_gateway") and not main.sim.run.inventory.has("lesser_key_of_ash"), "inventory Study teaches the chosen entry and consumes the book")
	main._handle_action({"type": "close"})
	main._handle_action({"type": "overlay", "id": "codex"})
	main.queue_redraw()
	await process_frame
	await process_frame
	_check(_has_named_action(main, "codex_book", "id", "lesser_key_of_ash"), "Codex keeps an inspectable spellbook record after the item is consumed")
	await _ui_action(main, "codex_book", "id", "lesser_key_of_ash", true)
	_check(main.overlay == "codex_book" and main.sim.content.items[main.codex_book_id].contents.size() == 3, "Codex opens the full spellbook contents after the run choice")

	main._handle_action({"type": "close"})
	main._handle_action({"type": "lower_panel", "id": "character"})
	main._handle_action({"type": "lower_character_tab", "id": "Character"})
	main._handle_action({"type": "overlay", "id": "ability_web"})
	main.queue_redraw()
	await process_frame
	await process_frame
	var large_web_probe = SimScript.new()
	large_web_probe.start_run(422, "jim")
	for index in range(120):
		large_web_probe.content.abilities["radial_probe_%03d" % index] = {"name": "Radial Probe %d" % index, "school": "Swordsmanship", "kind": "passive", "target": "passive", "time": 0, "costs": {}, "effects": [], "modifiers": {}, "web_root": index == 0, "requires": ["radial_probe_%03d" % (index - 1)] if index > 0 else []}
	var radial_nodes: Array = large_web_probe.get_progression_graph()
	var radial_bounds: Rect2 = large_web_probe.get_progression_graph_bounds(radial_nodes)
	_check(radial_nodes.size() >= 120 and radial_bounds.size.y > main._ability_graph_rect().size.y, "120-node prerequisite branch extends beyond the radial web viewport without a logical cap")
	var pan_before: Vector2 = main.web_pan
	await _touch_drag(main, main._ability_graph_rect().get_center(), main._ability_graph_rect().get_center() + Vector2(65, 45))
	_check(main.web_pan != pan_before, "touch drag pans the production progression graph")
	main.queue_free()
	mouse_reward.queue_free()
	touch_reward.queue_free()

	print("PLAYTEST REGRESSIONS %d · FAILURES %d" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + failure)
	quit(1 if not failures.is_empty() else 0)

func _ui_action(main: Control, action_type: String, property_name: String, value: Variant, use_touch: bool) -> void:
	main.queue_redraw()
	await process_frame
	await process_frame
	if action_type == "ability":
		for slot_index in range(main.sim.run.get("quickbar", []).size()):
			if main.sim.run.quickbar[slot_index].get("type") == "ability" and main.sim.run.quickbar[slot_index].get("id") == str(value):
				await _ui_action(main, "quickbar_slot", "index", slot_index, use_touch)
				return
	for hit in main.active_hits:
		var action: Dictionary = hit.action
		if String(action.get("type", "")) != action_type:
			continue
		if property_name != "" and str(action.get(property_name, "")) != str(value):
			continue
		var rect: Rect2 = hit.rect
		if use_touch:
			await _touch(main, rect.get_center())
		else:
			await _mouse_tap(main, rect.get_center())
		return
	_check(false, "UI action is visible: %s %s" % [action_type, str(value)])

func _has_action(main: Control, action_type: String) -> bool:
	return main.active_hits.any(func(hit: Dictionary) -> bool: return String(hit.action.get("type", "")) == action_type)

func _has_named_action(main: Control, action_type: String, property_name: String, value: String) -> bool:
	return main.active_hits.any(func(hit: Dictionary) -> bool: return String(hit.action.get("type", "")) == action_type and str(hit.action.get(property_name, "")) == value)

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

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
