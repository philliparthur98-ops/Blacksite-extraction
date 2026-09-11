class_name BlacksitePlayerV102
extends BlacksitePlayer

# v1.02 raid-persistent weapon state + authored first-person presentation.
var weapon_runtime: Dictionary = {}

# Authored WRAD first-person arms. The build vendors this CC0 GLB before Godot import.
var authored_arms_model: Node3D
var authored_skeleton: Skeleton3D
var weapon_socket: BoneAttachment3D
var uses_authored_fp_arms: bool = false
var authored_motion_time: float = 0.0

func _persist_current_weapon() -> void:
    if weapon_data.is_empty() or weapon_ids.is_empty():
        return
    var id: String = weapon_ids[clampi(current_weapon_index,0,weapon_ids.size()-1)]
    weapon_runtime[id] = {
        "ammo": ammo,
        "reserve": reserve
    }

func _find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node as Skeleton3D
    for child in node.get_children():
        var found := _find_skeleton(child)
        if found != null:
            return found
    return null

func _find_weapon_socket_bone(skeleton: Skeleton3D) -> String:
    for exact in ["socket.r","socket_r","weapon.r","weapon_r","hand.r","hand_r","RightHand","right_hand"]:
        if skeleton.find_bone(exact) >= 0:
            return exact
    for i in range(skeleton.get_bone_count()):
        var bone_name := str(skeleton.get_bone_name(i))
        var lower := bone_name.to_lower()
        var right_side := lower.ends_with(".r") or lower.ends_with("_r") or lower.contains("right")
        if right_side and (lower.contains("socket") or lower.contains("hand") or lower.contains("wrist")):
            return bone_name
    return ""

func _configure_fp_meshes(node: Node) -> void:
    if node is MeshInstance3D:
        var mesh_node := node as MeshInstance3D
        mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        mesh_node.visibility_range_end = 0.0
    for child in node.get_children():
        _configure_fp_meshes(child)

func _build_first_person_arms() -> void:
    var asset := "res://assets/characters/WRAD_Arms.glb"
    if ResourceLoader.exists(asset):
        var packed = load(asset)
        if packed is PackedScene:
            arms_root = Node3D.new()
            arms_root.name = "FirstPersonArms"
            weapon_anchor.add_child(arms_root)

            authored_arms_model = (packed as PackedScene).instantiate()
            authored_arms_model.name = "WRAD_FirstPersonRig"
            authored_arms_model.position = Vector3.ZERO
            authored_arms_model.rotation_degrees = Vector3.ZERO
            authored_arms_model.scale = Vector3.ONE
            arms_root.add_child(authored_arms_model)
            _configure_fp_meshes(authored_arms_model)

            authored_skeleton = _find_skeleton(authored_arms_model)
            if authored_skeleton != null:
                var socket_bone := _find_weapon_socket_bone(authored_skeleton)
                if socket_bone != "":
                    weapon_socket = BoneAttachment3D.new()
                    weapon_socket.name = "WeaponSocket"
                    weapon_socket.bone_name = socket_bone
                    authored_skeleton.add_child(weapon_socket)
                    uses_authored_fp_arms = true
                    return

            # Asset loaded but did not expose a usable rig. Remove it before
            # falling back so the player never sees duplicate arms.
            arms_root.queue_free()
            arms_root = null
            authored_arms_model = null
            authored_skeleton = null
            weapon_socket = null

    super._build_first_person_arms()

func _socket_current_viewmodel() -> void:
    if not uses_authored_fp_arms or weapon_socket == null or viewmodel == null:
        return
    if not is_instance_valid(weapon_socket) or not is_instance_valid(viewmodel):
        return
    if viewmodel.get_parent() == weapon_socket:
        return
    # Preserve the base player's calibrated weapon placement at the instant it
    # becomes a child of the authored right-hand socket. Subsequent armature
    # motion carries the weapon and hands as one coherent first-person rig.
    viewmodel.reparent(weapon_socket,true)

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
    _socket_current_viewmodel()
    _emit_hud()

func _consume_round_state() -> bool:
    # Authoritative ammunition/cooldown state transition shared by normal
    # gameplay and the headless regression. Input, VFX, ballistics and audio
    # intentionally live outside this pure state transition.
    if dead or reloading or fire_cooldown > 0.0 or ammo <= 0:
        return false
    ammo -= 1
    fire_cooldown = 60.0/float(weapon_data.get("rpm",600.0))
    _persist_current_weapon()
    return true

func _try_fire() -> void:
    if dead or reloading or fire_cooldown > 0.0 or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
        return
    if ammo <= 0:
        toast_requested.emit("MAGAZINE EMPTY")
        return
    if not _consume_round_state():
        return

    weapon_kick = 0.18 if current_weapon_index == 2 else (0.075 if current_weapon_index == 1 else 0.105)
    var arm_ratio := minf(float(body_health["left_arm"])/float(max_health["left_arm"]),float(body_health["right_arm"])/float(max_health["right_arm"]))
    var injury_recoil := lerpf(1.7,1.0,clampf(arm_ratio,0.0,1.0))
    recoil_pitch += (0.72 if aiming else 1.06)*injury_recoil
    recoil_yaw += randf_range(-0.20,0.20)*injury_recoil
    camera_roll += randf_range(-0.30,0.30)

    muzzle_mesh.visible = true
    muzzle_mesh.rotation_degrees.z = randf_range(0.0,360.0)
    muzzle_light.light_energy = 5.6 if current_weapon_index != 2 else 7.2
    get_tree().create_timer(0.038).timeout.connect(func() -> void:
        if is_instance_valid(muzzle_mesh): muzzle_mesh.visible = false
        if is_instance_valid(muzzle_light): muzzle_light.light_energy = 0.0
    )
    if shot_audio and shot_audio.stream:
        shot_audio.pitch_scale = randf_range(0.97,1.025)
        shot_audio.play()

    if current_weapon_index == 1:
        _play_view_animation("slide-open",4.2)
        get_tree().create_timer(0.045).timeout.connect(func() -> void: _play_view_animation("slide-close",4.5))
    elif current_weapon_index == 2:
        get_tree().create_timer(0.18).timeout.connect(func() -> void: _play_view_animation("charge-open",2.0))
        get_tree().create_timer(0.34).timeout.connect(func() -> void: _play_view_animation("charge-close",2.0))

    _eject_casing()
    var pellets := int(weapon_data.get("pellets",1))
    for i in range(pellets):
        _fire_ray(i,pellets,arm_ratio)
    _emit_hud()

func _finish_reload() -> void:
    super._finish_reload()
    _persist_current_weapon()

func _process(delta: float) -> void:
    super._process(delta)
    if dead or not uses_authored_fp_arms or authored_arms_model == null or not is_instance_valid(authored_arms_model):
        return

    authored_motion_time += delta
    var target_pos := Vector3.ZERO
    var target_rot := Vector3.ZERO
    var idle_breath := sin(authored_motion_time*1.8)*0.006

    if sprinting:
        target_pos = Vector3(0.015,-0.030,0.018)
        target_rot = Vector3(-4.0,-2.0,4.5)
    elif reloading:
        var progress := 1.0-clampf(reload_timer/maxf(reload_total,0.01),0.0,1.0)
        target_pos = Vector3(-0.015,-0.018,0.015+sin(progress*PI)*0.018)
        target_rot = Vector3(3.0+sin(progress*PI)*4.0,2.5,-5.0)
    elif aiming:
        target_pos = Vector3(0.0,-0.006,-0.008)
        target_rot = Vector3(0.0,0.0,0.0)
    else:
        target_pos = Vector3(0.0,idle_breath,0.0)
        target_rot = Vector3(idle_breath*80.0,0.0,sin(authored_motion_time*1.15)*0.22)

    authored_arms_model.position = authored_arms_model.position.lerp(target_pos,clampf(delta*9.0,0.0,1.0))
    authored_arms_model.rotation_degrees = authored_arms_model.rotation_degrees.lerp(target_rot,clampf(delta*8.0,0.0,1.0))

func has_authored_first_person_rig() -> bool:
    return uses_authored_fp_arms and authored_skeleton != null and weapon_socket != null and is_instance_valid(weapon_socket) and viewmodel != null and is_instance_valid(viewmodel) and viewmodel.get_parent() == weapon_socket

func get_weapon_runtime_state(id: String) -> Dictionary:
    if id == weapon_ids[current_weapon_index]:
        _persist_current_weapon()
    return (weapon_runtime.get(id,{}) as Dictionary).duplicate(true)

func smoke_ammo_persistence_regression() -> bool:
    # Exercise the same production state transition used by live firing, plus
    # switching and production reload completion.
    _load_weapon(0)
    var id := weapon_ids[0]
    var starting_mag := ammo
    var starting_reserve := reserve
    if starting_mag < 4:
        return false

    fire_cooldown = 0.0
    if not _consume_round_state():
        return false
    var after_fire_mag := ammo
    if after_fire_mag != starting_mag-1 or reserve != starting_reserve:
        return false

    _load_weapon(1)
    _load_weapon(0)
    if ammo != after_fire_mag or reserve != starting_reserve:
        return false

    fire_cooldown = 0.0
    if not _consume_round_state():
        return false
    fire_cooldown = 0.0
    if not _consume_round_state():
        return false

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
