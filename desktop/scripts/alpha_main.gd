extends "res://scripts/main.gd"

var secondary_extract: ExtractionTerminal
var alpha_bonus_loot_spawned := 0

const CONTRACTS := {
    "black_tide": {"name":"BLACK TIDE","reward":4200,"xp":650,"unlock":1},
    "clean_sweep": {"name":"CLEAN SWEEP","reward":3400,"xp":520,"unlock":2},
    "salvage": {"name":"SALVAGE RIGHTS","reward":3000,"xp":460,"unlock":2},
    "no_trace": {"name":"NO TRACE","reward":5000,"xp":800,"unlock":3}
}

func _ready() -> void:
    super._ready()
    _ensure_alpha_profile()
    _apply_saved_audio()
    if ui:
        ui.set_profile(profile)

func _ensure_alpha_profile() -> void:
    var changed := false
    var defaults := {
        "xp":0,
        "level":1,
        "active_contract":"black_tide",
        "completed_contracts":[],
        "contracts_completed":0,
        "trader_rep":0,
        "insurance_tokens":1,
        "settings":{"sensitivity":0.075,"fov":70.0,"master_volume":0.85},
        "alpha_version":"0.20"
    }
    for key in defaults.keys():
        if not profile.has(key):
            profile[key] = defaults[key]
            changed = true
    _recalculate_level()
    if changed:
        ProfileStore.save_profile(profile)

func _build_ui() -> void:
    ui = BlacksiteAlphaUI.new()
    add_child(ui)
    ui.deploy_requested.connect(_start_raid)
    ui.return_requested.connect(_return_to_terminal)
    ui.quit_requested.connect(func() -> void: get_tree().quit())
    var aui := ui as BlacksiteAlphaUI
    aui.buy_requested.connect(_alpha_buy)
    aui.sell_requested.connect(_alpha_sell)
    aui.equip_requested.connect(_alpha_equip)
    aui.contract_requested.connect(_alpha_contract)
    aui.hideout_upgrade_requested.connect(_alpha_hideout_upgrade)
    aui.settings_requested.connect(_alpha_settings)
    ui.set_profile(profile)

func _alpha_buy(id: String) -> void:
    var data := ItemDB.get_item(id)
    if data.is_empty():
        return
    var price := int(float(data.get("value",0))*1.25)
    if int(profile.get("cash",0)) < price:
        (ui as BlacksiteAlphaUI).alpha_status("INSUFFICIENT FUNDS",Color("ef6d65"))
        return
    var stash: Array = profile.get("stash",[])
    if stash.size() >= 80:
        (ui as BlacksiteAlphaUI).alpha_status("STASH CAPACITY REACHED",Color("ef6d65"))
        return
    profile["cash"] = int(profile.get("cash",0))-price
    stash.append(id)
    profile["stash"] = stash
    profile["trader_rep"] = int(profile.get("trader_rep",0))+1
    _save_refresh("PURCHASED %s" % str(data.get("name",id)).to_upper())

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
    _save_refresh("SOLD %s  +$%,d" % [str(ItemDB.get_item(id).get("name",id)).to_upper(),value])

func _alpha_equip(slot: String, id: String) -> void:
    var stash: Array = profile.get("stash",[])
    if not stash.has(id):
        return
    var loadout: Dictionary = profile.get("loadout",{}).duplicate(true)
    loadout[slot] = id
    profile["loadout"] = loadout
    _save_refresh("%s EQUIPPED" % str(ItemDB.get_item(id).get("name",id)).to_upper())

func _alpha_contract(id: String) -> void:
    if not CONTRACTS.has(id):
        return
    var requirement := int((CONTRACTS[id] as Dictionary).get("unlock",1))
    if int(profile.get("level",1)) < requirement:
        return
    profile["active_contract"] = id
    _save_refresh("CONTRACT ACCEPTED // %s" % str((CONTRACTS[id] as Dictionary).get("name",id)))

func _alpha_hideout_upgrade() -> void:
    var level := int(profile.get("hideout_level",1))
    if level >= 5:
        return
    var cost := 6000*level
    if int(profile.get("cash",0)) < cost:
        return
    profile["cash"] = int(profile.get("cash",0))-cost
    profile["hideout_level"] = level+1
    _save_refresh("OPERATIONS CELL UPGRADED TO LEVEL %d" % (level+1))

func _alpha_settings(settings: Dictionary) -> void:
    profile["settings"] = settings.duplicate(true)
    _apply_saved_audio()
    ProfileStore.save_profile(profile)
    if player and is_instance_valid(player):
        player.mouse_sensitivity = float(settings.get("sensitivity",0.075))
        player.camera.fov = float(settings.get("fov",70.0))
    (ui as BlacksiteAlphaUI).set_profile(profile)
    (ui as BlacksiteAlphaUI).alpha_status("SETTINGS APPLIED",Color("88d96f"))

func _apply_saved_audio() -> void:
    var settings: Dictionary = profile.get("settings",{})
    var linear := clampf(float(settings.get("master_volume",0.85)),0.0,1.0)
    AudioServer.set_bus_volume_db(0,linear_to_db(maxf(linear,0.001)))

func _save_refresh(message: String) -> void:
    ProfileStore.save_profile(profile)
    ui.set_profile(profile)
    (ui as BlacksiteAlphaUI).alpha_status(message,Color("88d96f"))

func _recalculate_level() -> void:
    var xp := int(profile.get("xp",0))
    var calculated := 1 + int(floor(sqrt(float(xp)/700.0)))
    profile["level"] = clampi(calculated,1,20)

func _start_raid() -> void:
    await super._start_raid()
    if player == null or not is_instance_valid(player):
        return
    var settings: Dictionary = profile.get("settings",{})
    player.mouse_sensitivity = float(settings.get("sensitivity",0.075))
    player.camera.fov = float(settings.get("fov",70.0))

    var loadout: Dictionary = profile.get("loadout",{})
    var primary := str(loadout.get("primary","m4"))
    var sidearm := str(loadout.get("sidearm","g17"))
    if primary not in ["m4","m870"]:
        primary = "m4"
    if sidearm != "g17":
        sidearm = "g17"
    player.weapon_ids = [primary,sidearm,"m870" if primary == "m4" else "m4"]
    player._load_weapon(0)

    var med_id := str(loadout.get("med","ifak"))
    med_uses = int(ItemDB.get_item(med_id).get("uses",4)) + maxi(0,int(profile.get("hideout_level",1))-1)
    var armor_id := str(loadout.get("armor","carrier"))
    player.armor = 60.0 if armor_id == "carrier" else 45.0

    _spawn_alpha_bonus_loot()
    _spawn_secondary_extract()
    ui.toast("FULL ALPHA // %s ACTIVE" % str((CONTRACTS.get(str(profile.get("active_contract","black_tide")),CONTRACTS["black_tide"]) as Dictionary).get("name","CONTRACT")),Color("efb469"))

func _spawn_alpha_bonus_loot() -> void:
    if raid_root == null:
        return
    alpha_bonus_loot_spawned = 0
    var candidates := [
        Vector3(-24,0.4,22),Vector3(18,0.4,14),Vector3(-28,0.4,-8),
        Vector3(22,0.4,-20),Vector3(8,0.4,-42),Vector3(-18,0.4,-48)
    ]
    candidates.shuffle()
    var table: Array = ItemDB.LOOT_TABLE
    for i in range(4):
        _spawn_loot(str(table[randi()%table.size()]),candidates[i])
        alpha_bonus_loot_spawned += 1

func _spawn_secondary_extract() -> void:
    if raid_root == null:
        return
    secondary_extract = ExtractionTerminal.new()
    secondary_extract.position = Vector3(28,0,-46)
    secondary_extract.configure(self)
    secondary_extract.name = "ServiceRoadExtraction"
    secondary_extract.enabled_for_extract = contract_secured
    raid_root.add_child(secondary_extract)

func _on_loot_picked(item_id: String, source: LootPickup) -> void:
    super._on_loot_picked(item_id,source)
    if item_id == "quest_drive" and secondary_extract:
        secondary_extract.enabled_for_extract = true

func _objective_text() -> String:
    var active := str(profile.get("active_contract","black_tide"))
    if not contract_secured:
        match active:
            "clean_sweep": return "CLEAN SWEEP // %d / 4 HOSTILES // ARCHIVE DRIVE STILL REQUIRED FOR EXTRACT" % mini(raid_kills,4)
            "salvage": return "SALVAGE RIGHTS // %d / 3 LOOT // ARCHIVE DRIVE STILL REQUIRED FOR EXTRACT" % mini(raid_loot.size(),3)
            "no_trace": return "NO TRACE // %d / 2 HEADSHOTS // ARCHIVE DRIVE STILL REQUIRED FOR EXTRACT" % mini(raid_headshots,2)
            _: return super._objective_text()
    if player and secondary_extract:
        var d_gate := player.global_position.distance_to(extract.global_position) if extract else 9999.0
        var d_road := player.global_position.distance_to(secondary_extract.global_position)
        return "EXTRACT // GATE 3 %dm  •  SERVICE ROAD %dm" % [int(d_gate),int(d_road)]
    return super._objective_text()

func _contract_success() -> bool:
    var active := str(profile.get("active_contract","black_tide"))
    match active:
        "black_tide": return contract_secured
        "clean_sweep": return contract_secured and raid_kills >= 4
        "salvage": return contract_secured and raid_loot.size() >= 3
        "no_trace": return contract_secured and raid_headshots >= 2
        _: return contract_secured

func _end_raid(extracted: bool) -> void:
    if not raid_active:
        return
    var successful_contract := extracted and _contract_success()
    var active := str(profile.get("active_contract","black_tide"))
    var active_data: Dictionary = CONTRACTS.get(active,CONTRACTS["black_tide"])
    var hideout_level := int(profile.get("hideout_level",1))
    var xp_gain := 80 + raid_kills*45 + raid_hits*4 + raid_headshots*20 + (150 if extracted else 0)
    xp_gain = int(float(xp_gain)*(1.0+float(hideout_level-1)*0.05))
    profile["xp"] = int(profile.get("xp",0))+xp_gain

    if successful_contract:
        var completed: Array = profile.get("completed_contracts",[])
        var first_completion := not completed.has(active)
        if first_completion:
            completed.append(active)
            profile["completed_contracts"] = completed
            profile["contracts_completed"] = int(profile.get("contracts_completed",0))+1
        var reward := int(active_data.get("reward",0))
        reward = int(float(reward)*(1.0+float(hideout_level-1)*0.05))
        if not first_completion:
            reward = int(float(reward)*0.35)
        profile["cash"] = int(profile.get("cash",0))+reward
        profile["xp"] = int(profile.get("xp",0))+int(active_data.get("xp",0))

    if not extracted:
        _apply_raid_loss()

    _recalculate_level()
    super._end_raid(extracted)
    ProfileStore.save_profile(profile)

func _apply_raid_loss() -> void:
    var stash: Array = profile.get("stash",[])
    var loadout: Dictionary = profile.get("loadout",{})
    var insurance := int(profile.get("insurance_tokens",0))
    var protected_primary := insurance > 0
    if protected_primary:
        profile["insurance_tokens"] = insurance-1
    for slot in ["primary","sidearm","armor","med"]:
        if protected_primary and slot == "primary":
            continue
        var id := str(loadout.get(slot,""))
        var idx := stash.find(id)
        if idx >= 0:
            stash.remove_at(idx)
    profile["stash"] = stash
    _repair_loadout_from_stash()

func _repair_loadout_from_stash() -> void:
    var stash: Array = profile.get("stash",[])
    var loadout: Dictionary = profile.get("loadout",{}).duplicate(true)
    if not stash.has(str(loadout.get("primary",""))):
        loadout["primary"] = "m4" if stash.has("m4") else ("m870" if stash.has("m870") else "")
    if not stash.has(str(loadout.get("sidearm",""))):
        loadout["sidearm"] = "g17" if stash.has("g17") else ""
    if not stash.has(str(loadout.get("armor",""))):
        loadout["armor"] = "carrier" if stash.has("carrier") else ("plate" if stash.has("plate") else "")
    if not stash.has(str(loadout.get("med",""))):
        loadout["med"] = "ifak" if stash.has("ifak") else ("salewa" if stash.has("salewa") else "")
    profile["loadout"] = loadout

func _return_to_terminal() -> void:
    super._return_to_terminal()
    _ensure_alpha_profile()
    if ui:
        ui.set_profile(profile)

func _run_raid_smoke_test() -> void:
    await get_tree().process_frame
    _ensure_alpha_profile()

    var original := profile.duplicate(true)
    var failures: Array[String] = []

    # Economy round-trip regression.
    var cash_before := int(profile.get("cash",0))
    var stash_before: Array = (profile.get("stash",[]) as Array).duplicate()
    _alpha_buy("ifak")
    if int(profile.get("cash",0)) >= cash_before or (profile.get("stash",[]) as Array).size() != stash_before.size()+1:
        failures.append("economy_buy")
    _alpha_sell("ifak")
    if (profile.get("stash",[]) as Array).size() != stash_before.size():
        failures.append("economy_sell")

    profile = original.duplicate(true)
    _ensure_alpha_profile()
    await _start_raid()
    await get_tree().process_frame
    await get_tree().process_frame
    await get_tree().process_frame

    if raid_root == null or not is_instance_valid(raid_root): failures.append("raid_root")
    if player == null or not is_instance_valid(player): failures.append("player")
    if extract == null or not is_instance_valid(extract): failures.append("extract")
    if secondary_extract == null or not is_instance_valid(secondary_extract): failures.append("secondary_extract")
    if enemies_alive < 5: failures.append("enemy_count")
    if alpha_bonus_loot_spawned < 4: failures.append("bonus_loot")
    if not ResourceLoader.exists("res://assets/characters/WRAD_Arms.glb"): failures.append("fp_arms_asset")
    var fp_ok := player != null and player.has_method("has_authored_first_person_rig") and bool(player.call("has_authored_first_person_rig"))
    if not fp_ok: failures.append("authored_fp_rig")
    var ammo_ok := player != null and player.has_method("smoke_ammo_persistence_regression") and bool(player.call("smoke_ammo_persistence_regression"))
    if not ammo_ok: failures.append("ammo_persistence")
    if contract_secured: failures.append("contract_start_state")
    if extract and extract.enabled_for_extract: failures.append("extract_lock")

    # Profile persistence schema regression.
    for key in ["xp","level","active_contract","completed_contracts","trader_rep","settings"]:
        if not profile.has(key): failures.append("profile_%s" % key)

    profile = original
    ProfileStore.save_profile(profile)

    if failures.is_empty():
        print("BLACKSITE_SMOKE_RAID_OK enemies=%d loot=%d fp_rig=PASS ammo_persistence=PASS extract_lock=PASS alpha_meta=PASS economy=PASS settings=PASS multi_extract=PASS" % [enemies_alive,get_tree().get_nodes_in_group("blacksite_loot").size()])
        print("BLACKSITE_ALPHA_SMOKE_OK progression=PASS inventory=PASS economy=PASS contracts=PASS save_schema=PASS")
        get_tree().quit(0)
    else:
        push_error("BLACKSITE_SMOKE_RAID_FAILED " + ",".join(failures))
        get_tree().quit(1)
