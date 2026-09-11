class_name BlacksitePlayerV102
extends BlacksitePlayer

# v1.02 weapon runtime state. The base player owns presentation and combat;
# this subclass guarantees per-weapon magazine/reserve persistence for the raid.
var weapon_runtime: Dictionary = {}
var smoke_bypass_fire_input: bool = false

func _persist_current_weapon() -> void:
    if weapon_data.is_empty() or weapon_ids.is_empty():
        return
    var id: String = weapon_ids[clampi(current_weapon_index,0,weapon_ids.size()-1)]
    weapon_runtime[id] = {
        "ammo": ammo,
        "reserve": reserve
    }

func _load_weapon(index: int) -> void:
    # Save the weapon being put away before the base implementation changes index.
    _persist_current_weapon()
    var target_index := clampi(index,0,weapon_ids.size()-1)
    var target_id: String = weapon_ids[target_index]
    var had_state := weapon_runtime.has(target_id)

    super._load_weapon(target_index)

    # First equip initializes from ItemDB once. Every later equip restores the
    # exact raid state instead of manufacturing a fresh magazine/reserve pool.
    if had_state:
        var state: Dictionary = weapon_runtime[target_id]
        ammo = int(state.get("ammo",ammo))
        reserve = int(state.get("reserve",reserve))
    else:
        weapon_runtime[target_id] = {"ammo":ammo,"reserve":reserve}
    _emit_hud()

func _try_fire() -> void:
    # Headless CI cannot capture a system cursor, so the smoke path exercises
    # the exact ammunition mutation/persistence portion of a shot without
    # depending on DisplayServer mouse state. Normal gameplay still delegates
    # to the full base firing path including ballistics, recoil, audio and VFX.
    if smoke_bypass_fire_input:
        if ammo <= 0 or reloading or fire_cooldown > 0.0:
            return
        ammo -= 1
        fire_cooldown = 60.0/float(weapon_data.get("rpm",600.0))
        _persist_current_weapon()
        return

    var before := ammo
    super._try_fire()
    if ammo != before:
        _persist_current_weapon()

func _finish_reload() -> void:
    super._finish_reload()
    _persist_current_weapon()

func get_weapon_runtime_state(id: String) -> Dictionary:
    if id == weapon_ids[current_weapon_index]:
        _persist_current_weapon()
    return (weapon_runtime.get(id,{}) as Dictionary).duplicate(true)

func smoke_ammo_persistence_regression() -> bool:
    # Exercise fire-state mutation, switching and production reload completion.
    _load_weapon(0)
    var id := weapon_ids[0]
    var starting_mag := ammo
    var starting_reserve := reserve
    if starting_mag < 4:
        return false

    smoke_bypass_fire_input = true
    fire_cooldown = 0.0
    _try_fire()
    var after_fire_mag := ammo
    if after_fire_mag != starting_mag-1 or reserve != starting_reserve:
        smoke_bypass_fire_input = false
        return false

    _load_weapon(1)
    _load_weapon(0)
    if ammo != after_fire_mag or reserve != starting_reserve:
        smoke_bypass_fire_input = false
        return false

    # Spend two more rounds, reload through the production reload completion
    # path, then switch away/back and verify consumed reserve remains consumed.
    fire_cooldown = 0.0
    _try_fire()
    fire_cooldown = 0.0
    _try_fire()
    smoke_bypass_fire_input = false

    var pre_reload_mag := ammo
    var pre_reload_reserve := reserve
    var capacity := int(weapon_data.get("mag",30))
    var expected_take := mini(capacity-pre_reload_mag,pre_reload_reserve)
    _start_reload()
    if not reloading:
        return false
    _finish_reload()
    var expected_mag := pre_reload_mag+expected_take
    var expected_reserve := pre_reload_reserve-expected_take
    if ammo != expected_mag or reserve != expected_reserve:
        return false

    _load_weapon(2)
    _load_weapon(0)
    var state := get_weapon_runtime_state(id)
    return ammo == expected_mag and reserve == expected_reserve and int(state.get("ammo",-1)) == expected_mag and int(state.get("reserve",-1)) == expected_reserve
