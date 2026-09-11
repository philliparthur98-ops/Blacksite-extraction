class_name LootPickup
extends Area3D

signal picked(item_id: String, source: LootPickup)

var item_id: String = "tools"
var data: Dictionary = {}
var base_y := 0.0
var phase := 0.0

func configure(id_: String) -> void:
    item_id = id_
    data = ItemDB.get_item(item_id)
    name = "Loot_%s" % item_id
    collision_layer = 4
    collision_mask = 0
    base_y = position.y
    phase = randf() * TAU
    _build_visual()
    set_process(true)

func _build_visual() -> void:
    var shape := CollisionShape3D.new()
    var sphere := SphereShape3D.new()
    sphere.radius = 0.45
    shape.shape = sphere
    add_child(shape)

    var pedestal := MeshInstance3D.new()
    var pm := CylinderMesh.new()
    pm.top_radius=0.34
    pm.bottom_radius=0.34
    pm.height=0.035
    pedestal.mesh=pm
    var glow:=StandardMaterial3D.new()
    glow.albedo_color=ItemDB.rarity_color(str(data.get("rarity","common"))).darkened(0.4)
    glow.emission_enabled=true
    glow.emission=ItemDB.rarity_color(str(data.get("rarity","common")))
    glow.emission_energy_multiplier=1.6
    glow.roughness=0.4
    pedestal.material_override=glow
    pedestal.position.y=0.02
    add_child(pedestal)

    var visual := MeshInstance3D.new()
    var kind := str(data.get("kind","barter"))
    match kind:
        "armor":
            var mesh:=BoxMesh.new();mesh.size=Vector3(0.46,0.55,0.10);visual.mesh=mesh;visual.position.y=0.34
        "med":
            var mesh:=BoxMesh.new();mesh.size=Vector3(0.45,0.32,0.26);visual.mesh=mesh;visual.position.y=0.25
        "valuable":
            var mesh:=BoxMesh.new();mesh.size=Vector3(0.52,0.28,0.11);visual.mesh=mesh;visual.position.y=0.23
        "intel":
            var mesh:=BoxMesh.new();mesh.size=Vector3(0.48,0.06,0.36);visual.mesh=mesh;visual.position.y=0.16;visual.rotation_degrees.y=18
        "quest":
            var mesh:=BoxMesh.new();mesh.size=Vector3(0.44,0.22,0.12);visual.mesh=mesh;visual.position.y=0.25
        _:
            var mesh:=BoxMesh.new();mesh.size=Vector3(0.42,0.31,0.28);visual.mesh=mesh;visual.position.y=0.24
    var mat:=StandardMaterial3D.new();mat.albedo_color=ItemDB.rarity_color(str(data.get("rarity","common"))).darkened(0.55);mat.metallic=0.35;mat.roughness=0.42
    visual.material_override=mat;add_child(visual)

    var label:=Label3D.new();label.text=str(data.get("name",item_id)).to_upper();label.font_size=24;label.position=Vector3(0,0.8,0);label.modulate=ItemDB.rarity_color(str(data.get("rarity","common")));label.outline_size=6;label.outline_modulate=Color("0b1014");label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;add_child(label)

    if item_id == "quest_drive":
        var light:=OmniLight3D.new();light.light_color=Color("55dce8");light.light_energy=0.9;light.omni_range=4.0;light.position.y=0.45;add_child(light)

func _process(_delta: float) -> void:
    rotation.y += 0.004
    position.y = base_y + sin(Time.get_ticks_msec()*0.002 + phase)*0.035

func get_interaction_prompt() -> String:
    if item_id == "quest_drive":
        return "SECURE BLACK TIDE DRIVE"
    return "TAKE %s  ·  $%s" % [str(data.get("name",item_id)).to_upper(), str(data.get("value",0))]

func interact(_player: Node) -> void:
    picked.emit(item_id,self)
