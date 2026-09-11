class_name BlacksiteEnemyV103
extends BlacksiteEnemy

var presentation_asset: String = ""

func _build_character() -> void:
    body_root = Node3D.new()
    body_root.name = "CharacterVisual"
    add_child(body_root)

    match archetype:
        "raider": presentation_asset = "res://assets/characters/ArmouredHeavy.glb"
        "guard": presentation_asset = "res://assets/characters/MaskedRaider.glb"
        _: presentation_asset = "res://assets/characters/FieldMedic.glb"

    if ResourceLoader.exists(presentation_asset):
        var packed = load(presentation_asset)
        if packed is PackedScene:
            character_model = (packed as PackedScene).instantiate()
            character_model.name = "Authored_%s" % archetype.capitalize()
            character_model.rotation_degrees = Vector3(0,180,0)
            character_model.position = Vector3.ZERO
            character_model.scale = Vector3.ONE
            body_root.add_child(character_model)
            character_anim = _find_animation_player(character_model)
            uses_character_asset = true
            _configure_imported_meshes(character_model)
            _play_character_anim("idle",1.0,0.0)
            return

    # Preserve a stable fallback if vendored content ever fails to import.
    super._build_character()

func _build_weapon() -> void:
    # v1.03 hostile assets carry their own authored weapon/equipment silhouette.
    # Add only gameplay muzzle/VFX so we do not stack a second floating rifle on them.
    rifle_root = Node3D.new()
    rifle_root.name = "IntegratedWeaponGameplayRig"
    rifle_root.position = Vector3(0.18,1.43,-0.40)
    body_root.add_child(rifle_root)

    muzzle = Node3D.new()
    muzzle.name = "Muzzle"
    muzzle.position = Vector3(0,0,-0.65)
    rifle_root.add_child(muzzle)

    var flash := MeshInstance3D.new()
    var flash_mesh := QuadMesh.new()
    flash_mesh.size = Vector2(0.15,0.15)
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

func get_presentation_asset() -> String:
    return presentation_asset
