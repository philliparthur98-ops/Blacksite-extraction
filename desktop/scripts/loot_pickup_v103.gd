class_name LootPickupV103
extends LootPickup

const PACK_SCENE := "res://assets/loot/ForestOutpost.glb"
const KEYCARD_SCENE := "res://assets/loot/KeyCard.glb"

const FRAGMENTS := {
    "ifak":"medical kit",
    "salewa":"medical kit",
    "radio":"field radio",
    "carrier":"plate carrier",
    "plate":"plate carrier",
    "gpu":"lockbox",
    "ssd":"field radio",
    "intel":"supply crate",
    "quest_drive":"lockbox",
    "tools":"tool wall",
    "battery":"fuel can",
    "gold":"supply crate"
}

static var cached_pack: PackedScene
static var cached_pack_source: Node
static var cached_keycard: PackedScene
var authored_visual: Node3D
var has_authored_asset: bool = false

func _build_visual() -> void:
    var shape := CollisionShape3D.new()
    var sphere := SphereShape3D.new()
    sphere.radius = 0.58
    shape.shape = sphere
    shape.position.y = 0.28
    add_child(shape)

    authored_visual = _instantiate_authored_item()
    if authored_visual != null:
        has_authored_asset = true
        authored_visual.name = "AuthoredLoot_%s" % item_id
        authored_visual.position = Vector3(0,0.02,0)
        authored_visual.rotation_degrees.y = randf_range(-18.0,18.0)
        authored_visual.scale = _scale_for_item(item_id)
        add_child(authored_visual)
        _configure_meshes(authored_visual)
    else:
        authored_visual = _hard_case_fallback()
        add_child(authored_visual)

    if item_id == "quest_drive":
        var light := OmniLight3D.new()
        light.light_color = Color("55dce8")
        light.light_energy = 0.35
        light.omni_range = 2.0
        light.position = Vector3(0,0.28,0)
        add_child(light)

func _load_pack_source() -> Node:
    if cached_pack_source != null and is_instance_valid(cached_pack_source):
        return cached_pack_source
    if cached_pack == null and ResourceLoader.exists(PACK_SCENE):
        var resource = load(PACK_SCENE)
        if resource is PackedScene: cached_pack = resource
    if cached_pack != null:
        cached_pack_source = cached_pack.instantiate()
    return cached_pack_source

func _instantiate_authored_item() -> Node3D:
    if item_id == "badge":
        if cached_keycard == null and ResourceLoader.exists(KEYCARD_SCENE):
            var key_resource = load(KEYCARD_SCENE)
            if key_resource is PackedScene: cached_keycard = key_resource
        if cached_keycard != null:
            return cached_keycard.instantiate() as Node3D
        return null
    var source := _load_pack_source()
    if source == null: return null
    var fragment := str(FRAGMENTS.get(item_id,"supply crate"))
    var found := _find_named_node(source,fragment)
    if found is Node3D:
        return (found as Node3D).duplicate(Node.DUPLICATE_USE_INSTANTIATION) as Node3D
    return null

func _find_named_node(node: Node, fragment: String) -> Node:
    var needle := fragment.to_lower().replace(" ","")
    var candidate := str(node.name).to_lower().replace("_","").replace("-","").replace(" ","")
    if candidate.contains(needle): return node
    for child in node.get_children():
        var result := _find_named_node(child,fragment)
        if result != null: return result
    return null

func _scale_for_item(id: String) -> Vector3:
    match id:
        "badge": return Vector3.ONE*0.55
        "plate", "carrier": return Vector3.ONE*0.82
        "radio": return Vector3.ONE*0.65
        "gpu", "ssd", "intel", "quest_drive": return Vector3.ONE*0.72
        "tools": return Vector3.ONE*0.75
        _: return Vector3.ONE*0.85

func _configure_meshes(node: Node) -> void:
    if node is MeshInstance3D:
        (node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    for child in node.get_children(): _configure_meshes(child)

func _hard_case_fallback() -> Node3D:
    var root := Node3D.new()
    var body := MeshInstance3D.new()
    var mesh := BoxMesh.new(); mesh.size = Vector3(0.48,0.18,0.34); body.mesh = mesh; body.position.y = 0.12
    var mat := StandardMaterial3D.new(); mat.albedo_color=Color("252b29"); mat.metallic=0.18; mat.roughness=0.72
    body.material_override=mat; root.add_child(body)
    return root

func _process(_delta: float) -> void:
    position.y = base_y

func get_interaction_prompt() -> String:
    if item_id == "quest_drive": return "HOLD F // SECURE BLACK TIDE DRIVE"
    return "F // TAKE %s  •  $%s" % [str(data.get("name",item_id)).to_upper(),str(data.get("value",0))]

func smoke_has_authored_asset() -> bool:
    return has_authored_asset
