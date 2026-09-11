class_name WorldBuilderV103
extends WorldBuilder

var map_extent_m: float = 360.0
var authored_districts: int = 0

const INDUSTRIAL_OUTPOST := "res://assets/environment/IndustrialOutpost.glb"
const PROP_PATHS := [
    "res://assets/environment/SM_Crate_Stack.glb",
    "res://assets/environment/SM_Pallet.glb",
    "res://assets/environment/SM_Barrel.glb",
    "res://assets/environment/SM_Rubble_Pile.glb",
    "res://assets/environment/SM_Pipe_2m.glb",
    "res://assets/environment/SM_Sign_Wall.glb",
    "res://assets/environment/SM_Wall_Damaged_4m.glb",
    "res://assets/environment/SM_Stairs_4m.glb"
]

func build() -> Dictionary:
    var original := super.build()
    _remove_demo_perimeter()
    _expand_ground_plane()
    _build_authored_districts()
    _build_connector_routes()
    _scatter_authored_clutter()
    _build_far_perimeter()

    return {
        "player_spawn": Vector3(-8.0,1.1,164.0),
        "enemy_spawns": [
            {"pos":Vector3(-28,0,134),"type":"scav"},
            {"pos":Vector3(34,0,128),"type":"guard"},
            {"pos":Vector3(-104,0,96),"type":"scav"},
            {"pos":Vector3(95,0,91),"type":"guard"},
            {"pos":Vector3(-12,0,58),"type":"scav"},
            {"pos":Vector3(31,0,18),"type":"guard"},
            {"pos":Vector3(-82,0,4),"type":"scav"},
            {"pos":Vector3(105,0,-12),"type":"raider"},
            {"pos":Vector3(-95,0,-76),"type":"guard"},
            {"pos":Vector3(82,0,-91),"type":"raider"},
            {"pos":Vector3(-35,0,-118),"type":"raider"},
            {"pos":Vector3(26,0,-139),"type":"guard"},
            {"pos":Vector3(-7,0,-158),"type":"raider"}
        ],
        "loot_spawns": [
            {"pos":Vector3(-32,0.45,142),"id":"tools"},
            {"pos":Vector3(37,0.45,132),"id":"ssd"},
            {"pos":Vector3(-112,0.45,88),"id":"radio"},
            {"pos":Vector3(-88,0.45,109),"id":"ifak"},
            {"pos":Vector3(102,0.45,83),"id":"plate"},
            {"pos":Vector3(84,0.45,112),"id":"battery"},
            {"pos":Vector3(-20,0.45,53),"id":"salewa"},
            {"pos":Vector3(24,0.45,16),"id":"gold"},
            {"pos":Vector3(-85,0.45,-5),"id":"intel"},
            {"pos":Vector3(101,0.45,-19),"id":"gpu"},
            {"pos":Vector3(-109,0.45,-83),"id":"badge"},
            {"pos":Vector3(-74,0.45,-102),"id":"radio"},
            {"pos":Vector3(89,0.45,-96),"id":"ssd"},
            {"pos":Vector3(67,0.45,-111),"id":"tools"},
            {"pos":Vector3(-29,0.45,-132),"id":"salewa"},
            {"pos":Vector3(31,0.45,-148),"id":"plate"}
        ],
        "quest_pos": Vector3(4.0,1.0,-164.0),
        "extract_pos": Vector3(-146.0,0.0,160.0),
        "map_extent_m": map_extent_m,
        "authored_districts": authored_districts,
        "original_layout": original
    }

func _remove_demo_perimeter() -> void:
    # The original 116 m block becomes the central customs yard. Remove only the
    # hard perimeter shells so the raid can flow into the expanded districts.
    for child in get_children():
        var n := str(child.name).to_lower()
        if n.contains("perimeter wall") or n.begins_with("north wall") or n == "south wall":
            child.queue_free()

func _expand_ground_plane() -> void:
    box("Expanded Harbor Asphalt",Vector3(0,-0.34,0),Vector3(map_extent_m,0.52,map_extent_m),"asphalt",true)
    # Broad roads create readable macro-navigation instead of one corridor.
    box("North South Haul Road",Vector3(0,-0.03,0),Vector3(22,0.08,330),"concrete",false)
    box("East West Service Road",Vector3(0,-0.025,28),Vector3(330,0.07,18),"concrete",false)
    box("South Logistics Apron",Vector3(0,-0.02,-130),Vector3(132,0.06,58),"concrete",false)
    for z in range(-158,160,14):
        box("haul road marker",Vector3(-5.5,0.025,float(z)),Vector3(0.16,0.03,5.0),"yellow",false)
    for x in range(-156,158,16):
        box("service road marker",Vector3(float(x),0.025,32.0),Vector3(5.5,0.03,0.16),"yellow",false)

func _scene_instance(path: String, pos: Vector3, rot_y: float, scale_: float = 1.0, collisions: bool = true) -> Node3D:
    if not ResourceLoader.exists(path):
        return null
    var packed = load(path)
    if not (packed is PackedScene):
        return null
    var root := (packed as PackedScene).instantiate() as Node3D
    if root == null:
        return null
    root.position = pos
    root.rotation_degrees.y = rot_y
    root.scale = Vector3.ONE*scale_
    add_child(root)
    _configure_authored_geometry(root,collisions)
    return root

func _configure_authored_geometry(node: Node, collisions: bool) -> void:
    if node is MeshInstance3D:
        var mi := node as MeshInstance3D
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
        mi.visibility_range_end = 260.0
        if collisions and mi.mesh != null:
            # Detailed imported geometry gets real collision rather than invisible
            # blockout boxes. This is intentionally done only for authored zones.
            mi.create_trimesh_collision()
    for child in node.get_children():
        _configure_authored_geometry(child,collisions)

func _build_authored_districts() -> void:
    if not ResourceLoader.exists(INDUSTRIAL_OUTPOST):
        return
    var placements := [
        {"p":Vector3(-105,0,92),"r":18.0,"s":1.25},
        {"p":Vector3(101,0,82),"r":-96.0,"s":1.18},
        {"p":Vector3(-96,0,-91),"r":166.0,"s":1.30},
        {"p":Vector3(92,0,-101),"r":79.0,"s":1.22},
        {"p":Vector3(1,0,-149),"r":-4.0,"s":1.35}
    ]
    for placement in placements:
        var placed := _scene_instance(INDUSTRIAL_OUTPOST,placement["p"],float(placement["r"]),float(placement["s"]),true)
        if placed:
            placed.name = "AuthoredIndustrialDistrict_%d" % authored_districts
            authored_districts += 1

func _build_connector_routes() -> void:
    # Cover, barriers and believable transition spaces prevent the larger map
    # from becoming empty running terrain.
    for z in [-132.0,-102.0,-66.0,-22.0,55.0,102.0,137.0]:
        for x in [-18.0,18.0]:
            box("Road Barrier",Vector3(x,0.52,z),Vector3(4.2,1.0,0.7),"concrete",true,randf_range(-8.0,8.0))
    for x in [-132.0,-72.0,67.0,128.0]:
        box("Service Checkpoint",Vector3(x,1.2,30),Vector3(7.0,2.4,1.0),"metal",true,randf_range(-5.0,5.0))
    # Distant warehouse silhouettes improve navigation and horizon density.
    for p in [Vector3(-151,4,-34),Vector3(149,4,-41),Vector3(-145,4,62),Vector3(147,4,129)]:
        _warehouse("Outer Warehouse",p,Vector3(24,8,20))

func _scatter_authored_clutter() -> void:
    var positions := [
        Vector3(-45,0,124),Vector3(49,0,118),Vector3(-130,0,56),Vector3(123,0,54),
        Vector3(-56,0,8),Vector3(58,0,-4),Vector3(-132,0,-49),Vector3(128,0,-58),
        Vector3(-53,0,-119),Vector3(50,0,-124),Vector3(-15,0,-146),Vector3(18,0,-154),
        Vector3(-118,0,121),Vector3(113,0,113),Vector3(-113,0,-117),Vector3(119,0,-126)
    ]
    var index := 0
    for pos in positions:
        var path: String = str(PROP_PATHS[index % PROP_PATHS.size()])
        var prop := _scene_instance(path,pos,randf_range(-180.0,180.0),1.0,true)
        if prop:
            prop.name = "AuthoredClutter_%d" % index
        index += 1

func _build_far_perimeter() -> void:
    # Visual/collision boundary at ~180 m, leaving a genuinely larger playable footprint.
    for x in [-179.0,179.0]:
        box("Outer Security Wall",Vector3(x,2.0,0),Vector3(0.8,4.0,358),"concrete",true)
    for z in [-179.0,179.0]:
        box("Outer Security Wall",Vector3(0,2.0,z),Vector3(358,4.0,0.8),"concrete",true)

func smoke_world_scale_ok() -> bool:
    return map_extent_m >= 350.0 and authored_districts >= 4 and ResourceLoader.exists(INDUSTRIAL_OUTPOST)
