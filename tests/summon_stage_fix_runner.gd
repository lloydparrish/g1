extends SceneTree

const SimScript = preload("res://scripts/game_sim.gd")

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_suite")

func run_suite() -> void:
	_test_phantom_companion_ai()
	_test_summon_stage_transfer()
	_test_map_transfer_and_saves()
	_test_stage_healing()
	_test_deferred_summon_placement()
	print("SUMMON / STAGE FIXES %d · FAILURES %d" % [checks, failures.size()])
	for failure in failures: printerr("FAIL: " + failure)
	quit(1 if not failures.is_empty() else 0)

func _test_phantom_companion_ai() -> void:
	var sim = _fresh(71001)
	var player: Dictionary = sim.get_player()
	player.pos = [7, 8]
	var blade_id := _spawn_phantom(sim, Vector2i(5, 8))
	var blade: Dictionary = sim.run.entities[blade_id]
	var beyond_range_id: String = sim._spawn_enemy("goblin", Vector2i(11, 8), false)
	sim.run.entities[beyond_range_id].hp = 100
	sim.run.entities[beyond_range_id].max_hp = 100
	sim._companion_turn(blade_id)
	_check(int(sim.run.entities[beyond_range_id].hp) == 100 and _distance(sim._pos(blade), sim._pos(sim.run.entities[beyond_range_id])) == int(blade.range), "Phantom Blade closes distance but never attacks beyond its authored range")
	_check(sim._pos(blade) == Vector2i(6, 8), "Phantom Blade uses one legal movement step while engaging a nearby foe")

	var nearby = _fresh(71002)
	nearby.get_player().pos = [5, 8]
	var nearby_blade := _spawn_phantom(nearby, Vector2i(5, 8))
	var target_id: String = nearby._spawn_enemy("goblin", Vector2i(8, 8), false)
	nearby.run.entities[target_id].hp = 100
	nearby.run.entities[target_id].max_hp = 100
	nearby._companion_turn(nearby_blade)
	_check(int(nearby.run.entities[target_id].hp) == 91, "Phantom Blade attacks a hostile within its real range and clear line of sight")

	var wall_case = _fresh(71003)
	wall_case.get_player().pos = [5, 8]
	var wall_blade := _spawn_phantom(wall_case, Vector2i(5, 8))
	var blocked_target: String = wall_case._spawn_enemy("goblin", Vector2i(7, 8), false)
	wall_case.run.entities[blocked_target].hp = 100
	wall_case.run.entities[blocked_target].max_hp = 100
	wall_case._set_grid(Vector2i(6, 8), "wall")
	wall_case._companion_turn(wall_blade)
	_check(int(wall_case.run.entities[blocked_target].hp) == 100, "Phantom Blade does not attack through blocking terrain")

	var distant = _fresh(71004)
	distant.get_player().pos = [5, 8]
	var distant_blade := _spawn_phantom(distant, Vector2i(6, 8))
	var distant_target: String = distant._spawn_enemy("goblin", Vector2i(12, 8), false)
	var distant_start: Vector2i = distant._pos(distant.run.entities[distant_blade])
	distant._companion_turn(distant_blade)
	_check(distant._pos(distant.run.entities[distant_blade]) == distant_start and _distance(distant._pos(distant.run.entities[distant_target]), distant._pos(distant.get_player())) > 4, "Phantom Blade ignores distant enemies instead of pursuing them away from its owner")

	var follow = _fresh(71005)
	follow.get_player().pos = [12, 8]
	var following_blade := _spawn_phantom(follow, Vector2i(5, 8))
	follow._companion_turn(following_blade)
	_check(follow._pos(follow.run.entities[following_blade]) == Vector2i(6, 8), "Phantom Blade follows its summoner through a scheduled movement action")
	var move_events := 0
	for event in follow.run.get("combat_history", []):
		if String(event.get("type", "")) == "Move" and String(event.get("actor_name", "")) == "Phantom Blade": move_events += 1
	_check(move_events == 1, "companion following uses the shared movement event path")
	var beside_player = _fresh(71009)
	beside_player.get_player().pos = [12, 8]
	var co_located_blade := _spawn_phantom(beside_player, Vector2i(12, 8))
	beside_player._companion_turn(co_located_blade)
	_check(_distance(beside_player._pos(beside_player.run.entities[co_located_blade]), beside_player._pos(beside_player.get_player())) == 1, "an idle companion moves off its summoner's tile using its own scheduled action")
	for _step in range(4): follow._companion_turn(following_blade)
	var follow_distance := _distance(follow._pos(follow.run.entities[following_blade]), follow._pos(follow.get_player()))
	var settled_position: Vector2i = follow._pos(follow.run.entities[following_blade])
	follow._companion_turn(following_blade)
	_check(follow_distance <= 2 and follow._pos(follow.run.entities[following_blade]) == settled_position, "the companion settles within its preferred one-to-two-tile following distance")

	var return_case = _fresh(71006)
	return_case.get_player().pos = [15, 8]
	var returning_blade := _spawn_phantom(return_case, Vector2i(5, 8))
	var irrelevant_target: String = return_case._spawn_enemy("goblin", Vector2i(6, 8), false)
	return_case.run.entities[irrelevant_target].hp = 100
	var separated_before := _distance(return_case._pos(return_case.run.entities[returning_blade]), return_case._pos(return_case.get_player()))
	return_case._companion_turn(returning_blade)
	_check(_distance(return_case._pos(return_case.run.entities[returning_blade]), return_case._pos(return_case.get_player())) < separated_before and int(return_case.run.entities[irrelevant_target].hp) == 100, "a separated companion returns to its owner before engaging a foe outside the owner's vicinity")

	var blocked_path = _fresh(71007)
	blocked_path.get_player().pos = [12, 8]
	var path_blade := _spawn_phantom(blocked_path, Vector2i(5, 8))
	var blocker := {"id": "fixture_blocker", "kind": "enemy", "faction": "Adventurers", "alive": true, "pos": [6, 8], "footprint": 1}
	blocked_path.run.entities["fixture_blocker"] = blocker
	for y in range(1, SimScript.HEIGHT - 1):
		if y != 4: blocked_path._set_grid(Vector2i(8, y), "wall")
	var legal_step: Vector2i = blocked_path._next_step(blocked_path._pos(blocked_path.run.entities[path_blade]), blocked_path._pos(blocked_path.get_player()), path_blade)
	blocked_path._companion_turn(path_blade)
	_check(legal_step != Vector2i(6, 8) and blocked_path._pos(blocked_path.run.entities[path_blade]) == legal_step and blocked_path._terrain_at(legal_step) != "wall", "companion pathfinding respects occupied cells and routes around walls")

	var scheduler = _fresh(71008)
	scheduler.get_player().pos = [10, 8]
	var scheduled_blade := _spawn_phantom(scheduler, Vector2i(5, 8))
	scheduler.get_player().next_time = 0
	scheduler.run.entities[scheduled_blade].next_time = 0
	scheduler._spend_player_time(60, "")
	var scheduled_move_count := 0
	for event in scheduler.run.get("combat_history", []):
		if String(event.get("type", "")) == "Move" and String(event.get("actor_name", "")) == "Phantom Blade": scheduled_move_count += 1
	_check(scheduled_move_count == 1 and int(scheduler.run.entities[scheduled_blade].next_time) == 72, "following consumes the summon’s normal scheduled action time without granting an extra move")

func _test_summon_stage_transfer() -> void:
	var before_stage = _fresh(71999)
	var before_stage_summon := _spawn_summon(before_stage, "skeleton", Vector2i(5, 8))
	before_stage.get_player().hp = 10
	before_stage._complete_stage()
	before_stage.get_player().hp = 10
	_check(before_stage.save_run(), "a completed Stage saves before its transition")
	var resumed_before_stage = SimScript.new()
	_check(resumed_before_stage.resume_run() and int(resumed_before_stage.get_player().hp) == 10 and resumed_before_stage.run.entities.has(before_stage_summon), "resume immediately before a Stage transition keeps Health and summon state unchanged")
	var before_stage_healing := maxi(1, int(floor(float(resumed_before_stage.get_player().max_hp) * SimScript.STAGE_ENTRY_HEAL_PERCENT)))
	_check(resumed_before_stage.advance_stage() and int(resumed_before_stage.get_player().hp) == mini(int(resumed_before_stage.get_player().max_hp), 10 + before_stage_healing) and resumed_before_stage.run.entities.has(before_stage_summon), "the resumed completed Stage applies one heal and transfers its living summon")
	resumed_before_stage.delete_saved_run()

	var sim = _fresh(72001)
	var player: Dictionary = sim.get_player()
	player.pos = [12, 8]
	var command: Array = player.resources.Command
	command[1] = 10
	player.resources.Command = command
	var skeleton_a := _spawn_summon(sim, "skeleton", Vector2i(5, 8))
	var skeleton_b := _spawn_summon(sim, "skeleton", Vector2i(6, 8))
	var blade_id := _spawn_phantom(sim, Vector2i(7, 8))
	sim.run.entities[skeleton_a].hp = 5
	sim.run.entities[skeleton_a].statuses = {"Poisoned": {"stacks": 2, "duration": 3, "source": "test", "source_actor_id": "player"}}
	sim.run.entities[skeleton_a].next_time = 333
	sim.run.entities[skeleton_b].alive = false
	sim.run.entities[skeleton_b].hp = 0
	var expired_id := _spawn_summon(sim, "skeleton", Vector2i(8, 8))
	sim.run.entities[expired_id]["summon_duration_remaining"] = 0
	var second_live_id := _spawn_summon(sim, "phantom_blade", Vector2i(9, 8))
	sim.run.entities[second_live_id].hp = 7
	var hp_before := int(sim.run.entities[skeleton_a].hp)
	_check(hp_before == 5 and blade_id != second_live_id, "the transfer fixture has distinct living summons with retained individual state")
	var expected_live_ids := [skeleton_a, blade_id, second_live_id]
	sim._complete_stage()
	_check(sim.advance_stage(), "production Stage 1 completion advances into Stage 2")
	var transferred := true
	for summon_id in expected_live_ids:
		if not sim.run.entities.has(summon_id) or not _entity_has_valid_unoccupied_cell(sim, summon_id) or String(sim.run.entities[summon_id].get("owner", "")) != "player": transferred = false
	_check(transferred, "all living player summons transfer with identity and valid unoccupied placement")
	_check(not sim.run.entities.has(skeleton_b) and not sim.run.entities.has(expired_id), "dead and expired summons are not transferred")
	_check(int(sim.run.entities[skeleton_a].hp) == 5 and int(sim.run.entities[second_live_id].hp) == 7 and int(sim.run.entities[skeleton_a].next_time) == 333 and JSON.stringify(sim.run.entities[skeleton_a].statuses) == JSON.stringify({"Poisoned": {"stacks": 2, "duration": 3, "source": "test", "source_actor_id": "player"}}), "summon health, status duration, and timeline survive the stage change without healing")
	_check(int(sim.get_player().resources.Command[0]) == 3, "Command occupancy is rebuilt from the three living transferred summons only")
	var live_summon_ids: Array[String] = []
	var entity_ids_are_stable := true
	for entity_id in sim.run.entities:
		var entity: Dictionary = sim.run.entities[entity_id]
		if String(entity.get("id", "")) != String(entity_id): entity_ids_are_stable = false
		if bool(entity.get("is_summon", false)) and bool(entity.get("alive", false)): live_summon_ids.append(String(entity_id))
	_check(live_summon_ids.size() == 3 and live_summon_ids.has(skeleton_a) and live_summon_ids.has(blade_id) and live_summon_ids.has(second_live_id) and sim.run.pending_summon_transfers.is_empty() and entity_ids_are_stable, "the transition has no duplicate, missing, or unstable summon identities")
	var spawned_enemy: String = sim._spawn_enemy("skeleton", Vector2i(4, 4), false)
	_check(spawned_enemy != skeleton_a and sim.run.entities.has(skeleton_a) and sim.run.entities.has(spawned_enemy), "new enemy identity allocation cannot overwrite a transferred summon")
	_check(sim.save_run(), "a run saves immediately after a stage transition")
	var resumed = SimScript.new()
	_check(resumed.resume_run() and resumed.run.entities.has(skeleton_a) and int(resumed.run.entities[skeleton_a].hp) == 5 and String(resumed.run.entities[skeleton_a].owner) == "player", "save/resume after a stage transition preserves summon identity, ownership, and health")
	resumed.delete_saved_run()

func _test_map_transfer_and_saves() -> void:
	var sim = _fresh(73001)
	var player: Dictionary = sim.get_player()
	player.resources.Command = [0, 10]
	var living_id := _spawn_summon(sim, "skeleton", Vector2i(6, 8))
	sim.run.entities[living_id].hp = 4
	sim.run.entities[living_id].statuses = {"Guard": {"stacks": 1, "duration": 1}}
	for _stage in range(5):
		sim._complete_stage()
		_check(sim.advance_stage(), "an ordinary stage transition reaches the next stage in the map route")
	_check(int(sim.run.stage_index) == 5 and sim.run.entities.has(living_id), "the living summon remains present through all five ordinary stages")
	var boss_id := ""
	for entity_id in sim.run.entities:
		if String(sim.run.entities[entity_id].get("kind", "")) == "boss" and bool(sim.run.entities[entity_id].get("alive", false)): boss_id = String(entity_id)
	_check(boss_id != "", "the map transition fixture reaches its production Stage 6 boss")
	var player_hp: Dictionary = sim.get_player()
	player_hp.hp = 10
	sim._damage(boss_id, 999999, "Slashing", "fixture", "player")
	var hp_before_entry := int(sim.get_player().hp)
	_check(sim.run.stage_completed and sim.advance_stage(), "Stage 6 completion reveals the next map through the production flow")
	_check(int(sim.get_player().hp) == hp_before_entry and sim.run.entities.has(living_id), "map reveal alone does not heal or discard living summons")
	_check(sim.save_run(), "the completed Stage 6 state saves before entering the next map")
	var pre_entry = SimScript.new()
	_check(pre_entry.resume_run() and int(pre_entry.get_player().hp) == hp_before_entry and pre_entry.run.entities.has(living_id), "resume before map entry does not heal and retains the summon")
	var expected_heal := maxi(1, int(floor(float(pre_entry.get_player().max_hp) * SimScript.STAGE_ENTRY_HEAL_PERCENT)))
	var expected_hp := mini(int(pre_entry.get_player().max_hp), hp_before_entry + expected_heal)
	_check(pre_entry.enter_next_map(), "the saved completed run enters its revealed next map")
	_check(String(pre_entry.run.map_depth) == "2" and int(pre_entry.run.stage_index) == 0 and int(pre_entry.get_player().hp) == expected_hp, "Stage 6 to next-map Stage 1 applies the configured healing exactly on entry")
	_check(pre_entry.run.entities.has(living_id) and int(pre_entry.run.entities[living_id].hp) == 4 and JSON.stringify(pre_entry.run.entities[living_id].statuses) == JSON.stringify({"Guard": {"stacks": 1, "duration": 1}}), "map entry preserves summon health and remaining status duration without healing it")
	_check(pre_entry.save_run(), "the run saves immediately after the map transition")
	var post_entry = SimScript.new()
	_check(post_entry.resume_run() and int(post_entry.get_player().hp) == expected_hp and post_entry.run.entities.has(living_id) and int(post_entry.run.entities[living_id].hp) == 4, "save/resume after map entry preserves the once-healed player and injured summon")
	post_entry.delete_saved_run()

func _test_stage_healing() -> void:
	var initial = _fresh(74001)
	_check(int(initial.get_player().hp) == int(initial.get_player().max_hp) and String(initial.run.get("last_stage_heal_transition_key", "")) == "", "starting a run does not trigger stage-transition healing")
	initial.get_player().hp = 10
	_check(initial.save_run(), "a damaged stage can be saved before continuing")
	var loaded = SimScript.new()
	_check(loaded.resume_run() and int(loaded.get_player().hp) == 10, "saving and resuming an active stage does not trigger healing")
	loaded.delete_saved_run()

	var exact = _fresh(74002)
	exact.get_player().hp = 10
	exact._complete_stage()
	var hp_before := int(exact.get_player().hp)
	var expected := maxi(1, int(floor(float(exact.get_player().max_hp) * SimScript.STAGE_ENTRY_HEAL_PERCENT)))
	_check(exact.advance_stage() and int(exact.get_player().hp) == mini(int(exact.get_player().max_hp), hp_before + expected), "stage entry heals exactly floor five percent of maximum Health")
	var healed_hp := int(exact.get_player().hp)
	exact.run.stage_completed = true
	exact._new_stage(String(exact.run.stage_id), false, true, true)
	_check(int(exact.get_player().hp) == healed_hp, "re-entering the same saved stage transition cannot heal twice")

	var minimum = _fresh(74003)
	minimum.get_player().max_hp = 19
	minimum.get_player().hp = 1
	minimum._complete_stage()
	_check(minimum.advance_stage() and int(minimum.get_player().hp) == 2, "the minimum stage heal is one HP when five percent rounds down to zero")

	var capped = _fresh(74004)
	capped.get_player().hp = int(capped.get_player().max_hp) - 1
	capped._complete_stage()
	_check(capped.advance_stage() and int(capped.get_player().hp) == int(capped.get_player().max_hp), "stage healing never exceeds maximum Health")
	var legacy_save: Dictionary = capped.run.duplicate(true)
	legacy_save["version"] = 3
	legacy_save.erase("pending_summon_transfers")
	legacy_save.erase("last_stage_heal_transition_key")
	var migrated_save: Dictionary = capped._migrate_run_data(legacy_save)
	_check(int(migrated_save.get("version", 0)) == SimScript.SAVE_VERSION and migrated_save.get("pending_summon_transfers", []).is_empty() and String(migrated_save.get("last_stage_heal_transition_key", "")) == "", "version-3 saves migrate into version 4 without inventing summons or replaying a heal")

func _test_deferred_summon_placement() -> void:
	var sim = _fresh(75001)
	var player: Dictionary = sim.get_player()
	player.pos = [2, 2]
	player.resources.Command = [0, 5]
	sim.run.entities = {"player": player}
	sim.run.objects = []
	for y in range(SimScript.HEIGHT):
		for x in range(SimScript.WIDTH): sim._set_grid(Vector2i(x, y), "wall")
	sim._set_grid(Vector2i(2, 2), "floor")
	var snapshot := {"id": "deferred_skeleton_700", "enemy_id": "skeleton", "name": "Skeleton", "kind": "summon", "is_summon": true, "owner": "player", "faction": "Adventurers", "alive": true, "hp": 6, "max_hp": 18, "command_cost": 1, "footprint": 1, "pos": [8, 8], "statuses": {"Slow": {"stacks": 1, "duration": 2}}}
	sim._restore_transferred_summons([snapshot])
	_check(sim.run.entities.size() == 1 and sim.run.pending_summon_transfers.size() == 1 and int(player.resources.Command[0]) == 1, "a summon with no valid tile is safely retained in the serialized deferred-placement queue")
	_check(sim.save_run(), "a deferred summon transfer saves")
	var resumed = SimScript.new()
	_check(resumed.resume_run() and resumed.run.pending_summon_transfers.size() == 1, "save/resume preserves a summon awaiting a valid tile")
	resumed._set_grid(Vector2i(3, 2), "floor")
	resumed._place_pending_summons()
	_check(resumed.run.pending_summon_transfers.is_empty() and resumed.run.entities.has("deferred_skeleton_700") and _entity_has_valid_unoccupied_cell(resumed, "deferred_skeleton_700"), "the deferred summon uses the first deterministic newly available legal tile")
	_check(int(resumed.run.entities["deferred_skeleton_700"].hp) == 6 and String(resumed.run.entities["deferred_skeleton_700"].owner) == "player", "deferred placement retains health and ownership")
	resumed.delete_saved_run()

func _fresh(seed_value: int):
	var sim = SimScript.new()
	sim.delete_saved_run()
	sim.profile["unlocked_character_ids"] = sim.get_starting_character_ids().duplicate()
	sim.profile["pending_character_reveals"] = []
	sim.start_run(seed_value, "jim")
	for entity_id in sim.run.entities:
		if String(entity_id) != "player": sim.run.entities[entity_id]["alive"] = false
	for y in range(SimScript.HEIGHT):
		for x in range(SimScript.WIDTH):
			sim._set_grid(Vector2i(x, y), "wall" if x == 0 or y == 0 or x == SimScript.WIDTH - 1 or y == SimScript.HEIGHT - 1 else "floor")
	sim.run.visible = sim._bool_grid(true)
	sim.run.explored = sim._bool_grid(true)
	sim.run.objects = []
	return sim

func _spawn_phantom(sim, position: Vector2i) -> String:
	var spawned: bool = sim._spawn_summon("phantom_blade", sim._pos(sim.get_player()))
	if not spawned: return ""
	for entity_id in sim.run.entities:
		if String(sim.run.entities[entity_id].get("enemy_id", "")) == "phantom_blade":
			sim.run.entities[entity_id].pos = [position.x, position.y]
			return String(entity_id)
	return ""

func _spawn_summon(sim, summon_id: String, position: Vector2i) -> String:
	var spawned: bool = sim._spawn_summon(summon_id, position)
	if not spawned: return ""
	var selected := ""
	for entity_id in sim.run.entities:
		if String(sim.run.entities[entity_id].get("enemy_id", "")) == summon_id and bool(sim.run.entities[entity_id].get("alive", false)):
			var candidate_id := String(entity_id)
			if selected == "" or candidate_id > selected: selected = candidate_id
	return selected

func _entity_has_valid_unoccupied_cell(sim, entity_id: String) -> bool:
	if not sim.run.entities.has(entity_id): return false
	var entity: Dictionary = sim.run.entities[entity_id]
	var position: Vector2i = sim._pos(entity)
	if sim._terrain_at(position) == "wall": return false
	var size := maxi(1, int(entity.get("footprint", 1)))
	for y in range(position.y, position.y + size):
		for x in range(position.x, position.x + size):
			for other_id in sim.run.entities:
				if String(other_id) == entity_id or not sim.run.entities[other_id].get("alive", false): continue
				var other: Dictionary = sim.run.entities[other_id]
				var other_pos: Vector2i = sim._pos(other)
				var other_size := maxi(1, int(other.get("footprint", 1)))
				if x >= other_pos.x and y >= other_pos.y and x < other_pos.x + other_size and y < other_pos.y + other_size: return false
	return true

func _distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

func _check(condition: bool, title: String) -> void:
	checks += 1
	if not condition: failures.append(title)
