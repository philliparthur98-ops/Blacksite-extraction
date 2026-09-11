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
var reload_total: float = 0.0
var reload_stage: int = 0
var aiming: bool = false
var recoil_pitch: float = 0.0
var recoil_yaw: float = 0.0
var weapon_kick: float = 0.0
var camera_roll: float = 0.0
var sway: Vector2 = Vector2.ZERO
var bob_time: float = 0.0
var interaction_target: Object = null
var interaction_text: String = ""
var shot_audio: AudioStreamPlayer
var reload_audio: AudioStreamPlayer
var camera: Camera3D
var neck: Node3D
var weapon_anchor: Node3D
var arms_root: Node3D
var viewmodel: Node3D
var view_anim: AnimationPlayer
var muzzle_light: OmniLight3D
var muzzle_mesh: MeshInstance3D
var capsule: CollisionShape3D
var crouched: bool = false
var sprinting: bool = false
var hip_position := Vector3(0.30,-0.30,-0.58)
var ads_position := Vector3(0.0,-0.185,-0.39)
var sprint_position := Vector3(0.34,-0.48,-0.46)
var casing_material: StandardMaterial3D

func setup(game_: Node) -> void:
    game = game_

func _ready() -> void:
    name = "Player"
    collision_layer = 1
    collision_mask = 1
    set_process_input(true)

    capsule = CollisionShape3D.new()
    var cap := CapsuleShape3D.new()
    cap.radius = 0.38
    cap.height = 1.75
    capsule.shape = cap
    capsule.position.y = 0.88
    add_child(capsule)

    neck = Node3D.new()
    neck.name = "Neck"
    neck.position = Vector3(0,1.62,0)
    add_child(neck)

    camera = Camera3D.new()
    camera.name = "Camera"
    camera.fov = 70.0
    camera.near = 0.035
    camera.far = 220.0
    camera.keep_aspect = Camera3D.KEEP_HEIGHT
    neck.add_child(camera)

    weapon_anchor = Node3D.new()
    weapon_anchor.name = "ViewmodelRig"
    weapon_anchor.position = hip_position
    camera.add_child(weapon_anchor)

    shot_audio = AudioStreamPlayer.new()
    shot_audio.volume_db = -1.5
    add_child(shot_audio)
    reload_audio = AudioStreamPlayer.new()
    reload_audio.volume_db = -7.0
    add_child(reload_audio)
    if ResourceLoader.exists("res://assets/audio/reload.wav"):
        reload_audio.stream = load("res://assets/audio/reload.wav")

    casing_material = _material(Color("b89448"),0.72,0.3)
    _build_first_person_arms()
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

func _capsule_visual(parent: Node3D, name_: String, pos: Vector3, radius: float, height: float, material: Material, rot: Vector3) -> Node3D:
    var pivot := Node3D.new()
    pivot.name = name_
    pivot.position = pos
    pivot.rotation_degrees = rot
    parent.add_child(pivot)
    var mesh_node := MeshInstance3D.new()
    var mesh := CapsuleMesh.new()
    mesh.radius = radius
    mesh.height = height
    mesh_node.mesh = mesh
    mesh_node.material_override = material
    mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    pivot.add_child(mesh_node)
    return pivot

func _box_visual(parent: Node3D, name_: String, pos: Vector3, size: Vector3, material: Material, rot: Vector3 = Vector3.ZERO) -> Node3D:
    var pivot := Node3D.new()
    pivot.name = name_
    pivot.position = pos
    pivot.rotation_degrees = rot
    parent.add_child(pivot)
    var mesh_node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_node.mesh = mesh
    mesh_node.material_override = material
    mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    pivot.add_child(mesh_node)
    return pivot

func _build_first_person_arms() -> void:
    arms_root = Node3D.new()
    arms_root.name = "FirstPersonArms"
    weapon_anchor.add_child(arms_root)
    var sleeve := _material(Color("354238"),0.0,0.94)
    var glove := _material(Color("171b19"),0.02,0.84)
    var pad := _material(Color("242b27"),0.08,0.66)

    _capsule_visual(arms_root,"LeftUpper",Vector3(-0.25,-0.16,0.10),0.082,0.43,sleeve,Vector3(66,-7,-10))
    _capsule_visual(arms_root,"LeftFore",Vector3(-0.16,-0.16,-0.18),0.071,0.43,sleeve,Vector3(78,-4,-5))
    _capsule_visual(arms_root,"RightUpper",Vector3(0.26,-0.17,0.12),0.084,0.44,sleeve,Vector3(68,8,10))
    _capsule_visual(arms_root,"RightFore",Vector3(0.18,-0.16,-0.18),0.071,0.42,sleeve,Vector3(79,5,5))
    _box_visual(arms_root,"LeftPad",Vector3(-0.23,-0.12,-0.03),Vector3(0.15,0.10,0.19),pad,Vector3(8,-6,-8))
    _box_visual(arms_root,"RightPad",Vector3(0.23,-0.12,-0.02),Vector3(0.15,0.10,0.19),pad,Vector3(8,6,8))
    _capsule_visual(arms_root,"LeftGlove",Vector3(-0.10,-0.12,-0.38),0.075,0.20,glove,Vector3(85,4,-8))
    _capsule_visual(arms_root,"RightGlove",Vector3(0.11,-0.13,-0.31),0.076,0.20,glove,Vector3(86,-4,8))
    for side in [-1.0,1.0]:
        for finger in range(3):
            var x := (0.10*side)+(float(finger)-1.0)*0.021
            var z := -0.47 if side < 0.0 else -0.40
            _capsule_visual(arms_root,"Finger_%s_%d" % ["L" if side < 0.0 else "R",finger],Vector3(x,-0.105,z),0.012,0.095,glove,Vector3(88,0,0))

func _build_muzzle() -> void:
    muzzle_light = OmniLight3D.new()
    muzzle_light.light_color = Color("ffb258")
    muzzle_light.light_energy = 0.0
    muzzle_light.omni_range = 6.5
    muzzle_light.position = Vector3(0,0,-0.72)
    weapon_anchor.add_child(muzzle_light)

    muzzle_mesh = MeshInstance3D.new()
    var mesh := QuadMesh.new()
    mesh.size = Vector2(0.18,0.18)
    muzzle_mesh.mesh = mesh
    var flash := _material(Color("ffc26b"),0.0,0.12)
    flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    flash.emission_enabled = true
    flash.emission = Color("ff8d33")
    flash.emission_energy_multiplier = 7.0
    muzzle_mesh.material_override = flash
    muzzle_mesh.position = Vector3(0,0,-0.76)
    muzzle_mesh.visible = false
    weapon_anchor.add_child(muzzle_mesh)

func _clear_viewmodel() -> void:
    if is_instance_valid(viewmodel):
        viewmodel.queue_free()
    viewmodel = null
    view_anim = null

func _fallback_weapon(id: String) -> Node3D:
    var root := Node3D.new()
    root.name = "Fallback_%s" % id
    var steel := _material(Color("22282b"),0.72,0.36)
    var polymer := _material(Color("111618"),0.05,0.66)
    _box_visual(root,"receiver",Vector3(0,0,-0.16),Vector3(0.24,0.14,0.58),steel)
    if id == "g17":
        _box_visual(root,"slide",Vector3(0,0.02,-0.20),Vector3(0.20,0.12,0.45),steel)
        _box_visual(root,"grip",Vector3(0,-0.13,-0.04),Vector3(0.12,0.32,0.16),polymer)
    elif id == "m870":
        _box_visual(root,"body",Vector3(0,0,-0.15),Vector3(0.15,0.14,0.76),steel)
        _box_visual(root,"stock",Vector3(0,0.01,0.40),Vector3(0.18,0.16,0.42),polymer)
    else:
        _box_visual(root,"handguard",Vector3(0,0.01,-0.55),Vector3(0.19,0.12,0.40),steel)
        _box_visual(root,"stock",Vector3(0,0.02,0.38),Vector3(0.25,0.14,0.35),polymer)
    return root

func _find_animation_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node as AnimationPlayer
    for child in node.get_children():
        var found := _find_animation_player(child)
        if found != null:
            return found
    return null

func _play_view_animation(fragment: String, speed: float = 1.0) -> void:
    if view_anim == null:
        return
    var needle := fragment.to_lower()
    for anim_name in view_anim.get_animation_list():
        if str(anim_name).to_lower().contains(needle):
            view_anim.speed_scale = speed
            view_anim.play(anim_name,0.06)
            return

func _load_weapon(index: int) -> void:
    current_weapon_index = clampi(index,0,weapon_ids.size()-1)
    var id: String = weapon_ids[current_weapon_index]
    weapon_data = ItemDB.get_item(id)
    ammo = int(weapon_data.get("mag",30))
    reserve = int(weapon_data.get("reserve",90))
    reloading = false
    reload_timer = 0.0
    reload_stage = 0
    _clear_viewmodel()

    var asset := str(weapon_data.get("asset",""))
    if asset != "" and ResourceLoader.exists(asset):
        var packed = load(asset)
        if packed is PackedScene:
            viewmodel = (packed as PackedScene).instantiate()
    if viewmodel == null:
        viewmodel = _fallback_weapon(id)
    weapon_anchor.add_child(viewmodel)
    view_anim = _find_animation_player(viewmodel)
    viewmodel.rotation_degrees = Vector3(0,180,0)
    viewmodel.scale = Vector3.ONE

    if id == "m4":
        viewmodel.position = Vector3(0.0,-0.05,-0.06)
        hip_position = Vector3(0.29,-0.29,-0.54)
        ads_position = Vector3(0.0,-0.205,-0.33)
        sprint_position = Vector3(0.35,-0.46,-0.42)
        muzzle_mesh.position.z = -0.77
        muzzle_light.position.z = -0.77
    elif id == "g17":
        viewmodel.position = Vector3(0.0,-0.06,-0.03)
        hip_position = Vector3(0.22,-0.27,-0.40)
        ads_position = Vector3(0.0,-0.205,-0.27)
        sprint_position = Vector3(0.29,-0.43,-0.31)
        muzzle_mesh.position.z = -0.45
        muzzle_light.position.z = -0.45
    else:
        viewmodel.position = Vector3(0.0,-0.07,-0.05)
        hip_position = Vector3(0.30,-0.31,-0.61)
        ads_position = Vector3(0.0,-0.215,-0.39)
        sprint_position = Vector3(0.36,-0.47,-0.50)
        muzzle_mesh.position.z = -0.87
        muzzle_light.position.z = -0.87

    weapon_anchor.position = hip_position
    arms_root.visible = true
    if id == "m870" and ResourceLoader.exists("res://assets/audio/shotgun.wav"):
        shot_audio.stream = load("res://assets/audio/shotgun.wav")
    elif id == "g17" and ResourceLoader.exists("res://assets/audio/pistol.wav"):
        shot_audio.stream = load("res://assets/audio/pistol.wav")
    elif ResourceLoader.exists("res://assets/audio/rifle.wav"):
        shot_audio.stream = load("res://assets/audio/rifle.wav")
    toast_requested.emit("%s READY" % str(weapon_data.get("name",id)).to_upper())
    _emit_hud()

func _input(event: InputEvent) -> void:
    if dead:
        return
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_ESCAPE:
                Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
                aiming = false
                get_viewport().set_input_as_handled()
                return
            KEY_F11:
                var mode := DisplayServer.window_get_mode()
                DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
                get_viewport().set_input_as_handled()
                return
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
        return

    if event is InputEventMouseButton:
        if event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
            Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
            get_viewport().set_input_as_handled()
            return
        if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
            return
        if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
            _try_fire()
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            aiming = event.pressed
        return

    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        var motion: Vector2 = event.screen_relative
        yaw -= motion.x*mouse_sensitivity
        pitch = clampf(pitch-motion.y*mouse_sensitivity,-72.0,68.0)
        sway = motion*0.00145
        get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
    if dead:
        return
    fire_cooldown = maxf(0.0,fire_cooldown-delta)
    if reloading:
        reload_timer -= delta
        if reload_stage == 0 and reload_timer <= reload_total*0.48:
            reload_stage = 1
            _play_view_animation("magazine-close",1.15)
        if reload_timer <= 0.0:
            _finish_reload()
    if bool(weapon_data.get("automatic",false)) and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        _try_fire()

    recoil_pitch = lerpf(recoil_pitch,0.0,delta*11.0)
    recoil_yaw = lerpf(recoil_yaw,0.0,delta*13.0)
    weapon_kick = lerpf(weapon_kick,0.0,delta*16.0)
    camera_roll = lerpf(camera_roll,0.0,delta*13.0)
    camera.fov = lerpf(camera.fov,48.0 if aiming else 70.0,clampf(delta*11.0,0.0,1.0))
    camera.rotation_degrees.z = camera_roll

    var target_pos := hip_position
    if sprinting:
        target_pos = sprint_position
    elif aiming:
        target_pos = ads_position
    target_pos.z += weapon_kick
    weapon_anchor.position = weapon_anchor.position.lerp(target_pos,clampf(delta*13.0,0.0,1.0))

    var target_rot := Vector3.ZERO
    if sprinting:
        target_rot = Vector3(-18,-12,12)
    elif reloading:
        var progress := 1.0-clampf(reload_timer/maxf(reload_total,0.01),0.0,1.0)
        target_rot = Vector3(10.0+sin(progress*PI)*13.0,8.0,-18.0)
    else:
        target_rot = Vector3(-sway.y*16.0,-sway.x*13.0,0.0)
    weapon_anchor.rotation_degrees = weapon_anchor.rotation_degrees.lerp(target_rot,clampf(delta*9.0,0.0,1.0))
    sway = sway.lerp(Vector2.ZERO,clampf(delta*8.0,0.0,1.0))
    _scan_interaction()
    _emit_hud()

func _physics_process(delta: float) -> void:
    if dead:
        return
    if not is_on_floor():
        velocity.y -= 18.0*delta

    var input := Vector2.ZERO
    if Input.is_key_pressed(KEY_A): input.x -= 1.0
    if Input.is_key_pressed(KEY_D): input.x += 1.0
    if Input.is_key_pressed(KEY_W): input.y += 1.0
    if Input.is_key_pressed(KEY_S): input.y -= 1.0
    input = input.normalized()
    crouched = Input.is_key_pressed(KEY_CTRL)

    var leg_ratio := minf(float(body_health["left_leg"])/float(max_health["left_leg"]),float(body_health["right_leg"])/float(max_health["right_leg"]))
    var injury_move := lerpf(0.58,1.0,clampf(leg_ratio,0.0,1.0))
    sprinting = Input.is_key_pressed(KEY_SHIFT) and input.y > 0.2 and stamina > 4.0 and not aiming and not crouched and leg_ratio > 0.18
    var speed := crouch_speed if crouched else (sprint_speed if sprinting else walk_speed)
    speed *= injury_move
    if sprinting:
        stamina = maxf(0.0,stamina-delta*17.0)
    else:
        stamina = minf(stamina_max,stamina+delta*11.0)

    var basis := Basis(Vector3.UP,deg_to_rad(yaw))
    var direction: Vector3 = (basis*Vector3(input.x,0,-input.y)).normalized()
    velocity.x = move_toward(velocity.x,direction.x*speed,delta*20.0)
    velocity.z = move_toward(velocity.z,direction.z*speed,delta*20.0)
    move_and_slide()
    rotation_degrees.y = yaw
    neck.rotation_degrees.x = pitch-recoil_pitch
    neck.rotation_degrees.y = recoil_yaw

    var moving := Vector2(velocity.x,velocity.z).length() > 0.4 and is_on_floor()
    if moving:
        bob_time += delta*(10.5 if sprinting else 7.2)
        var amp := 0.030 if sprinting else 0.017
        neck.position.y = lerpf(neck.position.y,(1.22 if crouched else 1.62)+sin(bob_time)*amp,delta*12.0)
        neck.position.x = lerpf(neck.position.x,cos(bob_time*0.5)*amp*0.55,delta*10.0)
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
    fire_cooldown = 60.0/float(weapon_data.get("rpm",600.0))
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

func _eject_casing() -> void:
    if get_tree().current_scene == null:
        return
    var casing := RigidBody3D.new()
    casing.name = "SpentCasing"
    casing.mass = 0.012
    casing.gravity_scale = 1.0
    get_tree().current_scene.add_child(casing)
    casing.global_position = camera.global_position+camera.global_transform.basis*Vector3(0.18,-0.12,-0.36)
    var mesh_node := MeshInstance3D.new()
    var shell := CylinderMesh.new()
    shell.top_radius = 0.006 if current_weapon_index != 2 else 0.010
    shell.bottom_radius = shell.top_radius
    shell.height = 0.028 if current_weapon_index != 2 else 0.055
    mesh_node.mesh = shell
    mesh_node.material_override = casing_material
    casing.add_child(mesh_node)
    casing.linear_velocity = camera.global_transform.basis*Vector3(randf_range(1.3,2.0),randf_range(0.8,1.4),randf_range(0.0,0.4))
    casing.angular_velocity = Vector3(randf_range(-12,12),randf_range(-12,12),randf_range(-12,12))
    get_tree().create_timer(2.2).timeout.connect(func() -> void:
        if is_instance_valid(casing): casing.queue_free()
    )

func _fire_ray(_i: int, pellets: int, arm_ratio: float) -> void:
    var spread := 0.0022 if aiming else 0.008
    spread *= lerpf(1.8,1.0,clampf(arm_ratio,0.0,1.0))
    if pellets > 1:
        spread = 0.032
    var origin := camera.global_position
    var direction := -camera.global_transform.basis.z
    direction = (direction+camera.global_transform.basis.x*randf_range(-spread,spread)+camera.global_transform.basis.y*randf_range(-spread,spread)).normalized()
    var query := PhysicsRayQueryParameters3D.create(origin,origin+direction*150.0)
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
        var rel_y: float = hit_pos.y-collider_node.global_position.y if collider_node else 0.0
        var headshot: bool = rel_y > 1.68
        var damage := float(weapon_data.get("damage",30.0))*(1.9 if headshot else 1.0)
        collider.call("take_damage",damage,hit_pos,headshot)
        if game and game.has_method("register_hit"):
            game.register_hit(headshot)
    elif game and game.has_method("spawn_impact"):
        game.spawn_impact(hit.get("position",Vector3.ZERO),hit.get("normal",Vector3.UP))

func _start_reload() -> void:
    if reloading or ammo >= int(weapon_data.get("mag",30)) or reserve <= 0:
        return
    reloading = true
    reload_total = 2.35 if current_weapon_index == 2 else (1.65 if current_weapon_index == 1 else 1.90)
    reload_timer = reload_total
    reload_stage = 0
    _play_view_animation("magazine-open",1.15)
    if reload_audio and reload_audio.stream:
        reload_audio.play()
    toast_requested.emit("RELOADING")

func _finish_reload() -> void:
    reloading = false
    reload_stage = 0
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
        "reload_progress":0.0 if not reloading else 1.0-clampf(reload_timer/maxf(reload_total,0.01),0.0,1.0)
    }
