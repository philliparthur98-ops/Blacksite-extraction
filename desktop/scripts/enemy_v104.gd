class_name BlacksiteEnemyV104
extends BlacksiteEnemyV103

# v1.04 tactical combat layer: obstacle-aware routing, multi-stage perception,
# archetype-specific repositioning and physical hostile fire that obeys cover.
var alert_memory: float = 0.0
var search_points: Array[Vector3] = []
var search_index: int = 0
var route_waypoint: Vector3 = Vector3.ZERO
var route_waypoint_valid: bool = false
var reposition_timer: float = 0.0
var combat_goal: Vector3 = Vector3.ZERO
var combat_goal_valid: bool = false
var hold_timer: float = 0.0

func on_unsuppressed_gunfire(source_position: Vector3) -> void:
    if dead:
        return
    if global_position.distance_to(source_position) <= 58.0:
        _alert_to(source_position,7.0)

func on_ally_down(source_position: Vector3) -> void:
    if dead:
        return
    if global_position.distance_to(source_position) <= 42.0:
        _alert_to(source_position,8.0)

func _alert_to(source_position: Vector3, duration: float) -> void:
    last_seen = source_position
    alert_memory = maxf(alert_memory,duration)
    investigate_timer = maxf(investigate_timer,duration)
    if state != "combat":
        state = "alert"

func _physics_process(delta: float) -> void:
    if dead or target == null or not is_instance_valid(target):
        return
    phase += delta
    fire_cooldown = maxf(0.0,fire_cooldown-delta)
    burst_timer = maxf(0.0,burst_timer-delta)
    hit_reaction = maxf(0.0,hit_reaction-delta*4.0)
    alert_memory = maxf(0.0,alert_memory-delta)
    reposition_timer = maxf(0.0,reposition_timer-delta)
    hold_timer = maxf(0.0,hold_timer-delta)

    var to_target := target.global_position-global_position
    var dist := Vector2(to_target.x,to_target.z).length()
    var visible := _has_los(dist)

    if visible:
        state = "combat"
        last_seen = target.global_position
        alert_memory = 7.0
        investigate_timer = 7.0
        search_points.clear()
    elif state == "combat" or alert_memory > 0.0:
        state = "alert"
    elif state == "alert":
        state = "search"
        _begin_search()
    elif state == "search" and search_points.is_empty():
        _begin_search()

    match state:
        "combat": _combat_tactical(delta,dist,to_target)
        "alert": _investigate_tactical(delta)
        "search": _search_tactical(delta)
        "hold": _hold_tactical(delta)
        _: _patrol_tactical(delta)

    if not is_on_floor():
        velocity.y -= 18.0*delta
    move_and_slide()
    _animate_character(delta)

func _ray_clear(from_position: Vector3, to_position: Vector3, ignore_target: bool = true) -> bool:
    var from := from_position+Vector3(0,0.85,0)
    var to := to_position+Vector3(0,0.85,0)
    var query := PhysicsRayQueryParameters3D.create(from,to)
    var excluded: Array[RID] = [get_rid()]
    if ignore_target and target != null and is_instance_valid(target):
        excluded.append(target.get_rid())
    query.exclude = excluded
    query.collide_with_areas = false
    query.collide_with_bodies = true
    return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _route_direction(destination: Vector3) -> Vector3:
    var flat_destination := Vector3(destination.x,global_position.y,destination.z)
    if route_waypoint_valid:
        if global_position.distance_to(route_waypoint) < 0.75:
            route_waypoint_valid = false
        elif _ray_clear(global_position,route_waypoint):
            return (route_waypoint-global_position).normalized()
        else:
            route_waypoint_valid = false

    var direct := flat_destination-global_position
    direct.y = 0.0
    if direct.length() < 0.08:
        return Vector3.ZERO
    direct = direct.normalized()
    if _ray_clear(global_position,flat_destination):
        return direct

    # Equivalent local path solution for the authored Harbor geometry. Probe
    # both sides of a blocker and retain the first two-segment route that can
    # reach the destination. This avoids the old direct-steer wall pushing.
    var lateral := Vector3(-direct.z,0,direct.x)
    for radius in [3.0,5.0,7.0,9.0]:
        for side in [1.0,-1.0]:
            var candidate := global_position + direct*2.0 + lateral*float(radius)*float(side)
            if _ray_clear(global_position,candidate) and _ray_clear(candidate,flat_destination):
                route_waypoint = candidate
                route_waypoint_valid = true
                return (candidate-global_position).normalized()

    # If a full two-segment route is not visible yet, slide along the blocker
    # rather than continuing to push straight into it.
    var fallback_side := 1.0 if (get_instance_id() & 1) == 0 else -1.0
    return lateral*fallback_side

func _move_tactical(destination: Vector3, speed: float, delta: float) -> void:
    var direction := _route_direction(destination)
    if direction.length() < 0.05:
        velocity.x = move_toward(velocity.x,0.0,delta*6.0)
        velocity.z = move_toward(velocity.z,0.0,delta*6.0)
        return
    velocity.x = move_toward(velocity.x,direction.x*speed,delta*7.0)
    velocity.z = move_toward(velocity.z,direction.z*speed,delta*7.0)
    rotation.y = lerp_angle(rotation.y,atan2(-direction.x,-direction.z),delta*4.5)

func _begin_search() -> void:
    search_points.clear()
    search_index = 0
    var seed := last_seen
    search_points.append(seed)
    search_points.append(seed+Vector3(4.5,0,2.5))
    search_points.append(seed+Vector3(-3.5,0,4.0))
    search_points.append(seed+Vector3(2.0,0,-4.5))
    search_points.append(seed+Vector3(-4.5,0,-2.0))

func _investigate_tactical(delta: float) -> void:
    if global_position.distance_to(last_seen) > 1.4:
        _move_tactical(last_seen,2.5 if archetype != "scav" else 3.0,delta)
        return
    if alert_memory <= 0.0:
        state = "search"
        _begin_search()
    else:
        velocity.x = move_toward(velocity.x,0.0,delta*7.0)
        velocity.z = move_toward(velocity.z,0.0,delta*7.0)

func _search_tactical(delta: float) -> void:
    if search_points.is_empty():
        _begin_search()
    if search_index >= search_points.size():
        state = "hold"
        hold_timer = 2.5 if archetype == "guard" else 1.2
        return
    var point := search_points[search_index]
    if global_position.distance_to(point) < 1.2:
        search_index += 1
        route_waypoint_valid = false
        return
    _move_tactical(point,2.0 if archetype == "guard" else 2.5,delta)

func _hold_tactical(delta: float) -> void:
    velocity.x = move_toward(velocity.x,0.0,delta*7.0)
    velocity.z = move_toward(velocity.z,0.0,delta*7.0)
    if hold_timer <= 0.0:
        state = "patrol"
        patrol_target = patrol_origin+Vector3(randf_range(-7.0,7.0),0,randf_range(-7.0,7.0))

func _patrol_tactical(delta: float) -> void:
    if global_position.distance_to(patrol_target) < 1.0:
        patrol_target = patrol_origin+Vector3(randf_range(-7.0,7.0),0,randf_range(-7.0,7.0))
    _move_tactical(patrol_target,1.35,delta)

func _candidate_has_cover(candidate: Vector3) -> bool:
    if target == null or not is_instance_valid(target):
        return false
    return not _ray_clear(candidate,target.global_position,false)

func _choose_combat_goal(dist: float) -> Vector3:
    var to_player := target.global_position-global_position
    to_player.y = 0.0
    var forward := to_player.normalized() if to_player.length() > 0.05 else Vector3.FORWARD
    var lateral := Vector3(-forward.z,0,forward.x)
    var choices: Array[Vector3] = []

    match archetype:
        "scav":
            choices = [target.global_position-forward*5.0+lateral*4.0,target.global_position-forward*5.0-lateral*4.0,target.global_position-forward*7.0]
        "guard":
            choices = [global_position-forward*4.0+lateral*3.5,global_position-forward*4.0-lateral*3.5,global_position+lateral*5.0,global_position-lateral*5.0]
        _:
            choices = [target.global_position-forward*10.0+lateral*8.0,target.global_position-forward*10.0-lateral*8.0,global_position+lateral*7.0,global_position-lateral*7.0]

    var best := global_position
    var best_score := -100000.0
    for candidate in choices:
        var candidate_dist := candidate.distance_to(target.global_position)
        var score := 0.0
        if _ray_clear(global_position,candidate): score += 4.0
        if archetype != "scav" and _candidate_has_cover(candidate): score += 6.0
        if archetype == "guard": score -= absf(candidate_dist-13.0)*0.25
        elif archetype == "raider": score -= absf(candidate_dist-15.0)*0.18
        else: score -= absf(candidate_dist-7.0)*0.28
        if score > best_score:
            best_score = score
            best = candidate
    return best

func _combat_tactical(delta: float, dist: float, to_target: Vector3) -> void:
    rotation.y = lerp_angle(rotation.y,atan2(-to_target.x,-to_target.z),delta*6.0)
    if reposition_timer <= 0.0 or not combat_goal_valid or global_position.distance_to(combat_goal) < 1.2:
        combat_goal = _choose_combat_goal(dist)
        combat_goal_valid = true
        reposition_timer = randf_range(1.4,2.4) if archetype == "scav" else randf_range(2.4,4.0)
        route_waypoint_valid = false

    var desired_speed := 3.2 if archetype == "scav" else (2.25 if archetype == "guard" else 2.75)
    if global_position.distance_to(combat_goal) > 1.1:
        _move_tactical(combat_goal,desired_speed,delta)
    else:
        velocity.x = move_toward(velocity.x,0.0,delta*8.0)
        velocity.z = move_toward(velocity.z,0.0,delta*8.0)

    if burst_remaining > 0 and burst_timer <= 0.0:
        _shoot_once(dist)
        burst_remaining -= 1
        burst_timer = 0.095 if archetype == "raider" else (0.15 if archetype == "guard" else 0.20)
    elif fire_cooldown <= 0.0 and dist < 34.0:
        burst_remaining = 3 if archetype == "raider" else (2 if archetype == "guard" else 1)
        fire_cooldown = randf_range(0.95,1.55) if archetype == "raider" else randf_range(1.35,2.35)

func _shoot_once(dist: float) -> void:
    muzzle.visible = true
    muzzle.rotation_degrees.z = randf_range(0.0,360.0)
    muzzle_light.light_energy = 4.5
    rifle_root.rotation_degrees.x -= 2.2
    get_tree().create_timer(0.045).timeout.connect(func() -> void:
        if is_instance_valid(muzzle): muzzle.visible = false
        if is_instance_valid(muzzle_light): muzzle_light.light_energy = 0.0)
    if shot_audio and shot_audio.stream:
        shot_audio.pitch_scale = randf_range(0.93,1.06)
        shot_audio.play()
    _fire_physical_shot(dist,false)

func _fire_physical_shot(dist: float, deterministic: bool = false) -> bool:
    if target == null or not is_instance_valid(target):
        return false
    var origin := muzzle.global_position if muzzle != null and is_instance_valid(muzzle) else global_position+Vector3(0,1.5,0)
    var aim_point := target.global_position+Vector3(0,1.25,0)
    var direction := (aim_point-origin).normalized()
    if not deterministic:
        var spread := clampf(0.018+dist*0.0012,0.018,0.060)
        if archetype == "raider": spread *= 0.68
        elif archetype == "guard": spread *= 0.82
        direction = (direction+Vector3(randf_range(-spread,spread),randf_range(-spread,spread),randf_range(-spread,spread))).normalized()
    var query := PhysicsRayQueryParameters3D.create(origin,origin+direction*55.0)
    query.exclude = [get_rid()]
    query.collide_with_areas = false
    query.collide_with_bodies = true
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty() or hit.get("collider") != target:
        return false

    var roll := 0.50 if deterministic else randf()
    var part := "thorax"
    if not deterministic:
        if roll < 0.05: part = "head"
        elif roll < 0.31: part = "left_arm" if randf() < 0.5 else "right_arm"
        elif roll < 0.55: part = "stomach"
        elif roll < 0.78: part = "left_leg" if randf() < 0.5 else "right_leg"
    var damage := 10.0 if deterministic else (randf_range(8.0,13.0) if archetype != "raider" else randf_range(10.0,16.0))
    target.apply_damage(damage,part,0.22 if archetype == "scav" else 0.38)
    return true

func smoke_route_direction_to(destination: Vector3) -> Vector3:
    route_waypoint_valid = false
    return _route_direction(destination)

func smoke_fire_at_target_deterministic() -> bool:
    return _fire_physical_shot(global_position.distance_to(target.global_position),true)
