class_name WorldBuilder
extends Node3D

var materials: Dictionary = {}
var flicker_lights: Array[OmniLight3D] = []
var flicker_phase: Array[float] = []

func build() -> Dictionary:
    name = "HarborDistrict"
    _build_environment()
    _build_materials()
    _build_ground()
    _build_perimeter()
    _build_warehouse_block()
    _build_container_yard()
    _build_pier_and_crane()
    _build_checkpoint()
    _build_story_scenes()
    _build_lighting()
    set_process(true)
    return {
        "player_spawn": Vector3(1.0, 1.1, 47.0),
        "enemy_spawns": [
            {"pos":Vector3(-10,0,23),"type":"scav"},
            {"pos":Vector3(13,0,19),"type":"guard"},
            {"pos":Vector3(-22,0,-2),"type":"scav"},
            {"pos":Vector3(17,0,-10),"type":"guard"},
            {"pos":Vector3(-10,0,-29),"type":"raider"},
            {"pos":Vector3(25,0,-35),"type":"raider"},
            {"pos":Vector3(-30,0,-37),"type":"scav"}
        ],
        "loot_spawns": [
            {"pos":Vector3(-15,0.45,28),"id":"tools"},
            {"pos":Vector3(18,0.5,24),"id":"ssd"},
            {"pos":Vector3(-24,0.55,-8),"id":"radio"},
            {"pos":Vector3(21,0.5,-15),"id":"plate"},
            {"pos":Vector3(-5,0.45,-19),"id":"salewa"},
            {"pos":Vector3(9,0.45,-27),"id":"gold"},
            {"pos":Vector3(29,0.55,-31),"id":"gpu"},
            {"pos":Vector3(-27,0.45,-34),"id":"intel"},
            {"pos":Vector3(4,0.45,8),"id":"battery"},
            {"pos":Vector3(-6,0.45,4),"id":"badge"}
        ],
        "quest_pos": Vector3(-2.0, 1.0, -32.0),
        "extract_pos": Vector3(0.0, 0.0, 52.0)
    }

func _process(_delta: float) -> void:
    var t := Time.get_ticks_msec() * 0.001
    for i in range(flicker_lights.size()):
        var l := flicker_lights[i]
        if is_instance_valid(l):
            var pulse := sin(t * (6.0 + i * 0.7) + flicker_phase[i]) * 0.16
            var glitch := 0.0 if fmod(t + i * 0.31, 3.9) > 0.12 else -0.65
            l.light_energy = max(0.08, 1.45 + pulse + glitch)

func _build_environment() -> void:
    var world_env := WorldEnvironment.new()
    world_env.name = "Atmosphere"
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    var sky_mat := ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color("263b4a")
    sky_mat.sky_horizon_color = Color("85929a")
    sky_mat.ground_bottom_color = Color("111820")
    sky_mat.ground_horizon_color = Color("59646a")
    sky_mat.sun_angle_max = 18.0
    sky_mat.sun_curve = 0.12
    var sky := Sky.new()
    sky.sky_material = sky_mat
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_energy = 0.62
    env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
    env.tonemap_mode = Environment.TONE_MAPPER_ACES
    env.tonemap_exposure = 1.05
    env.fog_enabled = true
    env.fog_light_color = Color("7d878b")
    env.fog_light_energy = 0.65
    env.fog_density = 0.006
    env.fog_height = 4.0
    env.fog_height_density = 0.12
    world_env.environment = env
    add_child(world_env)

    var sun := DirectionalLight3D.new()
    sun.name = "ColdSun"
    sun.rotation_degrees = Vector3(-47.0, -32.0, 0.0)
    sun.light_color = Color("ffd7ad")
    sun.light_energy = 1.55
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 100.0
    sun.directional_shadow_split_1 = 0.12
    sun.directional_shadow_split_2 = 0.35
    sun.directional_shadow_split_3 = 0.7
    add_child(sun)

func _texture(path: String) -> Texture2D:
    if ResourceLoader.exists(path):
        var r = load(path)
        if r is Texture2D:
            return r
    return null

func _pbr(name_: String, color: Color, rough: float, metal: float, base: String = "", normal: String = "", rough_tex: String = "", tile: float = 1.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.resource_name = name_
    m.albedo_color = color
    m.roughness = rough
    m.metallic = metal
    m.uv1_scale = Vector3(tile, tile, tile)
    var tex := _texture(base)
    if tex:
        m.albedo_texture = tex
    var norm := _texture(normal)
    if norm:
        m.normal_enabled = true
        m.normal_texture = norm
        m.normal_scale = 0.8
    var rt := _texture(rough_tex)
    if rt:
        m.roughness_texture = rt
    return m

func _build_materials() -> void:
    materials.asphalt = _pbr("Wet asphalt", Color("696d6b"), 0.86, 0.0, "res://assets/textures/asphalt_color.jpg", "res://assets/textures/asphalt_normal.jpg", "res://assets/textures/asphalt_rough.jpg", 0.075)
    materials.concrete = _pbr("Weathered concrete", Color("777875"), 0.9, 0.0, "res://assets/textures/concrete_color.jpg", "res://assets/textures/concrete_normal.jpg", "res://assets/textures/concrete_rough.jpg", 0.12)
    materials.brick = _pbr("Dock brick", Color("8b756c"), 0.88, 0.0, "res://assets/textures/brick_color.jpg", "res://assets/textures/brick_normal.jpg", "res://assets/textures/brick_rough.jpg", 0.18)
    materials.metal = _pbr("Rusted steel", Color("8b8c89"), 0.48, 0.62, "res://assets/textures/metal_color.jpg", "res://assets/textures/metal_normal.jpg", "res://assets/textures/metal_rough.jpg", 0.22)
    materials.dark_metal = _pbr("Gunmetal", Color("252a2d"), 0.38, 0.72)
    materials.rust = _pbr("Oxidized steel", Color("6e3523"), 0.72, 0.38)
    materials.blue = _pbr("Faded blue paint", Color("264f5e"), 0.52, 0.28)
    materials.red = _pbr("Faded red paint", Color("74352d"), 0.56, 0.25)
    materials.green = _pbr("Faded green paint", Color("405743"), 0.64, 0.18)
    materials.yellow = _pbr("Safety yellow", Color("ba8632"), 0.52, 0.24)
    materials.wood = _pbr("Oily timber", Color("5c4430"), 0.8, 0.0)
    materials.rubber = _pbr("Rubber", Color("171a1b"), 0.92, 0.0)
    materials.glass = _pbr("Dirty glass", Color("66808a"), 0.12, 0.0)
    materials.glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    materials.glass.albedo_color.a = 0.4
    materials.blood = _pbr("Dried blood", Color("4b1112"), 0.55, 0.0)
    materials.emissive_red = _pbr("Emergency red", Color("5f1414"), 0.35, 0.1)
    materials.emissive_red.emission_enabled = true
    materials.emissive_red.emission = Color("ff382f")
    materials.emissive_red.emission_energy_multiplier = 3.0
    materials.emissive_cyan = _pbr("Terminal cyan", Color("12383d"), 0.3, 0.15)
    materials.emissive_cyan.emission_enabled = true
    materials.emissive_cyan.emission = Color("47deec")
    materials.emissive_cyan.emission_energy_multiplier = 2.4

func _body_with_mesh(name_: String, pos: Vector3, mesh: Mesh, material: Material, collision_shape: Shape3D = null, rot: Vector3 = Vector3.ZERO) -> Node3D:
    var root: Node3D
    if collision_shape:
        var body := StaticBody3D.new()
        root = body
        var cs := CollisionShape3D.new()
        cs.shape = collision_shape
        body.add_child(cs)
    else:
        root = Node3D.new()
    root.name = name_
    root.position = pos
    root.rotation_degrees = rot
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = material
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    root.add_child(mi)
    add_child(root)
    return root

func box(name_: String, pos: Vector3, size: Vector3, mat_key: String, collision: bool = true, rot_y: float = 0.0) -> Node3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    var shape: Shape3D = null
    if collision:
        var bs := BoxShape3D.new()
        bs.size = size
        shape = bs
    return _body_with_mesh(name_, pos, mesh, materials.get(mat_key, materials.concrete), shape, Vector3(0, rot_y, 0))

func cylinder(name_: String, pos: Vector3, radius: float, height: float, mat_key: String, collision: bool = false, rot: Vector3 = Vector3.ZERO) -> Node3D:
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    var shape: Shape3D = null
    if collision:
        var cs := CylinderShape3D.new()
        cs.radius = radius
        cs.height = height
        shape = cs
    return _body_with_mesh(name_, pos, mesh, materials.get(mat_key, materials.metal), shape, rot)

func _build_ground() -> void:
    box("Harbor asphalt", Vector3(0,-0.28,0), Vector3(116,0.5,116), "asphalt", true)
    box("Loading apron", Vector3(0,-0.01,-20), Vector3(56,0.08,34), "concrete", false)
    for z in range(-50, 53, 7):
        box("lane stripe", Vector3(-1.1,0.025,float(z)), Vector3(0.14,0.03,3.5), "yellow", false)
    for x in [-18.0, 18.0]:
        for z in range(-44, 42, 12):
            box("drain", Vector3(x,0.02,float(z)), Vector3(1.7,0.03,0.24), "dark_metal", false)

func _build_perimeter() -> void:
    for x in [-55.0, 55.0]:
        box("perimeter wall", Vector3(x,1.65,0), Vector3(0.5,3.3,116), "concrete", true)
        for z in range(-52, 53, 5):
            box("wall cap", Vector3(x,3.45,float(z)), Vector3(0.75,0.16,4.2), "metal", false)
    box("north wall L", Vector3(-31,1.65,56), Vector3(50,3.3,0.5), "concrete", true)
    box("north wall R", Vector3(31,1.65,56), Vector3(50,3.3,0.5), "concrete", true)
    box("south wall", Vector3(0,1.65,-56), Vector3(116,3.3,0.5), "concrete", true)
    _make_fence(Vector3(0,1.2,51.5), 15.0, 0.0)

func _make_fence(pos: Vector3, length: float, rot_y: float) -> void:
    var root := Node3D.new()
    root.position = pos
    root.rotation_degrees.y = rot_y
    add_child(root)
    for x in range(int(-length/2.0), int(length/2.0)+1, 2):
        var p := BoxMesh.new(); p.size=Vector3(0.07,2.4,0.07)
        var mi:=MeshInstance3D.new();mi.mesh=p;mi.material_override=materials.metal;mi.position=Vector3(float(x),0,0);root.add_child(mi)
    for y in [0.0,0.95,1.9]:
        var r:=BoxMesh.new();r.size=Vector3(length,0.05,0.05)
        var rm:=MeshInstance3D.new();rm.mesh=r;rm.material_override=materials.metal;rm.position=Vector3(0,y-0.65,0);root.add_child(rm)
    for x in range(int(-length*2), int(length*2)+1):
        var wire:=BoxMesh.new();wire.size=Vector3(0.018,2.05,0.018)
        var wi:=MeshInstance3D.new();wi.mesh=wire;wi.material_override=materials.metal;wi.position=Vector3(float(x)*0.25,-0.05,0);root.add_child(wi)

func _warehouse(name_: String, center: Vector3, size: Vector3, door_side: int = 1) -> void:
    var w:=size.x;var d:=size.z;var h:=size.y
    box(name_+" floor", center+Vector3(0,0.08,0), Vector3(w,0.16,d), "concrete", false)
    box(name_+" back", center+Vector3(0,h*0.5,-d*0.5), Vector3(w,h,0.35), "brick", true)
    box(name_+" left", center+Vector3(-w*0.5,h*0.5,0), Vector3(0.35,h,d), "brick", true)
    box(name_+" right", center+Vector3(w*0.5,h*0.5,0), Vector3(0.35,h,d), "brick", true)
    var opening:=5.0
    var front_z:=center.z+d*0.5
    box(name_+" frontL", Vector3(center.x-(w+opening)*0.25,h*0.5,front_z), Vector3((w-opening)*0.5,h,0.35), "brick", true)
    box(name_+" frontR", Vector3(center.x+(w+opening)*0.25,h*0.5,front_z), Vector3((w-opening)*0.5,h,0.35), "brick", true)
    box(name_+" header", Vector3(center.x,h-0.55,front_z), Vector3(opening,1.1,0.35), "metal", true)
    box(name_+" roof", center+Vector3(0,h+0.18,0), Vector3(w+0.4,0.28,d+0.4), "metal", true)
    for x in range(int(-w/2)+2,int(w/2),4):
        box(name_+" beam", center+Vector3(float(x),h-0.35,0), Vector3(0.16,0.2,d-0.6), "dark_metal", false)
    for x in [-w*0.28,w*0.28]:
        box(name_+" window", Vector3(center.x+x,h*0.62,front_z+0.19), Vector3(2.0,1.0,0.06), "glass", false)
    var lamp := OmniLight3D.new();lamp.position=center+Vector3(0,h-0.7,0);lamp.light_color=Color("ffd7a3");lamp.light_energy=1.1;lamp.omni_range=12;lamp.shadow_enabled=true;add_child(lamp)

func _build_warehouse_block() -> void:
    _warehouse("Warehouse 07", Vector3(-28,0,-24), Vector3(31,7.5,37))
    _warehouse("Maintenance", Vector3(27,0,-28), Vector3(25,6.0,24))
    for p in [Vector3(-34,1.0,-18),Vector3(-23,1.0,-20),Vector3(-31,1.0,-32),Vector3(23,1.0,-26)]:
        box("cargo crate",p,Vector3(2.0,2.0,2.0),"wood",true)
    box("office shell",Vector3(-16,1.7,-34),Vector3(8,3.4,7),"concrete",true)
    box("office door",Vector3(-16,1.2,-30.45),Vector3(2.1,2.4,0.12),"dark_metal",false)
    var sign:=Label3D.new();sign.text="WAREHOUSE 07 // ACCESS RESTRICTED";sign.font_size=44;sign.modulate=Color("d9cfc1");sign.position=Vector3(-28,5.2,-4.9);sign.outline_size=6;sign.outline_modulate=Color("17191a");add_child(sign)

func _container(name_: String, pos: Vector3, mat_key: String, rot_y: float = 0.0) -> void:
    box(name_,pos,Vector3(8.2,2.65,2.65),mat_key,true,rot_y)
    var root:=Node3D.new();root.position=pos;root.rotation_degrees.y=rot_y;add_child(root)
    for x in range(-7,8):
        var rib:=BoxMesh.new();rib.size=Vector3(0.055,2.35,2.72)
        var mi:=MeshInstance3D.new();mi.mesh=rib;mi.material_override=materials.dark_metal;mi.position=Vector3(float(x)*0.47,0,0);root.add_child(mi)
    for x in [-3.9,3.9]:
        for y in [-1.15,1.15]:
            var c:=BoxMesh.new();c.size=Vector3(0.18,0.18,2.8)
            var cm:=MeshInstance3D.new();cm.mesh=c;cm.material_override=materials.metal;cm.position=Vector3(x,y,0);root.add_child(cm)

func _build_container_yard() -> void:
    var defs=[
        [Vector3(-16,1.32,29),"blue",0.0],[Vector3(-6,1.32,29),"red",0.0],[Vector3(4,1.32,29),"green",0.0],[Vector3(14,1.32,29),"blue",0.0],
        [Vector3(-21,1.32,15),"red",90.0],[Vector3(-21,3.98,15),"blue",90.0],[Vector3(21,1.32,13),"green",90.0],
        [Vector3(-8,1.32,4),"blue",0.0],[Vector3(2,1.32,4),"red",0.0],[Vector3(12,1.32,4),"green",0.0]
    ]
    for d in defs:_container("shipping container",d[0],d[1],d[2])
    for p in [Vector3(-33,0.18,10),Vector3(31,0.18,8),Vector3(14,0.18,-8),Vector3(-8,0.18,-12)]:
        _pallet_stack(p)
    for p in [Vector3(-38,0.55,14),Vector3(-36.7,0.55,14),Vector3(34,0.55,15),Vector3(35.3,0.55,15)]:
        cylinder("fuel drum",p,0.33,1.1,"rust",true)

func _pallet_stack(pos: Vector3) -> void:
    for level in range(2):
        for i in range(5):
            box("pallet slat",pos+Vector3((i-2)*0.23,level*0.19,0),Vector3(0.18,0.08,1.25),"wood",false)
        for z in [-0.48,0.0,0.48]:
            box("pallet brace",pos+Vector3(0,level*0.19-0.08,z),Vector3(1.2,0.09,0.12),"wood",false)

func _build_pier_and_crane() -> void:
    box("pier",Vector3(0,0.0,-49),Vector3(72,0.5,12),"concrete",true)
    for x in [-33.0,33.0]:
        cylinder("pier bollard",Vector3(x,0.55,-47),0.34,1.1,"dark_metal",true)
    for x in [29.0,36.0]:
        box("crane leg",Vector3(x,7.0,-45),Vector3(0.7,14,0.7),"yellow",true)
    box("crane bridge",Vector3(32.5,14,-45),Vector3(18,0.65,0.65),"yellow",false)
    box("crane boom",Vector3(22,16,-45),Vector3(24,0.35,0.4),"yellow",false,-8.0)
    cylinder("crane cable",Vector3(10.8,10.2,-45),0.035,10.5,"dark_metal",false)
    box("cargo hook",Vector3(10.8,5.0,-45),Vector3(0.5,0.7,0.25),"dark_metal",false)

func _build_checkpoint() -> void:
    box("checkpoint booth",Vector3(0,1.4,45),Vector3(8,2.8,4.8),"concrete",true)
    box("booth glass",Vector3(0,1.65,42.55),Vector3(5.2,1.1,0.08),"glass",false)
    box("barrier L",Vector3(-10,0.75,49),Vector3(13,0.18,0.18),"yellow",false,-7.0)
    box("barrier R",Vector3(10,0.75,49),Vector3(13,0.18,0.18),"yellow",false,7.0)
    for x in [-17.0,17.0]:
        box("jersey barrier",Vector3(x,0.55,47),Vector3(5.0,1.1,1.0),"concrete",true)
    var sign:=Label3D.new();sign.text="GATE 3 // EVAC CORRIDOR";sign.font_size=34;sign.position=Vector3(0,3.6,44.1);sign.modulate=Color("b8dbe4");sign.outline_size=5;add_child(sign)

func _blood_mark(pos: Vector3, scale_: Vector3) -> void:
    box("blood smear",pos,scale_,"blood",false)

func _story_label(text_: String, pos: Vector3, rot_y: float = 0.0, color: Color = Color("d2c8bb")) -> void:
    var l:=Label3D.new();l.text=text_;l.position=pos;l.rotation_degrees.y=rot_y;l.font_size=28;l.modulate=color;l.outline_size=7;l.outline_modulate=Color("101315");l.no_depth_test=false;add_child(l)

func _build_story_scenes() -> void:
    box("triage table",Vector3(-41,0.85,-8),Vector3(3.0,0.12,1.2),"metal",true)
    box("body bag",Vector3(-40.5,1.08,-8),Vector3(2.0,0.32,0.62),"rubber",false,9.0)
    _blood_mark(Vector3(-39.7,0.035,-7.4),Vector3(1.8,0.025,0.8))
    _blood_mark(Vector3(-38.1,0.035,-6.8),Vector3(0.9,0.025,0.45))
    _story_label("TRIAGE FULL\nMOVE WOUNDED TO PIER 6",Vector3(-43.7,2.0,-7.7),90.0,Color("c6b7a4"))
    box("security desk",Vector3(8,0.8,39),Vector3(3.4,1.0,1.2),"wood",true)
    box("dead monitor",Vector3(8,1.65,39),Vector3(0.85,0.6,0.16),"dark_metal",false)
    box("monitor glow",Vector3(8,1.65,38.9),Vector3(0.7,0.44,0.02),"emissive_cyan",false)
    _story_label("02:17 — PIER 6 WENT DARK\nDO NOT ANSWER CHANNEL 4",Vector3(9.8,1.7,38.2),-18.0,Color("e0d5c4"))
    box("breach door",Vector3(34,1.4,-16),Vector3(0.22,2.8,3.0),"dark_metal",true)
    for y in [0.75,1.2,1.65]:
        box("bullet strike",Vector3(33.86,y,-15.5+y*0.15),Vector3(0.03,0.08,0.08),"metal",false)
    _blood_mark(Vector3(32.6,0.035,-16.5),Vector3(2.6,0.024,0.55))
    _story_label("NO ENTRY // QUARANTINE",Vector3(33.82,2.15,-15.9),90.0,Color("ef7568"))
    var red:=OmniLight3D.new();red.position=Vector3(-2,3.1,-31);red.light_color=Color("ff473c");red.light_energy=1.4;red.omni_range=8.0;red.shadow_enabled=true;add_child(red);flicker_lights.append(red);flicker_phase.append(1.7)
    box("red fixture",Vector3(-2,3.15,-31),Vector3(0.3,0.18,0.2),"emissive_red",false)
    _story_label("BLACK TIDE // ARCHIVE 3",Vector3(-2,2.3,-32.7),0.0,Color("ff8b7f"))

func _build_lighting() -> void:
    for p in [Vector3(-43,5.5,31),Vector3(42,5.5,28),Vector3(-7,5.5,14),Vector3(26,5.5,-4),Vector3(-18,5.5,-44)]:
        cylinder("light pole",p-Vector3(0,2.7,0),0.09,5.4,"metal",false)
        box("lamp head",p+Vector3(0.55,0,0),Vector3(1.1,0.16,0.35),"metal",false)
        var l:=OmniLight3D.new();l.position=p+Vector3(0.55,-0.2,0);l.light_color=Color("ffd09b");l.light_energy=1.35;l.omni_range=14;l.shadow_enabled=false;add_child(l);flicker_lights.append(l);flicker_phase.append(randf()*6.0)
