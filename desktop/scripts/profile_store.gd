class_name ProfileStore
extends RefCounted

const SAVE_PATH := "user://blacksite_profile.json"
const TEMP_PATH := "user://blacksite_profile.tmp"
const BACKUP_PATH := "user://blacksite_profile.bak"

static func default_profile() -> Dictionary:
    return {
        "cash": 18500,
        "stash": ItemDB.STARTER_STASH.duplicate(),
        "loadout": {"primary":"m4","sidearm":"g17","armor":"carrier","med":"ifak"},
        "extractions": 0,
        "deaths": 0,
        "kills": 0,
        "raid_count": 0,
        "best_raid_value": 0,
        "hideout_level": 1
    }

static func _read_valid(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var file := FileAccess.open(path,FileAccess.READ)
    if file == null:
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return {}
    return (parsed as Dictionary).duplicate(true)

static func _merge_defaults(profile: Dictionary) -> Dictionary:
    var p := profile.duplicate(true)
    var defaults := default_profile()
    for key in defaults.keys():
        if not p.has(key):
            p[key] = defaults[key]
    return p

static func _load_from_paths(primary: String, backup: String, temp: String) -> Dictionary:
    for path in [primary,backup,temp]:
        var candidate := _read_valid(path)
        if not candidate.is_empty():
            return _merge_defaults(candidate)
    return default_profile()

static func load_profile() -> Dictionary:
    return _load_from_paths(SAVE_PATH,BACKUP_PATH,TEMP_PATH)

static func _remove_if_present(path: String) -> void:
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

static func _save_atomic(profile: Dictionary, primary: String, temp: String, backup: String) -> bool:
    _remove_if_present(temp)
    var file := FileAccess.open(temp,FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(profile,"  "))
    file.flush()
    file = null

    if _read_valid(temp).is_empty():
        _remove_if_present(temp)
        return false

    var primary_abs := ProjectSettings.globalize_path(primary)
    var temp_abs := ProjectSettings.globalize_path(temp)
    var backup_abs := ProjectSettings.globalize_path(backup)
    _remove_if_present(backup)

    if FileAccess.file_exists(primary):
        if DirAccess.rename_absolute(primary_abs,backup_abs) != OK:
            _remove_if_present(temp)
            return false

    if DirAccess.rename_absolute(temp_abs,primary_abs) != OK:
        if FileAccess.file_exists(backup):
            DirAccess.rename_absolute(backup_abs,primary_abs)
        _remove_if_present(temp)
        return false
    return true

static func save_profile(profile: Dictionary) -> void:
    if not _save_atomic(profile,SAVE_PATH,TEMP_PATH,BACKUP_PATH):
        push_error("BLACKSITE profile save failed; previous valid profile was preserved.")

static func smoke_save_recovery_regression() -> bool:
    var primary := "user://blacksite_profile_smoke.json"
    var temp := "user://blacksite_profile_smoke.tmp"
    var backup := "user://blacksite_profile_smoke.bak"
    _remove_if_present(primary)
    _remove_if_present(temp)
    _remove_if_present(backup)

    var first := default_profile()
    first["cash"] = 11111
    if not _save_atomic(first,primary,temp,backup):
        return false
    var second := first.duplicate(true)
    second["cash"] = 22222
    if not _save_atomic(second,primary,temp,backup):
        return false

    # Simulate a torn/corrupt newest save. The prior committed profile must survive.
    var corrupt := FileAccess.open(primary,FileAccess.WRITE)
    if corrupt == null:
        return false
    corrupt.store_string("{corrupt")
    corrupt.flush()
    corrupt = null
    var recovered := _load_from_paths(primary,backup,temp)
    var ok := int(recovered.get("cash",0)) == 11111

    _remove_if_present(primary)
    _remove_if_present(temp)
    _remove_if_present(backup)
    return ok
