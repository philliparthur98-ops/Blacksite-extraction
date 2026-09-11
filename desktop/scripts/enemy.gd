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
var muzzle: Node3D
var muzzle_light: OmniLight3D
var shot_audio: AudioStreamPlayer3D
var legs: Array[Node3D] = []
var arms: Array[Node3D] = []
var dead: bool = false

func configure(target_: BlacksitePlayer, archetype_: String) -> void:
    target = target_
    archetype = archetype_

func _ready() -> void:
    collision_layer = 1
    collision_mask = 1
    patrol_origin = global_position
    patrol_target = patrol_origin + Vector3(randf_range(-5.0, 5.0), 0.0, randf_range(-5.0, 5.0))
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
    shot_audio = AudioStreamPlayer3D.new()
    shot_audio.max_distance = 75.0
    shot_audio.unit_size = 8.0
    add_child(shot_audio)
    if ResourceLoader.exists("res://assets/audio/rifle.wav"):
        shot_audio.stream = load("res://assets/audio/rifle.wav")

func _mat(color: Color, metal: float = 0.0, rough: float = 0.7) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = metal
    material.roughness = rough
    return material

func _mesh_part(parent: Node3D, part_name: String, mesh: Mesh, pos: Vector3, material: Material, rot: Vector3 = Vector3.ZERO) -> Node3D:
    var node := Node3D.new()
    node.name = part_name
    node.position = pos
    node.rotation_degrees = rot
    parent.add_child(node)
    var visual := MeshInstance3D.new()
    visual.mesh = mesh
    visual.material_override = material
    visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    node.add_child(visual)
    return node

func _box(parent: Node3D, part_name: String, pos: Vector3, size: Vector3, material: Material, rot: Vector3 = Vector3.ZERO) -> Node3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    return _mesh_part(parent, part_name, mesh, pos, material, rot)

func _cyl(parent: Node3D, part_name: String, pos: Vector3, radius: float, height: float, material: Material, rot: Vector3 = Vector3.ZERO) -> Node3D:
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    return _mesh_part(parent, part_name, mesh, pos, material, rot)

func _sphere(parent: Node3D, part_name: String, pos: Vector3, radius: float, material: Material, scale_: Vector3 = Vector3.ONE) -> Node3D:
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    var node := _mesh_part(parent, part_name, mesh, pos, material)
    node.scale = scale_
    return node

func _build_character() -> void:
    body_root = Node3D.new()
    body_root.name = "Visual"
    add_child(body_root)

    var cloth_color := Color("30393a") if archetype == "raider" else Color("4a5346")
    var cloth := _mat(cloth_color, 0.0, 0.9)
    var cloth_dark := _mat(Color("2c332e"), 0.0, 0.92)
    var hard := _mat(Color("171d1f"), 0.25, 0.55)
    var skin := _mat(Color("775847"), 0.0, 0.82)
    var metal := _mat(Color("282f32"), 0.75, 0.38)
    var lens := _mat(Color("203c43"), 0.22, 0.12)
    lens.emission_enabled = true
    lens.emission = Color("153c45")
    lens.emission_energy_multiplier = 0.25

    _cyl(body_root, "torso", Vector3(0, 1.35, 0), 0.32, 0.78, cloth)
    _sphere(body_root, "head", Vector3(0, 2.02, 0), 0.23, skin, Vector3(1.0, 0.92, 0.94))
    _sphere(body_root, "helmet", Vector3(0, 2.14, 0), 0.275, hard, Vector3(1.0, 0.65, 1.0))
    _box(body_root, "goggles", Vector3(0, 2.05, -0.225), Vector3(0.35, 0.095, 0.055), lens)
    _box(body_root, "facewrap", Vector3(0, 1.91, -0.19), Vector3(0.28, 0.16, 0.07), cloth_dark)

    var leg_l := _cyl(body_root, "leg_l", Vector3(-0.14, 0.55, 0), 0.11, 0.85, cloth_dark)
    var leg_r := _cyl(body_root, "leg_r", Vector3(0.14, 0.55, 0), 0.11, 0.85, cloth_dark)
    legs = [leg_l, leg_r]
    var arm_l := _cyl(body_root, "arm_l", Vector3(-0.39, 1.38, -0.04), 0.09, 0.65, cloth, Vector3(14, 0, -8))
    var arm_r := _cyl(body_root, "arm_r", Vector3(0.39, 1.38, -0.04), 0.09, 0.65, cloth, Vector3(14, 0, 8))
    arms = [arm_l, arm_r]

    _box(body_root, "knee_l", Vector3(-0.14, 0.48, -0.09), Vector3(0.18, 0.17, 0.10), hard)
    _box(body_root, "knee_r", Vector3(0.14, 0.48, -0.09), Vector3(0.18, 0.17, 0.10), hard)
    _box(body_root, "front_plate", Vector3(0, 1.46, -0.27), Vector3(0.57, 0.59, 0.14), hard)
    _box(body_root, "rear_plate", Vector3(0, 1.46, 0.23), Vector3(0.55, 0.59, 0.17), cloth_dark)
    for x in [-0.21, 0.0, 0.21]:
        _box(body_root, "mag", Vector3(x, 1.28, -0.37), Vector3(0.15, 0.24, 0.10), cloth_dark)
    _box(body_root, "pack", Vector3(0, 1.39, 0.34), Vector3(0.48, 0.60, 0.25), cloth_dark)

    if archetype == "raider":
        _box(body_root, "shoulder_l", Vector3(-0.42, 1.58, 0), Vector3(0.23, 0.17, 0.23), hard)
        _box(body_root, "shoulder_r", Vector3(0.42, 1.58, 0), Vector3(0.23, 0.17, 0.23), hard)
        _box(body_root, "neck_guard", Vector3(0, 1.82, 0.04), Vector3(0.38, 0.18, 0.21), hard)

    var rifle := Node3D.new()
    rifle.name = "Rifle"
    rifle.position = Vector3(0.28, 1.42, -0.44)
    rifle.rotation_degrees = Vector3(-4, 0, -8)
    body_root.add_child(rifle)
    _box(rifle, "receiver", Vector3.ZERO, Vector3(0.62, 0.10, 0.11), metal)
    _cyl(rifle, "barrel", Vector3(0, -0.01, -0.48), 0.025, 0.65, metal, Vector3(90, 0, 0))
    _box(rifle, "magazine", Vector3(0, -0.15, -0.05), Vector3(0.12, 0.27, 0.10), hard, Vector3(8, 0, 0))
    _box(rifle, "stock", Vector3(0, 0.01, 0.43), Vector3(0.19, 0.13, 0.32), hard)

    muzzle = _sphere(rifle, "Muzzle", Vector3(0, -0.01, -0.81), 0.055, _mat(Color("ffb866"), 0.0, 0.2))
    var muzzle_mesh := muzzle.get_child(0) as MeshInstance3D
    if muzzle_mesh:
        var emission := muzzle_mesh.material_override as StandardMaterial3D
        if emission:
            emission.emission_enabled = true
            emission.emission = Color("ff8d31")
            emission.emission_energy_multiplier = 4.0
    muzzle.visible = false
    muzzle_light = OmniLight3D.new()
    muzzle_light.position = Vector3(0, -0.01, -0.81)
    muzzle_light.light_color = Color("ffad55")
    muzzle_light.light_energy = 0.0
    muzzle_light.omni_range = 4.0
    rifle.add_child(muzzle_light)

func _physics_process(delta: float) -> void:
    if dead or target == null or not is_instance_valid(target):
        return
    phase += delta
    fire_cooldown = maxf(0.0, fire_cooldown - delta)
    burst_timer = maxf(0.0, burst_timer - delta)
    var to_target := target.global_position - global_position
    var dist := Vector2(to_target.x, to_target.z).length()
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
        "combat":
            _combat(delta, dist, to_target)
        "investigate":
            _move_toward(last_seen, 2.4, delta)
        _:
            _patrol(delta)

    if not is_on_floor():
        velocity.y -= 18.0 * delta
    move_and_slide()
    _animate_body()

func _has_los(dist: float) -> bool:
    if dist > 38.0:
        return false
    var from := global_position + Vector3(0, 1.65, 0)
    var to := target.global_position + Vector3(0, 1.5, 0)
    var query := PhysicsRayQueryParameters3D.create(from, to)
    query.exclude = [get_rid()]
    query.collide_with_areas = false
    query.collide_with_bodies = true
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        return true
    return hit.get("collider") == target

func _combat(delta: float, dist: float, to_target: Vector3) -> void:
    rotation.y = lerp_angle(rotation.y, atan2(-to_target.x, -to_target.z), delta * 5.0)
    if dist > 11.0:
        _move_toward(target.global_position, 2.0 if archetype == "scav" else 2.6, delta)
    elif dist < 6.0:
        _move_toward(global_position - (target.global_position - global_position), 1.5, delta)
    else:
        velocity.x = move_toward(velocity.x, 0.0, delta * 6.0)
        velocity.z = move_toward(velocity.z, 0.0, delta * 6.0)

    if burst_remaining > 0 and burst_timer <= 0.0:
        _shoot_once(dist)
        burst_remaining -= 1
        burst_timer = 0.095 if archetype == "raider" else 0.16
    elif fire_cooldown <= 0.0 and dist < 31.0:
        burst_remaining = 3 if archetype == "raider" else (2 if archetype == "guard" else 1)
        fire_cooldown = randf_range(1.0, 1.8) if archetype == "raider" else randf_range(1.4, 2.5)

func _patrol(delta: float) -> void:
    if global_position.distance_to(patrol_target) < 1.0:
        patrol_target = patrol_origin + Vector3(randf_range(-6.0, 6.0), 0, randf_range(-6.0, 6.0))
    _move_toward(patrol_target, 1.35, delta)

func _move_toward(pos: Vector3, speed: float, delta: float) -> void:
    var direction := pos - global_position
    direction.y = 0.0
    if direction.length() < 0.1:
        return
    direction = direction.normalized()
    velocity.x = move_toward(velocity.x, direction.x * speed, delta * 6.0)
    velocity.z = move_toward(velocity.z, direction.z * speed, delta * 6.0)
    rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), delta * 3.5)

func _shoot_once(dist: float) -> void:
    muzzle.visible = true
    muzzle_light.light_energy = 3.7
    get_tree().create_timer(0.045).timeout.connect(func() -> void:
        if is_instance_valid(muzzle):
            muzzle.visible = false
        if is_instance_valid(muzzle_light):
            muzzle_light.light_energy = 0.0
    )
    if shot_audio and shot_audio.stream:
        shot_audio.play()
    var accuracy := clampf(0.76 - dist * 0.015, 0.18, 0.70)
    if archetype == "raider":
        accuracy += 0.10
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
    var damage := randf_range(8.0, 13.0) if archetype != "raider" else randf_range(10.0, 16.0)
    target.apply_damage(damage, part, 0.22 if archetype == "scav" else 0.38)

func _animate_body() -> void:
    var speed := Vector2(velocity.x, velocity.z).length()
    var walk := sin(phase * 8.0) * minf(speed / 2.5, 1.0)
    if legs.size() == 2:
        legs[0].rotation_degrees.x = walk * 25.0
        legs[1].rotation_degrees.x = -walk * 25.0
    if arms.size() == 2:
        arms[0].rotation_degrees.x = 14.0 - walk * 9.0
        arms[1].rotation_degrees.x = 14.0 + walk * 9.0
    body_root.position.y = sin(phase * 6.0) * 0.012 * minf(speed, 1.0)

func take_damage(amount: float, _hit_pos: Vector3, headshot: bool = false) -> void:
    if dead:
        return
    var damage := amount
    if not headshot and armor > 0.0:
        var absorbed := minf(armor, damage * 0.55)
        armor -= absorbed
        damage -= absorbed * 0.5
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
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tween.tween_property(body_root, "rotation_degrees:z", 87.0, 0.42)
    tween.parallel().tween_property(body_root, "position:y", -0.42, 0.42)
    killed.emit(self, archetype)
    if headshot:
        var label := Label3D.new()
        label.text = "HEADSHOT"
        label.font_size = 22
        label.position = Vector3(0, 2.5, 0)
        label.modulate = Color("ffb66d")
        label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        add_child(label)
