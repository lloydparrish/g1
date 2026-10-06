extends SceneTree

const SimScript = preload("res://scripts/game_sim.gd")
const MainScript = preload("res://scripts/main.gd")

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_suite")

func run_suite() -> void:
	var first = SimScript.new()
	var second = SimScript.new()
	first.start_run(551230, "jim")
	second.start_run(551230, "jim")
	var move_command := {"type": "move", "target": [13, 8]}
	var first_result: Dictionary = first.act(move_command)
	var second_result: Dictionary = second.act(move_command)
	_check(first_result.ok and first_result.get("presentation_events", []).size() > 0, "committed player actions emit a structured presentation transcript")
	_check(first_result.get("presentation_events", []) == second_result.get("presentation_events", []), "same seed and command produce the same combat presentation transcript")
	_check(first.state_digest() == second.state_digest(), "presentation recording preserves deterministic authoritative outcomes")
	_check(first.run.get("combat_history", []).size() <= 100, "persisted combat feed has a bounded recent-event history")

	var hidden_sim = SimScript.new()
	hidden_sim.start_run(551231, "jim")
	var unseen_id: String = hidden_sim._spawn_enemy("skeleton", Vector2i(0, 0), false)
	hidden_sim._recording_presentation = true
	hidden_sim._action_presentation_events.clear()
	hidden_sim._emit_combat_event("Damage", unseen_id, "player", {"amount": 43, "damage_type": "Fire", "secret": "hidden attacker"})
	var unseen_events: Array = hidden_sim._action_presentation_events.duplicate(true)
	var unseen_event: Dictionary = unseen_events[0] if not unseen_events.is_empty() else {}
	_check(unseen_events.size() == 1 and unseen_event.get("type", "") == "UnseenImpact", "an unseen attack on the player uses generic feedback")
	_check(not unseen_event.get("details", {}).has("amount") and not unseen_event.get("details", {}).has("damage_type") and unseen_event.get("actor_name", "") == "", "fog-safe feedback reveals no hidden attacker identity or hit details")
	hidden_sim._recording_presentation = false

	var credit = SimScript.new()
	credit.start_run(551232, "jim")
	var full_id: String = credit._spawn_enemy("skeleton", Vector2i(13, 8), false)
	credit._on_death(full_id, "Jim", "player")
	_check(int(credit.run.kills) == 1 and int(credit.run.xp) == int(credit.content.enemies.skeleton.xp), "a player kill receives full XP and kill credit")
	var owned_id: String = credit._spawn_enemy("goblin", Vector2i(13, 8), false)
	credit.run.entities["owned_test"] = {"id": "owned_test", "owner": "player", "kind": "summon", "alive": true, "pos": [12, 7], "name": "Owned summon"}
	var prior_kills := int(credit.run.kills)
	var prior_xp := int(credit.run.xp)
	credit._on_death(owned_id, "Owned summon", "owned_test")
	_check(int(credit.run.kills) == prior_kills + 1 and int(credit.run.xp) == prior_xp + int(credit.content.enemies.goblin.xp), "player-owned summons receive full kill and XP credit")
	var status_target: String = credit._spawn_enemy("skeleton", Vector2i(13, 8), false)
	credit._apply_status(status_target, "Stunned", 1, "Lunge", "player")
	_check(int(credit.run.combat_contributions.get(status_target, 0)) > 0, "player-owned harmful status application records meaningful participation")
	var neutral_target: String = credit._spawn_enemy("goblin", Vector2i(13, 8), false)
	credit._apply_status(neutral_target, "Haste", 1, "test", "player")
	_check(int(credit.run.combat_contributions.get(neutral_target, 0)) == 0, "non-harmful status does not qualify for assist XP")
	var assist = SimScript.new()
	assist.start_run(551233, "jim")
	var assisted_id: String = assist._spawn_enemy("skeleton", Vector2i(13, 8), false)
	assist.run.combat_contributions[assisted_id] = 4
	var assist_amount := maxi(1, int(floor(float(assist.content.enemies.skeleton.xp) * 0.5)))
	assist._on_death(assisted_id, "An enemy", "")
	_check(int(assist.run.assists) == 1 and int(assist.run.kills) == 0 and int(assist.run.xp) == assist_amount, "meaningful player contribution to another actor's kill receives assist XP")
	var no_credit = SimScript.new()
	no_credit.start_run(551234, "jim")
	var no_credit_id: String = no_credit._spawn_enemy("skeleton", Vector2i(13, 8), false)
	no_credit._on_death(no_credit_id, "An enemy", "")
	_check(int(no_credit.run.kills) == 0 and int(no_credit.run.assists) == 0 and int(no_credit.run.xp) == 0, "kills without player or summon participation grant no XP")

	var growth = SimScript.new()
	growth.start_run(551235, "jim")
	var starting_hp := int(growth.get_player().max_hp)
	var starting_vitality := int(growth.run.attributes.Vitality)
	growth._award_xp(35, "test")
	_check(int(growth.run.level) == 2 and int(growth.run.skill_points) == 1 and int(growth.get_player().max_hp) == starting_hp + 2, "level-up grants an ability point and durable character growth")
	_check(int(growth.run.attributes.Vitality) == starting_vitality + 1, "automatic attribute growth follows the character profile")
	_check(growth.run.combat_history.any(func(event: Dictionary) -> bool: return event.get("type", "") == "LevelUp" and event.get("details", {}).get("attribute", "") == "Vitality"), "level-up growth is included in the combat event feed")
	var xp_test = SimScript.new()
	xp_test.start_run(551238, "jim")
	xp_test.run.xp = 34
	xp_test._recording_presentation = true
	xp_test._action_presentation_events.clear()
	xp_test._award_xp(10, "kill")
	var level_event: Dictionary = {}
	for event in xp_test._action_presentation_events:
		if event.get("type", "") == "LevelUp": level_event = event
	_check(int(level_event.get("details", {}).get("xp", -1)) == 9, "level-up event reports the post-threshold XP for an accurate animated progress bar")
	growth.save_run()
	var growth_resumed = SimScript.new()
	_check(growth_resumed.resume_run() and int(growth_resumed.run.level) == 2 and int(growth_resumed.run.attributes.Vitality) == starting_vitality + 1, "level and automatic character growth survive save and resume")
	growth_resumed.delete_saved_run()

	var bar = SimScript.new()
	bar.start_run(551236, "jim")
	_check(bar.run.quickbar.size() == 8 and bar.run.quickbar.filter(func(slot: Dictionary) -> bool: return slot.get("type", "") == "empty").size() == 1, "quickbar is always eight slots and fills from starting actives and usable items")
	_check(bar.assign_quickbar(7, "ability", "lunge") and bar.run.quickbar[7].id == "lunge", "learned active abilities can be assigned by stable ability ID")
	_check(bar.run.quickbar.count({"type": "ability", "id": "lunge"}) == 1, "reassigning an ability clears its previous duplicate slot")
	_check(bar.assign_quickbar(7, "ability", "guard") and bar.run.quickbar[7].id == "guard" and bar.run.quickbar.count({"type": "ability", "id": "lunge"}) == 0, "replacing a slot preserves its selected position and clears old assignment")
	_check(bar.assign_quickbar(7, "empty", "") and bar.run.quickbar[7].get("type", "") == "empty", "active abilities can be explicitly removed from a slot")
	var passive_id := ""
	for ability_id in bar.content.abilities:
		if bar.content.abilities[ability_id].get("kind", "") == "passive":
			passive_id = String(ability_id)
			break
	_check(passive_id != "" and not bar.assign_quickbar(6, "ability", passive_id), "passive abilities cannot occupy active quickbar slots")
	_check(bar.assign_quickbar(6, "item", "healing_potion"), "usable item can be assigned to an action slot")
	bar.run.inventory.erase("healing_potion")
	_check(bar.run.quickbar[6] == {"type": "item", "id": "healing_potion"}, "item quickbar assignment remains stable when its stack is empty")
	bar.run.inventory.append("healing_potion")
	_check(bar.run.quickbar[6] == {"type": "item", "id": "healing_potion"} and bar.run.inventory.count("healing_potion") == 1, "reacquiring an item restores the same stable-ID quickbar assignment")
	for ability_id in bar.content.abilities:
		if bar.content.abilities[ability_id].get("kind", "active") != "passive" and not bar.run.known.has(ability_id):
			bar.run.known.append(ability_id)
	_check(bar.get_available_abilities().size() > 8, "the ability palette can expose more active abilities than the quickbar has slots")
	bar.save_run()
	var resumed = SimScript.new()
	_check(resumed.resume_run() and resumed.run.quickbar == bar.run.quickbar and resumed.run.quickbar_customized, "quickbar assignments survive save and resume")
	resumed.delete_saved_run()

	var modes: Array[String] = ["Normal", "Fast", "Instant"]
	var authoritative_digests: Array[String] = []
	for mode in modes:
		var main = MainScript.new()
		root.add_child(main)
		main.sim = SimScript.new()
		main.sim.start_run(551237, "jim")
		main.page = "battle"
		main.playback_mode = mode
		var mode_result: Dictionary = main.sim.act(move_command)
		main._commit_action(mode_result)
		authoritative_digests.append(main.sim.state_digest())
		if mode != "Instant":
			var before_blocked_input: String = main.sim.state_digest()
			main._handle_action({"type": "wait"})
			_check(main.playback_active and main.sim.state_digest() == before_blocked_input, "%s playback blocks overlapping gameplay input" % mode)
			main._handle_action({"type": "playback_skip"})
			_check(not main.playback_active, "%s playback can be skipped without changing simulation time" % mode)
		else:
			_check(not main.playback_active, "Instant mode presents the committed action without playback delay")
			var history_digest: String = main.sim.state_digest()
			main._handle_action({"type": "open_combat_history"})
			_check(main.overlay == "combat_history", "the recent-event panel opens the expandable encounter history")
			main._handle_action({"type": "close"})
			_check(main.overlay == "" and main.sim.state_digest() == history_digest, "history navigation is presentation-only")
		root.remove_child(main)
		main.free()
	_check(authoritative_digests.size() == 3 and authoritative_digests[0] == authoritative_digests[1] and authoritative_digests[1] == authoritative_digests[2], "Normal, Fast, and Instant presentation modes share one authoritative simulation result")

	print("COMBAT PRESENTATION CHECKS %d · FAILURES %d" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + failure)
	quit(1 if not failures.is_empty() else 0)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
