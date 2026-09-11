class_name BlacksitePlayer
extends CharacterBody3D

signal died
signal hud_state_changed(state: Dictionary)
signal interaction_prompt(text: String)
signal toast_requested(text: String)

var game: Node
var mouse_sensitivity: float = 0.075
var yaw: float = 0.0
var pitch: float = 0.0
var walk_speed: float = 4.1
var sprint_speed: float = 6.6
var crouch_speed: float = 2.25
var stamina: float = 100.0
var stamina_max: float = 100.0
var armor: float = 60.0
var body_health: Dictionary = {"head":35.0,"thorax":85.0,"stomach":70.0,"left_arm":60.0,"right_arm":60.0,"left_leg":65.0,"right_leg":65.0}
var max_health: Dictionary = {"head":35.0,"thorax":85.0,"stomach":70.0,"left_arm":60.0,"right_arm":60.0,"left_leg":65.0,"right_leg":65.0}
var dead: bool = false
var current_weapon_index: int = 0
var weapon_ids: Array[String] = ["m4","g17","m870"]
var weapon_data: Dictionary = {}
var ammo: int = 0
var reserve: int = 0
var fire_cooldown: float = 0.0
var reloading: bool = false
var reload_timer: float = 0.0
var aiming: bool = false
var recoil_pitch: float = 0.0
var recoil_yaw: float = 0.0
var weapon_kick: float = 0.0
var sway: Vector2 = Vector2.ZERO
var bob_time: float = 0.0
var interaction_target: Object = null
var interaction_text: String = ""
var shot_audio: AudioStreamPlayer
var camera: Camera3D
var neck: Node3D
var weapon_anchor: Node3D
var viewmodel: Node3D
var optic_mount: Node3D
var muzzle_light: OmniLight3D
var muzzle_mesh: MeshInstance3D
var capsule: CollisionShape3D
var crouched: bool = false

func setup(game_: Node) -> void:
    game = game_

func _ready() -> void:
    name = "Player"
    collision_layer = 1
    collision_mask = 1

    capsule = CollisionShape3D.new()
    var cap := CapsuleShape3D.new()
    cap.radius = 0.38
    cap.height = 1.75
    capsule.shape = cap
    capsule.position.y = 0.88
    add_child(capsule)

    neck = Node3D.new()
    neck.name = "Neck"
    neck.position = Vector3(0, 1.62, 0)
    add_child(neck)
    camera = Camera3D.new()
    camera.name = "Camera"
    camera.fov = 70.0
    camera.near = 0.04
    camera.far = 180.0
    neck.add_child(camera)
    weapon_anchor = Node3D.new()
    weapon_anchor.name = "WeaponAnchor"
    weapon_anchor.position = Vector3(0.33, -0.34, -0.72)
    camera.add_child(weapon_anchor)

    shot_audio = AudioStreamPlayer.new()
    add_child(shot_audio)
    _build_hands()
    _build_muzzle()
    _load_weapon(0)
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    _emit_hud()

func _material(color: Color, metallic: float = 0.0, roughness: float = 0.7) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.metallic = metallic
    m.roughness = roughness
    return m

func _build_hands() -> void:
    var glove := _material(Color("363a35"), 0.0, 0.88)
    var sleeve := _material(Color("52604e"), 0.0, 0.92)
    for side in [-1.0, 1.0]:
        var fore := MeshInstance3D.new()
        var arm_mesh := CylinderMesh.new()
        arm_mesh.top_radius = 0.07
        arm_mesh.bottom_radius = 0.09
        arm_mesh.height = 0.52
        fore.mesh = arm_mesh
        fore.material_override = sleeve
        fore.position = Vector3(0.20 * side, -0.26, -0.36)
        fore.rotation_degrees = Vector3(73, 0, 12 * side)
        weapon_anchor.add_child(fore)

        var hand := MeshInstance3D.new()
        var hand_mesh := SphereMesh.new()
        hand_mesh.radius = 0.095
        hand_mesh.height = 0.18
        hand.mesh = hand_mesh
        hand.material_override = glove
        hand.position = Vector3(0.15 * side, -0.12, -0.55 if side > 0.0 else -0.28)
        hand.scale = Vector3(1.0, 0.75, 1.15)
        weapon_anchor.add_child(hand)

func _build_muzzle() -> void:
    muzzle_light = OmniLight3D.new()
    muzzle_light.light_color = Color("ffb258")
    muzzle_light.light_energy = 0.0
    muzzle_light.omni_range = 5.0
    muzzle_light.position = Vector3(0, 0, -1.2)
    weapon_anchor.add_child(muzzle_light)

    muzzle_mesh = MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = 0.08
    mesh.height = 0.16
    muzzle_mesh.mesh = mesh
    var flash := _material(Color("ffc26b"), 0.0, 0.2)
    flash.emission_enabled = true
    flash.emission = Color("ff8d33")
    flash.emission_energy_multiplier = 5.0
    muzzle_mesh.material_override = flash
    muzzle_mesh.position = Vector3(0, 0, -1.2)
    muzzle_mesh.visible = false
    weapon_anchor.add_child(muzzle_mesh)

func _clear_viewmodel() -> void:
    if is_instance_valid(viewmodel):
        viewmodel.queue_free()
    viewmodel = null
    if is_instance_valid(optic_mount):
        optic_mount.queue_free()
    optic_mount = null

func _fallback_weapon(id: String) -> Node3D:
    var root := Node3D.new()
    root.name = "Fallback_%s" % id
    var steel := _material(Color("22282b"), 0.72, 0.36)
    var polymer := _material(Color("111618"), 0.05, 0.66)
    _fallback_box(root, Vector3(0,0,-0.16), Vector3(0.24,0.14,0.58), steel)
    if id == "g17":
        _fallback_box(root, Vector3(0,0.02,-0.20), Vector3(0.20,0.12,0.45), steel)
        _fallback_box(root, Vector3(0,-0.13,-0.04), Vector3(0.12,0.32,0.16), polymer)
        _fallback_cyl(root, Vector3(0,0.02,-0.48),0.022,0.32,steel)
    elif id == "m870":
        _fallback_box(root,Vector3(0,0,-0.15),Vector3(0.15,0.14,0.76),steel)
        _fallback_cyl(root,Vector3(0,0.03,-0.74),0.028,0.95,steel)
        _fallback_box(root,Vector3(0,-0.04,-0.49),Vector3(0.18,0.12,0.33),polymer)
        _fallback_box(root,Vector3(0,0.01,0.40),Vector3(0.18,0.16,0.42),polymer)
    else:
        _fallback_box(root,Vector3(0,0.01,-0.55),Vector3(0.19,0.12,0.40),steel)
        _fallback_cyl(root,Vector3(0,0.01,-0.96),0.025,0.62,steel)
        _fallback_box(root,Vector3(0,-0.16,-0.05),Vector3(0.13,0.33,0.16),polymer)
        _fallback_box(root,Vector3(0,0.02,0.38),Vector3(0.25,0.14,0.35),polymer)
    return root

func _fallback_box(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> void:
    var visual := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    visual.mesh = mesh
    visual.material_override = material
    visual.position = pos
    parent.add_child(visual)

func _fallback_cyl(parent: Node3D, pos: Vector3, radius: float, height: float, material: Material) -> void:
    var visual := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    visual.mesh = mesh
    visual.material_override = material
    visual.position = pos
    visual.rotation_degrees.x = 90.0
    parent.add_child(visual)

func _load_weapon(index: int) -> void:
    current_weapon_index = clampi(index, 0, weapon_ids.size() - 1)
    var id: String = weapon_ids[current_weapon_index]
    weapon_data = ItemDB.get_item(id)
    ammo = int(weapon_data.get("mag",30))
    reserve = int(weapon_data.get("reserve",90))
    reloading = false
    reload_timer = 0.0
    _clear_viewmodel()

    var asset := str(weapon_data.get("asset",""))
    if asset != "" and ResourceLoader.exists(asset):
        var packed := load(asset)
        if packed is PackedScene:
            viewmodel = (packed as PackedScene).instantiate()
    if viewmodel == null:
        viewmodel = _fallback_weapon(id)
    weapon_anchor.add_child(viewmodel)

    if id == "m4":
        viewmodel.scale = Vector3.ONE * 0.46
        viewmodel.rotation_degrees = Vector3(0,90,0)
        viewmodel.position = Vector3(0.03,-0.07,-0.10)
        _add_optic()
    elif id == "g17":
        viewmodel.scale = Vector3.ONE * 0.62
        viewmodel.rotation_degrees = Vector3(0,90,0)
        viewmodel.position = Vector3(0.02,-0.06,-0.12)
    else:
        viewmodel.scale = Vector3.ONE * 0.52
        viewmodel.rotation_degrees = Vector3(0,90,0)
        viewmodel.position = Vector3(0.02,-0.08,-0.05)

    if id == "m870" and ResourceLoader.exists("res://assets/audio/shotgun.wav"):
        shot_audio.stream = load("res://assets/audio/shotgun.wav")
    elif ResourceLoader.exists("res://assets/audio/rifle.wav"):
        shot_audio.stream = load("res://assets/audio/rifle.wav")
    toast_requested.emit("%s READY" % str(weapon_data.get("name",id)).to_upper())
    _emit_hud()

func _add_optic() -> void:
    optic_mount = Node3D.new()
    optic_mount.name = "Optic"
    optic_mount.position = Vector3(0,0.17,-0.23)
    weapon_anchor.add_child(optic_mount)
    var metal := _material(Color("11171a"),0.7,0.32)
    var glass := _material(Color("193842"),0.2,0.08)
    glass.emission_enabled = true
    glass.emission = Color("183c48")
    glass.emission_energy_multiplier = 0.4
    var tube := MeshInstance3D.new()
    var tube_mesh := CylinderMesh.new()
    tube_mesh.top_radius = 0.065;tube_mesh.bottom_radius = 0.065;tube_mesh.height = 0.22
    tube.mesh = tube_mesh;tube.material_override = metal;tube.rotation_degrees.x = 90.0;optic_mount.add_child(tube)
    var lens := MeshInstance3D.new()
    var lens_mesh := CylinderMesh.new()
    lens_mesh.top_radius = 0.057;lens_mesh.bottom_radius = 0.057;lens_mesh.height = 0.012
    lens.mesh = lens_mesh;lens.material_override = glass;lens.rotation_degrees.x = 90.0;lens.position.z = -0.115;optic_mount.add_child(lens)

func _unhandled_input(event: InputEvent) -> void:
    if dead:
        return
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        aiming = false
        return
    if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
        return
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        yaw -= event.relative.x * mouse_sensitivity
        pitch = clampf(pitch - event.relative.y * mouse_sensitivity,-72.0,68.0)
        sway = event.relative * 0.0018
    elif event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
            _try_fire()
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            aiming = event.pressed
    elif event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_R:
                _start_reload()
            KEY_F:
                _try_interact()
            KEY_H:
                if game and game.has_method("use_med"):
                    game.use_med()
            KEY_1:
                _load_weapon(0)
            KEY_2:
                _load_weapon(1)
            KEY_3:
                _load_weapon(2)
            KEY_TAB:
                if game and game.has_method("toggle_raid_inventory"):
                    game.toggle_raid_inventory()

func _process(delta: float) -> void:
    if dead:
        return
    fire_cooldown = maxf(0.0,fire_cooldown-delta)
    if reloading:
        reload_timer -= delta
        weapon_anchor.rotation_degrees.z = lerpf(weapon_anchor.rotation_degrees.z,11.0,delta*8.0)
        if reload_timer <= 0.0:
            _finish_reload()
    else:
        weapon_anchor.rotation_degrees.z = lerpf(weapon_anchor.rotation_degrees.z,0.0,delta*10.0)
    if bool(weapon_data.get("automatic",false)) and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        _try_fire()

    recoil_pitch = lerpf(recoil_pitch,0.0,delta*11.0)
    recoil_yaw = lerpf(recoil_yaw,0.0,delta*13.0)
    weapon_kick = lerpf(weapon_kick,0.0,delta*15.0)
    camera.fov = lerpf(camera.fov,48.0 if aiming else 70.0,delta*12.0)
    var target_pos := Vector3(0.0,-0.205,-0.51) if aiming else Vector3(0.33,-0.34,-0.72)
    target_pos.z += weapon_kick
    weapon_anchor.position = weapon_anchor.position.lerp(target_pos,clampf(delta*13.0,0.0,1.0))
    weapon_anchor.rotation_degrees.x = lerpf(weapon_anchor.rotation_degrees.x,-sway.y*18.0,delta*8.0)
    weapon_anchor.rotation_degrees.y = lerpf(weapon_anchor.rotation_degrees.y,-sway.x*15.0,delta*8.0)
    sway = sway.lerp(Vector2.ZERO,clampf(delta*8.0,0.0,1.0))
    _scan_interaction()
    _emit_hud()

func _physics_process(delta: float) -> void:
    if dead:
        return
    if not is_on_floor():
        velocity.y -= 18.0 * delta

    var input := Vector2.ZERO
    if Input.is_key_pressed(KEY_A): input.x -= 1.0
    if Input.is_key_pressed(KEY_D): input.x += 1.0
    if Input.is_key_pressed(KEY_W): input.y += 1.0
    if Input.is_key_pressed(KEY_S): input.y -= 1.0
    input = input.normalized()
    crouched = Input.is_key_pressed(KEY_CTRL)

    var leg_ratio := minf(float(body_health["left_leg"])/float(max_health["left_leg"]),float(body_health["right_leg"])/float(max_health["right_leg"]))
    var injury_move := lerpf(0.58,1.0,clampf(leg_ratio,0.0,1.0))
    var sprinting := Input.is_key_pressed(KEY_SHIFT) and input.y > 0.2 and stamina > 4.0 and not aiming and not crouched and leg_ratio > 0.18
    var speed := crouch_speed if crouched else (sprint_speed if sprinting else walk_speed)
    speed *= injury_move
    if sprinting:
        stamina = maxf(0.0,stamina-delta*17.0)
    else:
        stamina = minf(stamina_max,stamina+delta*11.0)

    var basis := Basis(Vector3.UP,deg_to_rad(yaw))
    var direction: Vector3 = (basis * Vector3(input.x,0,-input.y)).normalized()
    velocity.x = move_toward(velocity.x,direction.x*speed,delta*20.0)
    velocity.z = move_toward(velocity.z,direction.z*speed,delta*20.0)
    move_and_slide()
    rotation_degrees.y = yaw
    neck.rotation_degrees.x = pitch-recoil_pitch
    neck.rotation_degrees.y = recoil_yaw

    var moving := Vector2(velocity.x,velocity.z).length() > 0.4 and is_on_floor()
    if moving:
        bob_time += delta * (10.5 if sprinting else 7.2)
        var amp := 0.035 if sprinting else 0.022
        neck.position.y = lerpf(neck.position.y,(1.22 if crouched else 1.62)+sin(bob_time)*amp,delta*12.0)
        neck.position.x = lerpf(neck.position.x,cos(bob_time*0.5)*amp*0.65,delta*10.0)
    else:
        neck.position.y = lerpf(neck.position.y,1.22 if crouched else 1.62,delta*10.0)
        neck.position.x = lerpf(neck.position.x,0.0,delta*8.0)

func _try_fire() -> void:
    if dead or reloading or fire_cooldown > 0.0 or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
        return
    if ammo <= 0:
        toast_requested.emit("MAGAZINE EMPTY")
        return
    ammo -= 1
    fire_cooldown = 60.0 / float(weapon_data.get("rpm",600.0))
    weapon_kick = 0.22 if current_weapon_index == 2 else 0.12
    var arm_ratio := minf(float(body_health["left_arm"])/float(max_health["left_arm"]),float(body_health["right_arm"])/float(max_health["right_arm"]))
    var injury_recoil := lerpf(1.7,1.0,clampf(arm_ratio,0.0,1.0))
    recoil_pitch += (0.65 if aiming else 1.05) * injury_recoil
    recoil_yaw += randf_range(-0.22,0.22) * injury_recoil
    muzzle_mesh.visible = true
    muzzle_light.light_energy = 4.8
    get_tree().create_timer(0.045).timeout.connect(func() -> void:
        if is_instance_valid(muzzle_mesh):
            muzzle_mesh.visible = false
        if is_instance_valid(muzzle_light):
            muzzle_light.light_energy = 0.0
    )
    if shot_audio and shot_audio.stream:
        shot_audio.play()
    var pellets := int(weapon_data.get("pellets",1))
    for i in range(pellets):
        _fire_ray(i,pellets,arm_ratio)
    _emit_hud()

func _fire_ray(_i: int, pellets: int, arm_ratio: float) -> void:
    var spread := 0.0025 if aiming else 0.009
    spread *= lerpf(1.8,1.0,clampf(arm_ratio,0.0,1.0))
    if pellets > 1:
        spread = 0.035
    var origin := camera.global_position
    var direction := -camera.global_transform.basis.z
    direction = (direction + camera.global_transform.basis.x*randf_range(-spread,spread) + camera.global_transform.basis.y*randf_range(-spread,spread)).normalized()
    var query := PhysicsRayQueryParameters3D.create(origin,origin+direction*140.0)
    query.exclude = [get_rid()]
    query.collide_with_areas = true
    query.collide_with_bodies = true
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        return
    var collider: Object = hit.get("collider")
    if collider != null and collider.has_method("take_damage"):
        var hit_pos: Vector3 = hit.get("position",Vector3.ZERO)
        var collider_node := collider as Node3D
        var rel_y: float = hit_pos.y - collider_node.global_position.y if collider_node else 0.0
        var headshot: bool = rel_y > 1.7
        var damage := float(weapon_data.get("damage",30.0)) * (1.85 if headshot else 1.0)
        collider.call("take_damage",damage,hit_pos,headshot)
        if game and game.has_method("register_hit"):
            game.register_hit(headshot)
    elif game and game.has_method("spawn_impact"):
        game.spawn_impact(hit.get("position",Vector3.ZERO),hit.get("normal",Vector3.UP))

func _start_reload() -> void:
    if reloading or ammo >= int(weapon_data.get("mag",30)) or reserve <= 0:
        return
    reloading = true
    reload_timer = 2.15 if current_weapon_index == 2 else 1.55
    toast_requested.emit("RELOADING")

func _finish_reload() -> void:
    reloading = false
    var capacity := int(weapon_data.get("mag",30))
    var needed := capacity-ammo
    var take := mini(needed,reserve)
    ammo += take
    reserve -= take
    toast_requested.emit("MAGAZINE SEATED")

func _scan_interaction() -> void:
    interaction_target = null
    interaction_text = ""
    var origin := camera.global_position
    var direction := -camera.global_transform.basis.z
    var query := PhysicsRayQueryParameters3D.create(origin,origin+direction*3.2)
    query.exclude = [get_rid()]
    query.collide_with_areas = true
    query.collide_with_bodies = true
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty():
        var candidate: Object = hit.get("collider")
        if candidate != null and candidate.has_method("get_interaction_prompt"):
            interaction_target = candidate
            interaction_text = str(candidate.call("get_interaction_prompt"))
    interaction_prompt.emit(interaction_text)

func _try_interact() -> void:
    if interaction_target and is_instance_valid(interaction_target) and interaction_target.has_method("interact"):
        interaction_target.call("interact",self)

func apply_damage(amount: float, body_part: String = "thorax", armor_pen: float = 0.25) -> void:
    if dead:
        return
    var part := body_part if body_health.has(body_part) else "thorax"
    var damage := amount
    if (part == "thorax" or part == "stomach") and armor > 0.0:
        var absorbed := minf(armor,damage*(1.0-armor_pen)*0.78)
        armor -= absorbed
        damage -= absorbed*0.58
    body_health[part] = maxf(0.0,float(body_health[part])-damage)
    if (part == "head" or part == "thorax") and float(body_health[part]) <= 0.0:
        _die()
    var total := 0.0
    for value in body_health.values():
        total += float(value)
    if total <= 80.0:
        _die()
    _emit_hud()

func heal(amount: float) -> void:
    for key in body_health.keys():
        body_health[key] = minf(float(max_health[key]),float(body_health[key])+amount/7.0)
    _emit_hud()

func _die() -> void:
    if dead:
        return
    dead = true
    aiming = false
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    died.emit()

func _emit_hud() -> void:
    hud_state_changed.emit(get_hud_state())

func get_hud_state() -> Dictionary:
    var total := 0.0
    var maximum := 0.0
    for key in body_health.keys():
        total += float(body_health[key])
        maximum += float(max_health[key])
    return {
        "hp":int(round(total/maximum*100.0)),
        "armor":int(round(armor)),
        "stamina":int(round(stamina)),
        "ammo":ammo,
        "reserve":reserve,
        "weapon":str(weapon_data.get("name","")),
        "caliber":str(weapon_data.get("caliber","")),
        "body":body_health.duplicate(),
        "body_max":max_health.duplicate(),
        "reloading":reloading,
        "reload_progress":0.0 if not reloading else 1.0-clampf(reload_timer/(2.15 if current_weapon_index==2 else 1.55),0.0,1.0)
    }
