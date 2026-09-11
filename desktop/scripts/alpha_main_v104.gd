extends "res://scripts/alpha_main_v103.gd"

# Smoke-only lifecycle hardening. Keep live object references valid until their
# queued deletes are actually processed so player callbacks cannot dereference
# an already-cleared UI while the final frame is draining.
func _smoke_cleanup() -> void:
    raid_active = false
    if raid_root != null and is_instance_valid(raid_root):
        raid_root.process_mode = Node.PROCESS_MODE_DISABLED
        raid_root.queue_free()
    if ui != null and is_instance_valid(ui):
        ui.process_mode = Node.PROCESS_MODE_DISABLED
        ui.queue_free()
    LootPickupV103.release_cached_assets()

    await get_tree().process_frame
    await get_tree().process_frame
    await get_tree().process_frame
    await get_tree().process_frame
    await get_tree().process_frame

    raid_root = null
    player = null
    world = null
    extract = null
    secondary_extract = null
    ui = null
