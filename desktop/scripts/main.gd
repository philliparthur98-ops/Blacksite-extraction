extends Node

var profile: Dictionary = {}
var ui: BlacksiteUI
var world: WorldBuilder
var player: BlacksitePlayer
var extract: ExtractionTerminal
var raid_root: Node3D
var raid_active: bool = false
var raid_time: float = 900.0
var raid_loot: Array[String] = []
var contract_secured: bool = false
var raid_kills: int = 0
var raid_hits: int = 0
var raid_headshots: int = 0
var enemies_alive: int = 0
var start_msec: int = 0
var med_uses: int = 4
var quest_position: Vector3 = Vector3(-2,1,-32)
var impact_material: StandardMaterial3D
var smoke_raid_mode: bool = false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    smoke_raid_mode = OS.get_cmdline_user_args().has("--smoke-raid")
    profile = ProfileStore.load_profile()
    _ensure_input_map()
    _build_ui()
    _prepare_impact_material()
    if smoke_raid_mode:
        call_deferred("_run_raid_smoke_test")

func _run_raid_smoke_test() -> void:
    await get_tree().process_frame
    _start_raid()
    await get_tree().process_frame
    await get_tree().process_frame
    await get_tree().process_frame
    var failures: Array[String] = []
    if raid_root == null or not is_instance_valid(raid_root): failures.append("raid_root")
    if world == null or not is_instance_valid(world): failures.append("world")
    if player == null or not is_instance_valid(player): failures.append("player")
    if extract == null or not is_instance_valid(extract): failures.append("extract")
    if enemies_alive < 5: failures.append("enemy_count=%d" % enemies_alive)
    var pickups := get_tree().get_nodes_in_group("blacksite_loot")
    if pickups.size() < 5: failures.append("loot_count=%d" % pickups.size())

    if not ResourceLoader.exists("res://assets/weapons/VXR_Carbine.glb"): failures.append("vxr_asset")
    if not ResourceLoader.exists("res://assets/weapons/P9_Duty.glb"): failures.append("p9_asset")
    if not ResourceLoader.exists("res://assets/weapons/SG12_Breacher.glb"): failures.append("sg12_asset")
    if not ResourceLoader.exists("res://assets/characters/GorgeholdScout.glb"): failures.append("character_asset")
    if player != null and player.viewmodel == null: failures.append("player_viewmodel")

    var enemy_nodes := get_tree().get_nodes_in_group("blacksite_enemy")
    var rigged_count := 0
    for enemy_node in enemy_nodes:
        if bool(enemy_node.get("uses_character_asset")):
            rigged_count += 1
    if enemy_nodes.size() < 5: failures.append("enemy_group=%d" % enemy_nodes.size())
    if rigged_count < 5: failures.append("rigged_enemies=%d" % rigged_count)

    if failures.is_empty():
        print("BLACKSITE_SMOKE_RAID_OK enemies=%d rigged=%d loot=%d objective=%s viewmodel=%s" % [enemies_alive,rigged_count,pickups.size(),str(quest_position),str(player.viewmodel.name)])
        get_tree().quit(0)
    else:
        push_error("BLACKSITE_SMOKE_RAID_FAILED " + ",".join(failures))
        get_tree().quit(1)

func _ensure_input_map() -> void:
    _key_action("move_forward",KEY_W)
    _key_action("move_back",KEY_S)
    _key_action("move_left",KEY_A)
    _key_action("move_right",KEY_D)
    _key_action("sprint",KEY_SHIFT)
    _key_action("crouch",KEY_CTRL)
    _key_action("reload",KEY_R)
    _key_action("interact",KEY_F)
    _key_action("inventory",KEY_TAB)
    _key_action("weapon_1",KEY_1)
    _key_action("weapon_2",KEY_2)
    _key_action("weapon_3",KEY_3)
    _mouse_action("fire",MOUSE_BUTTON_LEFT)
    _mouse_action("aim",MOUSE_BUTTON_RIGHT)

func _key_action(action: StringName, code: int) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    if InputMap.action_get_events(action).is_empty():
        var event := InputEventKey.new()
        event.physical_keycode = code
        InputMap.action_add_event(action,event)

func _mouse_action(action: StringName, button: int) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    if InputMap.action_get_events(action).is_empty():
        var event := InputEventMouseButton.new()
        event.button_index = button
        InputMap.action_add_event(action,event)

func _build_ui() -> void:
    ui = BlacksiteUI.new()
    add_child(ui)
    ui.deploy_requested.connect(_start_raid)
    ui.return_requested.connect(_return_to_terminal)
    ui.quit_requested.connect(func() -> void: get_tree().quit())
    ui.set_profile(profile)

func _prepare_impact_material() -> void:
    impact_material = StandardMaterial3D.new()
    impact_material.albedo_color = Color("1b1d1e")
    impact_material.roughness = 0.9

func _start_raid() -> void:
    if raid_root and is_instance_valid(raid_root):
        raid_root.queue_free()
        await get_tree().process_frame

    raid_root = Node3D.new()
    raid_root.name = "RaidRoot"
    add_child(raid_root)

    world = WorldBuilder.new()
    raid_root.add_child(world)
    var layout: Dictionary = world.build()
    quest_position = layout.get("quest_pos",Vector3(-2,1,-32))

    player = BlacksitePlayer.new()
    player.setup(self)
    player.position = layout.get("player_spawn",Vector3(0,1,45))
    player.died.connect(_on_player_died)
    player.hud_state_changed.connect(_on_player_hud)
    player.interaction_prompt.connect(func(text: String) -> void: ui.set_prompt(text))
    player.toast_requested.connect(func(text: String) -> void: ui.toast(text))
    raid_root.add_child(player)

    raid_loot.clear()
    contract_secured = false
    raid_kills = 0
    raid_hits = 0
    raid_headshots = 0
    raid_time = 900.0
    med_uses = 4
    start_msec = Time.get_ticks_msec()
    enemies_alive = 0

    var enemy_defs: Array = layout.get("enemy_spawns",[])
    for definition in enemy_defs:
        var enemy := BlacksiteEnemy.new()
        enemy.configure(player,str(definition.get("type","scav")))
        enemy.position = definition.get("pos",Vector3.ZERO)
        enemy.killed.connect(_on_enemy_killed)
        raid_root.add_child(enemy)
        enemies_alive += 1

    var loot_defs: Array = layout.get("loot_spawns",[])
    for definition in loot_defs:
        _spawn_loot(str(definition.get("id","tools")),definition.get("pos",Vector3.ZERO))
    _spawn_loot("quest_drive",quest_position)

    extract = ExtractionTerminal.new()
    extract.position = layout.get("extract_pos",Vector3(0,0,52))
    extract.configure(self)
    extract.enabled_for_extract = false
    raid_root.add_child(extract)

    raid_active = true
    ui.show_raid()
    ui.toast("BLACK TIDE // INSERTION LIVE",Color("efb469"))
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _spawn_loot(id: String, pos: Vector3) -> void:
    if raid_root == null:
        return
    var loot := LootPickup.new()
    loot.position = pos
    loot.configure(id)
    loot.picked.connect(_on_loot_picked)
    loot.add_to_group("blacksite_loot")
    raid_root.add_child(loot)

func _on_loot_picked(item_id: String, source: LootPickup) -> void:
    if not raid_active:
        return
    if item_id == "quest_drive":
        contract_secured = true
        if extract:
            extract.enabled_for_extract = true
        ui.toast("CONTRACT ITEM SECURED // GATE 3 UNLOCKED",Color("6fe8ef"))
    else:
        raid_loot.append(item_id)
        var data := ItemDB.get_item(item_id)
        ui.toast("LOOT SECURED IN PACK // %s" % str(data.get("name",item_id)).to_upper(),ItemDB.rarity_color(str(data.get("rarity","common"))))
    if is_instance_valid(source):
        source.queue_free()

func _on_enemy_killed(enemy: BlacksiteEnemy, archetype: String) -> void:
    raid_kills += 1
    enemies_alive = maxi(0,enemies_alive-1)
    var chance := 0.78 if archetype == "raider" else 0.48
    if randf() < chance:
        var table: Array = ItemDB.LOOT_TABLE
        var id := str(table[randi()%table.size()])
        if is_instance_valid(enemy):
            _spawn_loot(id,enemy.global_position+Vector3(0,0.25,0))
    ui.toast("HOSTILE DOWN // %d REMAINING" % enemies_alive,Color("d9e7ea"))

func register_hit(headshot: bool) -> void:
    raid_hits += 1
    if headshot:
        raid_headshots += 1
    ui.hit(headshot)

func spawn_impact(pos: Vector3, normal: Vector3) -> void:
    if not raid_root:
        return
    var decal := MeshInstance3D.new()
    var quad := QuadMesh.new()
    quad.size = Vector2(0.08,0.08)
    decal.mesh = quad
    decal.material_override = impact_material
    decal.global_position = pos+normal*0.006
    var up := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.97 else Vector3.RIGHT
    decal.look_at(pos-normal,up)
    raid_root.add_child(decal)
    get_tree().create_timer(18.0).timeout.connect(func() -> void:
        if is_instance_valid(decal): decal.queue_free()
    )

func use_med() -> void:
    if not raid_active or player == null or not is_instance_valid(player):
        return
    if med_uses <= 0:
        ui.toast("IFAK EMPTY",Color("ef6961"))
        return
    med_uses -= 1
    player.heal(42.0)
    ui.toast("IFAK APPLIED // %d USES REMAIN" % med_uses,Color("88d96f"))

func request_extract() -> void:
    if not raid_active:
        return
    if not contract_secured:
        ui.toast("EXTRACTION LOCKED // CONTRACT ITEM REQUIRED",Color("ed6860"))
        return
    _end_raid(true)

func toggle_raid_inventory() -> void:
    if raid_active:
        ui.toggle_raid_inventory(raid_loot)

func _on_player_died() -> void:
    _end_raid(false)

func _on_player_hud(_state: Dictionary) -> void:
    pass

func _process(delta: float) -> void:
    if not raid_active or player == null or not is_instance_valid(player):
        return
    raid_time -= delta
    if raid_time <= 0.0:
        ui.toast("RAID TIMER EXPIRED",Color("ed6860"))
        _end_raid(false)
        return
    ui.update_hud(player.get_hud_state(),raid_time,_objective_text(),raid_loot)

func _objective_text() -> String:
    if player == null:
        return ""
    if not contract_secured:
        var distance := player.global_position.distance_to(quest_position)
        return "BLACK TIDE // SECURE ARCHIVE DRIVE // %dm" % int(distance)
    if extract:
        var distance := player.global_position.distance_to(extract.global_position)
        return "EXTRACT // GATE 3 // %dm" % int(distance)
    return "EXTRACT // GATE 3"

func _end_raid(extracted: bool) -> void:
    if not raid_active:
        return
    raid_active = false
    if player and is_instance_valid(player):
        player.set_physics_process(false)
        player.set_process(false)
        player.set_process_input(false)
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

    profile["raid_count"] = int(profile.get("raid_count",0))+1
    profile["kills"] = int(profile.get("kills",0))+raid_kills
    if extracted:
        profile["extractions"] = int(profile.get("extractions",0))+1
        var stash: Array = profile.get("stash",[])
        var cash_gain := 0
        for id in raid_loot:
            stash.append(id)
            cash_gain += int(ItemDB.get_item(id).get("value",0))
        profile["stash"] = stash
        profile["cash"] = int(profile.get("cash",0))+cash_gain
        profile["best_raid_value"] = maxi(int(profile.get("best_raid_value",0)),cash_gain)
    else:
        profile["deaths"] = int(profile.get("deaths",0))+1
    ProfileStore.save_profile(profile)

    var stats := {
        "kills":raid_kills,
        "hits":raid_hits,
        "headshots":raid_headshots,
        "time":float(Time.get_ticks_msec()-start_msec)/1000.0
    }
    var recovered: Array = raid_loot if extracted else []
    ui.show_result(extracted,stats,recovered)

func _return_to_terminal() -> void:
    if raid_root and is_instance_valid(raid_root):
        raid_root.queue_free()
    raid_root = null
    player = null
    world = null
    extract = null
    ui.show_menu(profile)
