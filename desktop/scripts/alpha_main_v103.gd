extends "res://scripts/alpha_main.gd"

var recovery_loaner_active: bool = false

func _create_world_builder() -> WorldBuilder:
    return WorldBuilderV103.new()

func _create_enemy() -> BlacksiteEnemy:
    return BlacksiteEnemyV103.new()

func _create_loot_pickup() -> LootPickup:
    return LootPickupV103.new()

func _build_ui() -> void:
    ui = BlacksiteAlphaUIV103.new()
    add_child(ui)
    ui.deploy_requested.connect(_start_raid)
    ui.return_requested.connect(_return_to_terminal)
    ui.quit_requested.connect(func() -> void: get_tree().quit())
    var aui := ui as BlacksiteAlphaUIV103
    aui.buy_requested.connect(_alpha_buy)
    aui.sell_requested.connect(_alpha_sell)
    aui.equip_requested.connect(_alpha_equip)
    aui.contract_requested.connect(_alpha_contract)
    aui.hideout_upgrade_requested.connect(_alpha_hideout_upgrade)
    aui.settings_requested.connect(_alpha_settings)
    ui.set_profile(profile)

func _alpha_sell(id: String) -> void:
    var stash: Array = profile.get("stash",[])
    var idx := stash.find(id)
    if idx < 0:
        return
    var loadout: Dictionary = profile.get("loadout",{})
    var equipped_count := 0
    for slot in loadout.keys():
        if str(loadout[slot]) == id:
            equipped_count += 1
    if stash.count(id) <= equipped_count:
        (ui as BlacksiteAlphaUI).alpha_status("ITEM EQUIPPED — CHANGE LOADOUT FIRST",Color("ef6d65"))
        return
    var value := int(float(ItemDB.get_item(id).get("value",0))*0.72)
    stash.remove_at(idx)
    profile["stash"] = stash
    profile["cash"] = int(profile.get("cash",0))+value
    var value_text := str(value)
    if ui is BlacksiteAlphaUIV103:
        value_text = (ui as BlacksiteAlphaUIV103)._format_int(value)
    _save_refresh("SOLD %s  +$%s" % [str(ItemDB.get_item(id).get("name",id)).to_upper(),value_text])

func _resolve_raid_kit() -> Dictionary:
    var stash: Array = profile.get("stash",[])
    var loadout: Dictionary = profile.get("loadout",{})
    var weapons: Array[String] = []

    var primary := str(loadout.get("primary",""))
    if primary in ["m4","m870"] and stash.has(primary):
        weapons.append(primary)
    var sidearm := str(loadout.get("sidearm",""))
    if sidearm == "g17" and stash.has(sidearm):
        weapons.append(sidearm)

    var loaner := weapons.is_empty()
    if loaner:
        # Explicit recovery kit: one P9 only, no armor and no medical supply.
        # It is intentionally not inserted into the persistent stash and is not
        # eligible for sale, insurance or retention.
        weapons.append("g17")

    var armor := str(loadout.get("armor",""))
    if armor == "" or not stash.has(armor) or str(ItemDB.get_item(armor).get("kind","")) != "armor":
        armor = ""
    var med := str(loadout.get("med",""))
    if med == "" or not stash.has(med) or str(ItemDB.get_item(med).get("kind","")) != "med":
        med = ""

    return {"weapons":weapons,"armor":armor,"med":med,"loaner":loaner}

func _apply_resolved_raid_kit() -> void:
    if player == null or not is_instance_valid(player):
        return
    var kit := _resolve_raid_kit()
    recovery_loaner_active = bool(kit.get("loaner",false))
    var weapons: Array[String] = kit.get("weapons",[]) as Array[String]
    player.weapon_ids = weapons
    if player is BlacksitePlayerV102:
        (player as BlacksitePlayerV102).weapon_runtime.clear()
    player._load_weapon(0)

    var armor_id := str(kit.get("armor",""))
    match armor_id:
        "carrier": player.armor = 60.0
        "plate": player.armor = 45.0
        _: player.armor = 0.0

    var med_id := str(kit.get("med",""))
    med_uses = 0
    if med_id != "":
        med_uses = int(ItemDB.get_item(med_id).get("uses",0)) + maxi(0,int(profile.get("hideout_level",1))-1)

    if recovery_loaner_active and ui:
        ui.toast("RECOVERY LOANER // P9 ONLY // NO ARMOR // NO MEDS",Color("efb469"))

func _start_raid() -> void:
    # The inherited alpha start creates the world and applies its legacy defaults.
    # Before control returns to the player, replace those defaults with an
    # authoritative inventory-backed kit (or the explicit recovery loaner).
    await super._start_raid()
    _apply_resolved_raid_kit()

func _spawn_alpha_bonus_loot() -> void:
    if raid_root == null:
        return
    alpha_bonus_loot_spawned = 0
    var candidates := [
        Vector3(-121,0.42,116),Vector3(119,0.42,108),Vector3(-72,0.42,61),
        Vector3(69,0.42,52),Vector3(-126,0.42,-39),Vector3(124,0.42,-52),
        Vector3(-76,0.42,-118),Vector3(78,0.42,-124),Vector3(-15,0.42,-151),
        Vector3(42,0.42,-143),Vector3(-44,0.42,145),Vector3(53,0.42,137)
    ]
    candidates.shuffle()
    var table: Array = ItemDB.LOOT_TABLE
    for i in range(8):
        _spawn_loot(str(table[randi()%table.size()]),candidates[i])
        alpha_bonus_loot_spawned += 1

func _spawn_secondary_extract() -> void:
    if raid_root == null:
        return
    secondary_extract = ExtractionTerminal.new()
    secondary_extract.position = Vector3(148,0,-157)
    secondary_extract.configure(self)
    secondary_extract.name = "ServiceRoadExtraction"
    secondary_extract.enabled_for_extract = contract_secured
    raid_root.add_child(secondary_extract)

func _smoke_cleanup() -> void:
    raid_active = false
    if raid_root != null and is_instance_valid(raid_root):
        raid_root.queue_free()
    raid_root = null
    player = null
    world = null
    extract = null
    secondary_extract = null
    if ui != null and is_instance_valid(ui):
        ui.queue_free()
    ui = null
    LootPickupV103.release_cached_assets()
    # Give deferred deletion and the dummy renderer multiple idle cycles.
    await get_tree().process_frame
    await get_tree().process_frame
    await get_tree().process_frame
    await get_tree().process_frame

func _smoke_raid_loss_integrity() -> bool:
    var before := profile.duplicate(true)
    profile = ProfileStore.default_profile()
    _ensure_alpha_profile()
    profile["stash"] = ["m4","g17","carrier","ifak"]
    profile["loadout"] = {"primary":"m4","sidearm":"g17","armor":"carrier","med":"ifak"}
    profile["insurance_tokens"] = 0
    _apply_raid_loss()
    var stash_after: Array = profile.get("stash",[])
    var kit := _resolve_raid_kit()
    var weapons: Array = kit.get("weapons",[])
    var ok := stash_after.is_empty() and bool(kit.get("loaner",false)) and weapons.size() == 1 and str(weapons[0]) == "g17" and str(kit.get("armor","")) == "" and str(kit.get("med","")) == ""
    profile = before
    return ok

func _run_raid_smoke_test() -> void:
    await get_tree().process_frame
    _ensure_alpha_profile()
    var saved_profile := profile.duplicate(true)
    var failures: Array[String] = []

    if not ProfileStore.smoke_save_recovery_regression():
        failures.append("save_recovery")
    if not _smoke_raid_loss_integrity():
        failures.append("raid_loss_integrity")

    profile = ProfileStore.default_profile()
    _ensure_alpha_profile()
    profile["cash"] = 50000
    var stash_start := (profile.get("stash",[]) as Array).size()
    var cash_start := int(profile.get("cash",0))
    _alpha_buy("ifak")
    if int(profile.get("cash",0)) >= cash_start or (profile.get("stash",[]) as Array).size() != stash_start+1:
        failures.append("economy_buy")
    _alpha_sell("ifak")
    if (profile.get("stash",[]) as Array).size() != stash_start:
        failures.append("economy_sell")

    await _start_raid()
    await get_tree().process_frame
    await get_tree().process_frame
    await get_tree().process_frame
    await get_tree().process_frame

    if raid_root == null or not is_instance_valid(raid_root): failures.append("raid_root")
    if player == null or not is_instance_valid(player): failures.append("player")
    if world == null or not is_instance_valid(world): failures.append("world")
    if extract == null or not is_instance_valid(extract): failures.append("extract")
    if secondary_extract == null or not is_instance_valid(secondary_extract): failures.append("secondary_extract")
    if enemies_alive < 12: failures.append("enemy_count=%d" % enemies_alive)
    if alpha_bonus_loot_spawned < 8: failures.append("bonus_loot")

    var world_ok := world is WorldBuilderV103 and (world as WorldBuilderV103).smoke_world_scale_ok()
    if not world_ok:
        failures.append("world_scale_or_authored_districts")

    var fp_ok := player.has_method("has_authored_first_person_rig") and bool(player.call("has_authored_first_person_rig"))
    var grip_ok := player.has_method("smoke_grip_alignment_ok") and bool(player.call("smoke_grip_alignment_ok"))
    if not fp_ok: failures.append("fp_rig")
    if not grip_ok: failures.append("weapon_grip_alignment")
    var ammo_ok := player.has_method("smoke_ammo_persistence_regression") and bool(player.call("smoke_ammo_persistence_regression"))
    if not ammo_ok: failures.append("ammo_persistence")

    if contract_secured: failures.append("contract_should_start_unsecured")
    if extract and extract.enabled_for_extract: failures.append("primary_extract_should_start_locked")
    if secondary_extract and secondary_extract.enabled_for_extract: failures.append("secondary_extract_should_start_locked")

    var enemy_nodes := get_tree().get_nodes_in_group("blacksite_enemy")
    var enemy_assets: Dictionary = {}
    var authored_enemies := 0
    for node in enemy_nodes:
        if node is BlacksiteEnemyV103:
            var path := (node as BlacksiteEnemyV103).get_presentation_asset()
            if path != "": enemy_assets[path] = true
            if bool(node.get("uses_character_asset")): authored_enemies += 1
    if authored_enemies < 10: failures.append("authored_enemy_count=%d" % authored_enemies)
    if enemy_assets.size() < 3: failures.append("enemy_visual_variety=%d" % enemy_assets.size())

    var pickups := get_tree().get_nodes_in_group("blacksite_loot")
    var authored_loot := 0
    for pickup in pickups:
        if pickup is LootPickupV103 and (pickup as LootPickupV103).smoke_has_authored_asset():
            authored_loot += 1
    if pickups.size() < 20: failures.append("loot_count=%d" % pickups.size())
    if authored_loot < 12: failures.append("authored_loot=%d" % authored_loot)

    var ui_ok := ui is BlacksiteAlphaUIV103 and (ui as BlacksiteAlphaUIV103).smoke_workspace_ok()
    if not ui_ok: failures.append("ui_workspace")

    var smoke_line := "BLACKSITE_SMOKE_RAID_OK enemies=%d authored_enemies=%d enemy_variants=%d loot=%d authored_loot=%d world_extent=%.0fm world_scale=PASS fp_rig=PASS grip=PASS ammo_persistence=PASS extract_lock=PASS economy=PASS raid_loss=PASS save_recovery=PASS ui_v103=PASS" % [enemies_alive,authored_enemies,enemy_assets.size(),pickups.size(),authored_loot,(world as WorldBuilderV103).map_extent_m]
    profile = saved_profile

    if failures.is_empty():
        await _smoke_cleanup()
        print(smoke_line)
        get_tree().quit(0)
    else:
        push_error("BLACKSITE_SMOKE_RAID_FAILED " + ",".join(failures))
        await _smoke_cleanup()
        get_tree().quit(1)
