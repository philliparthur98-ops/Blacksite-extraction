class_name ProfileStore
extends RefCounted

const SAVE_PATH := "user://blacksite_profile.json"

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

static func load_profile() -> Dictionary:
    if not FileAccess.file_exists(SAVE_PATH):
        return default_profile()
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return default_profile()
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return default_profile()
    var p: Dictionary = parsed
    var d := default_profile()
    for key in d.keys():
        if not p.has(key):
            p[key] = d[key]
    return p

static func save_profile(profile: Dictionary) -> void:
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(profile, "  "))
