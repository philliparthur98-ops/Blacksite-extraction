class_name BlacksiteEnemy
extends CharacterBody3D

signal killed(enemy: BlacksiteEnemy, archetype: String)

var target: BlacksitePlayer
var archetype: String = "scav"
var health: float = 100.0
var armor: float = 0.0
var fire_cooldown: float = 1.0
var burst_remaining: int = 0
var burst_timer: float = 0.0
var state: String = "idle"
var last_seen: Vector3 = Vector3.ZERO
var investigate_timer: float = 0.0
var patrol_origin: Vector3 = Vector3.ZERO
var patrol_target: Vector3 = Vector3.ZERO
var phase: float = 0.0
var body_root: Node3D
var character_model: Node3D
var character_anim: AnimationPlayer
var rifle_root: Node3D
var muzzle: Node3D
var muzzle_light: OmniLight3D
var shot_audio: AudioStreamPlayer3D
var dead: bool = false
var uses_character_asset: bool = false
var current_anim: StringName = &""
var hit_reaction: float = 0.0
var fallback_legs: Array[Node3D] = []
var fallback_arms: Array[Node3D] = []

func configure(target_: BlacksitePlayer, archetype_: String) -> void:
    target = target_
    archetype = archetype_

func _ready() -> void:
    collision_layer = 1
    collision_mask = 1
    add_to_group("blacksite_enemy")
    patrol_origin = global_position
    patrol_target = patrol_origin+Vector3(randf_range(-5.0,5.0),0.0,randf_range(-5.0,5.0))
    match archetype:
        "guard":
            health = 125.0
            armor = 38.0
        "raider":
            health = 150.0
            armor = 62.0
        _:
            health = 95.0
            armor = 12.0

    var shape := CollisionShape3D.new()
    var cap := CapsuleShape3D.new()
    cap.radius = 0.42
    cap.height = 1.8
    shape.shape = cap
    shape.position.y = 0.9
    add_child(shape)

    _build_character()
    _build_weapon()

    shot_audio = AudioStreamPlayer3D.new()
    shot_audio.max_distance = 80.0
    shot_audio.unit_size = 8.0
    shot_audio.volume_db = -4.0
    add_child(shot_audio)
    if ResourceLoader.exists("res://assets/audio/rifle.wav"):
        shot_audio.stream = load("res://assets/audio/rifle.wav")

func _mat(color: Color, metal: float = 0.0, rough: float = 0.7) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = metal
    material.roughness = rough
    return material

func _find_animation_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node as AnimationPlayer
    for child in node.get_children():
        var result := _find_animation_player(child)
        if result != null:
            return result
    return null

func _find_animation(fragment: String) -> StringName:
    if character_anim == null:
        return &""
    var needle := fragment.to_lower()
    for anim_name in character_anim.get_animation_list():
        if str(anim_name).to_lower().contains(needle):
            return anim_name
    return &""

func _play_character_anim(fragment: String, speed: float = 1.0, blend: float = 0.18) -> void:
    if character_anim == null or dead:
        return
    var anim_name := _find_animation(fragment)
    if anim_name == &"":
        return
    if current_anim != anim_name or not character_anim.is_playing():
        current_anim = anim_name
        character_anim.play(anim_name,blend,speed)
    else:
        character_anim.speed_scale = speed

func _build_character() -> void:
    body_root = Node3D.new()
    body_root.name = "CharacterVisual"
    add_child(body_root)

    var asset := "res://assets/characters/GorgeholdScout.glb"
    if ResourceLoader.exists(asset):
        var packed = load(asset)
        if packed is PackedScene:
            character_model = (packed as PackedScene).instantiate()
            character_model.name = "RiggedOperator"
            character_model.rotation_degrees = Vector3(0,180,0)
            character_model.position = Vector3.ZERO
            character_model.scale = Vector3.ONE
            body_root.add_child(character_model)
            character_anim = _find_animation_player(character_model)
            uses_character_asset = true
            _configure_imported_meshes(character_model)
            _add_archetype_gear()
            _play_character_anim("idle",1.0,0.0)
            return

    uses_character_asset = false
    _build_fallback_operator()

func _configure_imported_meshes(node: Node) -> void:
    if node is MeshInstance3D:
        var mesh_node := node as MeshInstance3D
        mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
        mesh_node.visibility_range_end = 165.0
    for child in node.get_children():
        _configure_imported_meshes(child)

func _mesh_part(parent: Node3D, mesh: Mesh, pos: Vector3, material: Material, rot: Vector3 = Vector3.ZERO) -> Node3D:
    var node := Node3D.new()
    node.position = pos
    node.rotation_degrees = rot
    parent.add_child(node)
    var visual := MeshInstance3D.new()
    visual.mesh = mesh
    visual.material_override = material
    visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    node.add_child(visual)
    return node

func _capsule_part(parent: Node3D, pos: Vector3, radius: float, height: float, material: Material, rot: Vector3 = Vector3.ZERO) -> Node3D:
    var mesh := CapsuleMesh.new()
    mesh.radius = radius
    mesh.height = height
    return _mesh_part(parent,mesh,pos,material,rot)

func _box_part(parent: Node3D, pos: Vector3, size: Vector3, material: Material, rot: Vector3 = Vector3.ZERO) -> Node3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    return _mesh_part(parent,mesh,pos,material,rot)

func _sphere_part(parent: Node3D, pos: Vector3, radius: float, material: Material, scale_: Vector3 = Vector3.ONE) -> Node3D:
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius*2.0
    var node := _mesh_part(parent,mesh,pos,material)
    node.scale = scale_
    return node

func _add_archetype_gear() -> void:
    var gear_color := Color("262c29")
    if archetype == "guard": gear_color = Color("38433a")
    if archetype == "raider": gear_color = Color("181c1e")
    var gear := _mat(gear_color,0.05,0.83)
    _box_part(body_root,Vector3(0,1.35,-0.18),Vector3(0.46,0.46,0.12),gear)
    _box_part(body_root,Vector3(0,1.33,0.18),Vector3(0.40,0.42,0.15),gear)
    if archetype != "scav":
        var helmet := SphereMesh.new()
        helmet.radius = 0.235
        helmet.height = 0.30
        var helmet_node := _mesh_part(body_root,helmet,Vector3(0,1.82,0),gear)
        helmet_node.scale = Vector3(1.0,0.72,1.0)
    if archetype == "raider":
        _box_part(body_root,Vector3(0,1.38,0.29),Vector3(0.36,0.42,0.18),gear)

func _build_fallback_operator() -> void:
    var cloth := _mat(Color("3d4941"),0.0,0.92)
    var cloth_dark := _mat(Color("242b27"),0.0,0.94)
    var hard := _mat(Color("14191a"),0.22,0.58)
    var skin := _mat(Color("876552"),0.0,0.84)
    _capsule_part(body_root,Vector3(0,1.34,0),0.31,0.78,cloth)
    _sphere_part(body_root,Vector3(0,1.97,0),0.22,skin,Vector3(0.94,1.05,0.93))
    _sphere_part(body_root,Vector3(0,2.10,0),0.26,hard,Vector3(1.0,0.66,1.0))
    _box_part(body_root,Vector3(0,1.45,-0.27),Vector3(0.53,0.55,0.13),hard)
    _box_part(body_root,Vector3(0,1.41,0.28),Vector3(0.47,0.53,0.22),cloth_dark)
    fallback_legs = [
        _capsule_part(body_root,Vector3(-0.14,0.57,0),0.105,0.83,cloth_dark),
        _capsule_part(body_root,Vector3(0.14,0.57,0),0.105,0.83,cloth_dark)
    ]
    fallback_arms = [
        _capsule_part(body_root,Vector3(-0.38,1.37,-0.05),0.09,0.63,cloth,Vector3(15,0,-8)),
        _capsule_part(body_root,Vector3(0.38,1.37,-0.05),0.09,0.63,cloth,Vector3(15,0,8))
    ]
    for x_value in [-0.19,0.0,0.19]:
        var x: float = float(x_value)
        _box_part(body_root,Vector3(x,1.25,-0.36),Vector3(0.14,0.22,0.09),cloth_dark)

func _build_weapon() -> void:
    rifle_root = Node3D.new()
    rifle_root.name = "WeaponRig"
    rifle_root.position = Vector3(0.18,1.43,-0.34)
    rifle_root.rotation_degrees = Vector3(-7,180,-7)
    body_root.add_child(rifle_root)

    var asset := "res://assets/weapons/VXR_Carbine.glb"
    var rifle_model: Node3D = null
    if ResourceLoader.exists(asset):
        var packed = load(asset)
        if packed is PackedScene:
            rifle_model = (packed as PackedScene).instantiate()
    if rifle_model == null:
        rifle_model = Node3D.new()
        var steel := _mat(Color("22282b"),0.72,0.36)
        var polymer := _mat(Color("111618"),0.05,0.68)
        _box_part(rifle_model,Vector3(0,0,-0.18),Vector3(0.16,0.13,0.58),steel)
        _box_part(rifle_model,Vector3(0,0,0.32),Vector3(0.20,0.14,0.34),polymer)
    rifle_model.name = "Carbine"
    rifle_root.add_child(rifle_model)

    muzzle = Node3D.new()
    muzzle.name = "Muzzle"
    muzzle.position = Vector3(0,0,-0.78)
    rifle_root.add_child(muzzle)
    var flash := MeshInstance3D.new()
    var flash_mesh := QuadMesh.new()
    flash_mesh.size = Vector2(0.16,0.16)
    flash.mesh = flash_mesh
    var flash_mat := _mat(Color("ffc168"),0.0,0.12)
    flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    flash_mat.emission_enabled = true
    flash_mat.emission = Color("ff8b31")
    flash_mat.emission_energy_multiplier = 6.0
    flash.material_override = flash_mat
    muzzle.add_child(flash)
    muzzle.visible = false
    muzzle_light = OmniLight3D.new()
    muzzle_light.light_color = Color("ffae55")
    muzzle_light.light_energy = 0.0
    muzzle_light.omni_range = 4.8
    muzzle.add_child(muzzle_light)

func _physics_process(delta: float) -> void:
    if dead or target == null or not is_instance_valid(target):
        return
    phase += delta
    fire_cooldown = maxf(0.0,fire_cooldown-delta)
    burst_timer = maxf(0.0,burst_timer-delta)
    hit_reaction = maxf(0.0,hit_reaction-delta*4.0)
    var to_target := target.global_position-global_position
    var dist := Vector2(to_target.x,to_target.z).length()
    var visible := _has_los(dist)

    if visible:
        state = "combat"
        last_seen = target.global_position
        investigate_timer = 4.5
    elif investigate_timer > 0.0:
        state = "investigate"
        investigate_timer -= delta
    else:
        state = "patrol"

    match state:
        "combat": _combat(delta,dist,to_target)
        "investigate": _move_toward(last_seen,2.4,delta)
        _: _patrol(delta)

    if not is_on_floor():
        velocity.y -= 18.0*delta
    move_and_slide()
    _animate_character(delta)

func _has_los(dist: float) -> bool:
    if dist > 38.0:
        return false
    var from := global_position+Vector3(0,1.65,0)
    var to := target.global_position+Vector3(0,1.5,0)
    var query := PhysicsRayQueryParameters3D.create(from,to)
    query.exclude = [get_rid()]
    query.collide_with_areas = false
    query.collide_with_bodies = true
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        return true
    return hit.get("collider") == target

func _combat(delta: float, dist: float, to_target: Vector3) -> void:
    rotation.y = lerp_angle(rotation.y,atan2(-to_target.x,-to_target.z),delta*5.0)
    if dist > 11.0:
        _move_toward(target.global_position,2.0 if archetype == "scav" else 2.6,delta)
    elif dist < 6.0:
        _move_toward(global_position-(target.global_position-global_position),1.5,delta)
    else:
        velocity.x = move_toward(velocity.x,0.0,delta*6.0)
        velocity.z = move_toward(velocity.z,0.0,delta*6.0)

    if burst_remaining > 0 and burst_timer <= 0.0:
        _shoot_once(dist)
        burst_remaining -= 1
        burst_timer = 0.095 if archetype == "raider" else 0.16
    elif fire_cooldown <= 0.0 and dist < 31.0:
        burst_remaining = 3 if archetype == "raider" else (2 if archetype == "guard" else 1)
        fire_cooldown = randf_range(1.0,1.8) if archetype == "raider" else randf_range(1.4,2.5)

func _patrol(delta: float) -> void:
    if global_position.distance_to(patrol_target) < 1.0:
        patrol_target = patrol_origin+Vector3(randf_range(-6.0,6.0),0,randf_range(-6.0,6.0))
    _move_toward(patrol_target,1.35,delta)

func _move_toward(pos: Vector3, speed: float, delta: float) -> void:
    var direction := pos-global_position
    direction.y = 0.0
    if direction.length() < 0.1:
        return
    direction = direction.normalized()
    velocity.x = move_toward(velocity.x,direction.x*speed,delta*6.0)
    velocity.z = move_toward(velocity.z,direction.z*speed,delta*6.0)
    rotation.y = lerp_angle(rotation.y,atan2(-direction.x,-direction.z),delta*3.5)

func _shoot_once(dist: float) -> void:
    muzzle.visible = true
    muzzle.rotation_degrees.z = randf_range(0.0,360.0)
    muzzle_light.light_energy = 4.5
    rifle_root.rotation_degrees.x -= 2.2
    get_tree().create_timer(0.045).timeout.connect(func() -> void:
        if is_instance_valid(muzzle): muzzle.visible = false
        if is_instance_valid(muzzle_light): muzzle_light.light_energy = 0.0
    )
    if shot_audio and shot_audio.stream:
        shot_audio.pitch_scale = randf_range(0.96,1.03)
        shot_audio.play()
    var accuracy := clampf(0.76-dist*0.015,0.18,0.70)
    if archetype == "raider": accuracy += 0.10
    if randf() > accuracy:
        return
    var roll := randf()
    var part := "thorax"
    if roll < 0.06:
        part = "head"
    elif roll < 0.35:
        part = "left_arm" if randf() < 0.5 else "right_arm"
    elif roll < 0.58:
        part = "stomach"
    elif roll < 0.80:
        part = "left_leg" if randf() < 0.5 else "right_leg"
    var damage := randf_range(8.0,13.0) if archetype != "raider" else randf_range(10.0,16.0)
    target.apply_damage(damage,part,0.22 if archetype == "scav" else 0.38)

func _animate_character(delta: float) -> void:
    var speed := Vector2(velocity.x,velocity.z).length()
    rifle_root.rotation_degrees.x = lerpf(rifle_root.rotation_degrees.x,-7.0,clampf(delta*12.0,0.0,1.0))
    if uses_character_asset:
        if state == "combat" and speed < 0.5:
            if _find_animation("grasp") != &"":
                _play_character_anim("grasp",1.0,0.16)
            else:
                _play_character_anim("idle",1.0,0.16)
        elif speed > 2.15:
            _play_character_anim("run",clampf(speed/2.6,0.85,1.2),0.18)
        elif speed > 0.25:
            _play_character_anim("walk",clampf(speed/1.4,0.72,1.35),0.18)
        else:
            _play_character_anim("idle",1.0,0.20)
        body_root.rotation_degrees.x = lerpf(body_root.rotation_degrees.x,-hit_reaction*4.0,clampf(delta*15.0,0.0,1.0))
    else:
        var walk := sin(phase*8.0)*minf(speed/2.5,1.0)
        if fallback_legs.size() == 2:
            fallback_legs[0].rotation_degrees.x = walk*25.0
            fallback_legs[1].rotation_degrees.x = -walk*25.0
        if fallback_arms.size() == 2:
            fallback_arms[0].rotation_degrees.x = 14.0-walk*9.0
            fallback_arms[1].rotation_degrees.x = 14.0+walk*9.0
        body_root.position.y = sin(phase*6.0)*0.012*minf(speed,1.0)

func take_damage(amount: float, _hit_pos: Vector3, headshot: bool = false) -> void:
    if dead:
        return
    hit_reaction = 1.0
    var damage := amount
    if not headshot and armor > 0.0:
        var absorbed := minf(armor,damage*0.55)
        armor -= absorbed
        damage -= absorbed*0.5
    health -= damage
    if health <= 0.0:
        _die(headshot)

func _die(headshot: bool) -> void:
    if dead:
        return
    dead = true
    collision_layer = 0
    collision_mask = 0
    velocity = Vector3.ZERO
    if character_anim:
        character_anim.stop()
    var fall_side := -1.0 if randf() < 0.5 else 1.0
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tween.tween_property(body_root,"rotation_degrees:z",fall_side*88.0,0.46)
    tween.parallel().tween_property(body_root,"rotation_degrees:x",randf_range(-9.0,8.0),0.46)
    tween.parallel().tween_property(body_root,"position:y",-0.46,0.46)
    killed.emit(self,archetype)
    if headshot:
        var label := Label3D.new()
        label.text = "HEADSHOT"
        label.font_size = 22
        label.position = Vector3(0,2.5,0)
        label.modulate = Color("ffb66d")
        label.outline_size = 6
        label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        add_child(label)
