extends "res://scripts/alpha_main_v104.gd"

func _create_enemy() -> BlacksiteEnemy:
    return BlacksiteEnemyV104.new()

func _body_total(p: BlacksitePlayer) -> float:
    var total := 0.0
    for value in p.body_health.values(): total += float(value)
    return total

func _smoke_tactical_enemy_regression() -> Array[String]:
    var failures: Array[String] = []
    var root := Node3D.new()
    root.name = "TacticalSmokeRoot"
    add_child(root)

    var dummy := BlacksitePlayerV102.new()
    dummy.setup(self)
    dummy.position = Vector3(8,10,0)
    root.add_child(dummy)
    dummy.process_mode = Node.PROCESS_MODE_DISABLED

    var hostile := BlacksiteEnemyV104.new()
    hostile.configure(dummy,"guard")
    hostile.position = Vector3(-8,10,0)
    root.add_child(hostile)
    hostile.process_mode = Node.PROCESS_MODE_DISABLED

    var blocker := StaticBody3D.new()
    blocker.name = "TacticalSmokeBlocker"
    blocker.position = Vector3(0,10,0)
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(2.0,3.8,8.0)
    shape.shape = box
    blocker.add_child(shape)
    root.add_child(blocker)

    await get_tree().physics_frame
    await get_tree().physics_frame

    var before := _body_total(dummy)
    var did_hit := hostile.smoke_fire_at_target_deterministic()
    var after := _body_total(dummy)
    if did_hit or absf(after-before) > 0.001:
        failures.append("hostile_cover_block")

    var route := hostile.smoke_route_direction_to(dummy.global_position)
    if route.length() < 0.5 or absf(route.z) < 0.10:
        failures.append("hostile_obstacle_route")

    hostile.on_unsuppressed_gunfire(Vector3(-2,10,1))
    if hostile.state != "alert" or hostile.alert_memory <= 0.0:
        failures.append("hostile_gunfire_alert")

    root.queue_free()
    await get_tree().process_frame
    await get_tree().process_frame
    return failures

func _run_raid_smoke_test() -> void:
    await get_tree().process_frame
    var tactical_failures := await _smoke_tactical_enemy_regression()
    if not tactical_failures.is_empty():
        push_error("BLACKSITE_TACTICAL_SMOKE_FAILED " + ",".join(tactical_failures))
        get_tree().quit(1)
        return
    print("BLACKSITE_TACTICAL_SMOKE_OK cover_block=PASS obstacle_route=PASS gunfire_alert=PASS")
    await super._run_raid_smoke_test()
