class_name BlacksitePlayerV102
extends BlacksitePlayer

# v1.02 weapon runtime state. The base player owns presentation and combat;
# this subclass guarantees per-weapon magazine/reserve persistence for the raid.
var weapon_runtime: Dictionary = {}

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
    # Exercise the same fire/switch/reload code paths used in a raid.
    _load_weapon(0)
    var id := weapon_ids[0]
    var starting_mag := ammo
    var starting_reserve := reserve
    if starting_mag < 4:
        return false

    fire_cooldown = 0.0
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    _try_fire()
    var after_fire_mag := ammo
    if after_fire_mag != starting_mag-1 or reserve != starting_reserve:
        return false

    _load_weapon(1)
    _load_weapon(0)
    if ammo != after_fire_mag or reserve != starting_reserve:
        return false

    # Spend two more rounds, reload through the production reload completion
    # path, then switch away/back and verify the consumed reserve stays consumed.
    fire_cooldown = 0.0
    _try_fire()
    fire_cooldown = 0.0
    _try_fire()
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
