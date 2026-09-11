class_name BlacksiteEnemy
extends CharacterBody3D

signal killed(enemy: BlacksiteEnemy, archetype: String)

var target: BlacksitePlayer
var archetype := "scav"
var health := 100.0
var armor := 0.0
var fire_cooldown := 1.0
var burst_remaining := 0
var burst_timer := 0.0
var state := "idle"
var last_seen := Vector3.ZERO
var investigate_timer := 0.0
var patrol_origin := Vector3.ZERO
var patrol_target := Vector3.ZERO
var phase := 0.0
var body_root: Node3D
var muzzle: Node3D
var muzzle_light: OmniLight3D
var shot_audio: AudioStreamPlayer3D
var legs: Array[Node3D] = []
var arms: Array[Node3D] = []
var dead := false

func configure(target_: BlacksitePlayer, archetype_: String) -> void:
    target=target_;archetype=archetype_

func _ready() -> void:
    collision_layer=1;collision_mask=1;patrol_origin=global_position;patrol_target=patrol_origin+Vector3(randf_range(-5,5),0,randf_range(-5,5))
    match archetype:
        "guard":health=125;armor=38
        "raider":health=150;armor=62
        _:health=95;armor=12
    var shape:=CollisionShape3D.new();var cap:=CapsuleShape3D.new();cap.radius=.42;cap.height=1.8;shape.shape=cap;shape.position.y=.9;add_child(shape);_build_character()
    shot_audio=AudioStreamPlayer3D.new();shot_audio.max_distance=75;shot_audio.unit_size=8;add_child(shot_audio);if ResourceLoader.exists("res://assets/audio/rifle.wav"):shot_audio.stream=load("res://assets/audio/rifle.wav");set_physics_process(true)

func _mat(color: Color, metal:=0.0, rough:=0.7) -> StandardMaterial3D:
    var m:=StandardMaterial3D.new();m.albedo_color=color;m.metallic=metal;m.roughness=rough;return m
func _mesh_part(parent: Node3D, name_:String, mesh:Mesh, pos:Vector3, material:Material, rot:=Vector3.ZERO) -> Node3D:
    var n:=Node3D.new();n.name=name_;n.position=pos;n.rotation_degrees=rot;parent.add_child(n);var mi:=MeshInstance3D.new();mi.mesh=mesh;mi.material_override=material;mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON;n.add_child(mi);return n
func _box(parent:Node3D,name_:String,pos:Vector3,size:Vector3,material:Material,rot:=Vector3.ZERO)->Node3D:
    var b:=BoxMesh.new();b.size=size;return _mesh_part(parent,name_,b,pos,material,rot)
func _cyl(parent:Node3D,name_:String,pos:Vector3,r:float,h:float,material:Material,rot:=Vector3.ZERO)->Node3D:
    var c:=CylinderMesh.new();c.top_radius=r;c.bottom_radius=r;c.height=h;return _mesh_part(parent,name_,c,pos,material,rot)
func _sphere(parent:Node3D,name_:String,pos:Vector3,r:float,material:Material,scale:=Vector3.ONE)->Node3D:
    var s:=SphereMesh.new();s.radius=r;s.height=r*2;var n:=_mesh_part(parent,name_,s,pos,material);n.scale=scale;return n

func _build_character() -> void:
    body_root=Node3D.new();body_root.name="Visual";add_child(body_root)
    var cloth:=_mat(Color("4a5346") if archetype!="raider" else Color("30393a"),0,.9);var cloth2:=_mat(Color("2c332e"),0,.92);var hard:=_mat(Color("171d1f"),.25,.55);var skin:=_mat(Color("775847"),0,.82);var metal:=_mat(Color("282f32"),.75,.38);var lens:=_mat(Color("203c43"),.22,.12);lens.emission_enabled=true;lens.emission=Color("153c45");lens.emission_energy_multiplier=.25
    _cyl(body_root,"torso",Vector3(0,1.35,0),.32,.78,cloth);_sphere(body_root,"head",Vector3(0,2.02,0),.23,skin,Vector3(1,.92,.94));_sphere(body_root,"helmet",Vector3(0,2.14,0),.275,hard,Vector3(1,.65,1));_box(body_root,"goggles",Vector3(0,2.05,-.225),Vector3(.35,.095,.055),lens);_box(body_root,"facewrap",Vector3(0,1.91,-.19),Vector3(.28,.16,.07),cloth2)
    var l1:=_cyl(body_root,"leg_l",Vector3(-.14,.55,0),.11,.85,cloth2);var l2:=_cyl(body_root,"leg_r",Vector3(.14,.55,0),.11,.85,cloth2);legs=[l1,l2];var a1:=_cyl(body_root,"arm_l",Vector3(-.39,1.38,-.04),.09,.65,cloth,Vector3(14,0,-8));var a2:=_cyl(body_root,"arm_r",Vector3(.39,1.38,-.04),.09,.65,cloth,Vector3(14,0,8));arms=[a1,a2]
    _box(body_root,"knee_l",Vector3(-.14,.48,-.09),Vector3(.18,.17,.10),hard);_box(body_root,"knee_r",Vector3(.14,.48,-.09),Vector3(.18,.17,.10),hard);_box(body_root,"front_plate",Vector3(0,1.46,-.27),Vector3(.57,.59,.14),hard);_box(body_root,"rear_plate",Vector3(0,1.46,.23),Vector3(.55,.59,.17),cloth2)
    for x in [-.21,0.0,.21]:_box(body_root,"mag",Vector3(x,1.28,-.37),Vector3(.15,.24,.10),cloth2)
    _box(body_root,"pack",Vector3(0,1.39,.34),Vector3(.48,.60,.25),cloth2)
    if archetype=="raider":_box(body_root,"shoulder_l",Vector3(-.42,1.58,0),Vector3(.23,.17,.23),hard);_box(body_root,"shoulder_r",Vector3(.42,1.58,0),Vector3(.23,.17,.23),hard);_box(body_root,"neck_guard",Vector3(0,1.82,.04),Vector3(.38,.18,.21),hard)
    var rifle:=Node3D.new();rifle.name="Rifle";rifle.position=Vector3(.28,1.42,-.44);rifle.rotation_degrees=Vector3(-4,0,-8);body_root.add_child(rifle);_box(rifle,"receiver",Vector3.ZERO,Vector3(.62,.10,.11),metal);_cyl(rifle,"barrel",Vector3(0,-.01,-.48),.025,.65,metal,Vector3(90,0,0));_box(rifle,"magazine",Vector3(0,-.15,-.05),Vector3(.12,.27,.10),hard,Vector3(8,0,0));_box(rifle,"stock",Vector3(0,.01,.43),Vector3(.19,.13,.32),hard)
    muzzle=_sphere(rifle,"Muzzle",Vector3(0,-.01,-.81),.055,_mat(Color("ffb866"),0,.2));var mm:=muzzle.get_child(0) as MeshInstance3D;var em:=mm.material_override as StandardMaterial3D;em.emission_enabled=true;em.emission=Color("ff8d31");em.emission_energy_multiplier=4.0;muzzle.visible=false;muzzle_light=OmniLight3D.new();muzzle_light.position=Vector3(0,-.01,-.81);muzzle_light.light_color=Color("ffad55");muzzle_light.light_energy=0;muzzle_light.omni_range=4;rifle.add_child(muzzle_light)

func _physics_process(delta: float) -> void:
    if dead or target==null or not is_instance_valid(target):return
    phase+=delta;fire_cooldown=maxf(0.0,fire_cooldown-delta);burst_timer=maxf(0.0,burst_timer-delta);var to_target:=target.global_position-global_position;var dist:=Vector2(to_target.x,to_target.z).length();var visible:=_has_los(dist)
    if visible:state="combat";last_seen=target.global_position;investigate_timer=4.5
    elif investigate_timer>0:state="investigate";investigate_timer-=delta
    else:state="patrol"
    match state:
        "combat":_combat(delta,dist,to_target)
        "investigate":_move_toward(last_seen,2.4,delta)
        _:_patrol(delta)
    if not is_on_floor():velocity+=get_gravity()*delta
    move_and_slide();_animate_body(delta)

func _has_los(dist: float) -> bool:
    if dist>38:return false
    var from:=global_position+Vector3(0,1.65,0);var to:=target.global_position+Vector3(0,1.5,0);var q:=PhysicsRayQueryParameters3D.create(from,to);q.exclude=[get_rid()];q.collide_with_areas=false;q.collide_with_bodies=true;var h:=get_world_3d().direct_space_state.intersect_ray(q);if h.is_empty():return true;return h.get("collider")==target

func _combat(delta:float,dist:float,to_target:Vector3)->void:
    rotation.y=lerp_angle(rotation.y,atan2(-to_target.x,-to_target.z),delta*5.0)
    if dist>11:_move_toward(target.global_position,2.0 if archetype=="scav" else 2.6,delta)
    elif dist<6:_move_toward(global_position-(target.global_position-global_position),1.5,delta)
    else:velocity.x=move_toward(velocity.x,0,delta*6);velocity.z=move_toward(velocity.z,0,delta*6)
    if burst_remaining>0 and burst_timer<=0:_shoot_once(dist);burst_remaining-=1;burst_timer=.095 if archetype=="raider" else .16
    elif fire_cooldown<=0 and dist<31:burst_remaining=3 if archetype=="raider" else (2 if archetype=="guard" else 1);fire_cooldown=randf_range(1.0,1.8) if archetype=="raider" else randf_range(1.4,2.5)

func _patrol(delta:float)->void:
    if global_position.distance_to(patrol_target)<1.0:patrol_target=patrol_origin+Vector3(randf_range(-6,6),0,randf_range(-6,6))
    _move_toward(patrol_target,1.35,delta)
func _move_toward(pos:Vector3,speed:float,delta:float)->void:
    var d:=pos-global_position;d.y=0;if d.length()<.1:return;d=d.normalized();velocity.x=move_toward(velocity.x,d.x*speed,delta*6);velocity.z=move_toward(velocity.z,d.z*speed,delta*6);rotation.y=lerp_angle(rotation.y,atan2(-d.x,-d.z),delta*3.5)

func _shoot_once(dist:float)->void:
    muzzle.visible=true;muzzle_light.light_energy=3.7;get_tree().create_timer(.045).timeout.connect(func():
        if is_instance_valid(muzzle):muzzle.visible=false
        if is_instance_valid(muzzle_light):muzzle_light.light_energy=0)
    if shot_audio and shot_audio.stream:shot_audio.play()
    var accuracy:=clampf(.76-dist*.015,0.18,.70);if archetype=="raider":accuracy+=.10;if randf()>accuracy:return
    var roll:=randf();var part:="thorax";if roll<.06:part="head"
    elif roll<.35:part="left_arm" if randf()<.5 else "right_arm"
    elif roll<.58:part="stomach"
    elif roll<.80:part="left_leg" if randf()<.5 else "right_leg"
    var damage:=randf_range(8,13) if archetype!="raider" else randf_range(10,16);target.apply_damage(damage,part,.22 if archetype=="scav" else .38)

func _animate_body(delta:float)->void:
    var sp:=Vector2(velocity.x,velocity.z).length();var walk:=sin(phase*8.0)*minf(sp/2.5,1.0);if legs.size()==2:legs[0].rotation_degrees.x=walk*25;legs[1].rotation_degrees.x=-walk*25
    if arms.size()==2:arms[0].rotation_degrees.x=14-walk*9;arms[1].rotation_degrees.x=14+walk*9
    body_root.position.y=sin(phase*6.0)*.012*minf(sp,1.0)

func take_damage(amount:float,_hit_pos:Vector3,headshot:bool=false)->void:
    if dead:return
    var dmg:=amount;if not headshot and armor>0:var absorbed:=minf(armor,dmg*.55);armor-=absorbed;dmg-=absorbed*.5
    health-=dmg;if health<=0:_die(headshot)

func _die(headshot:bool)->void:
    if dead:return
    dead=true;collision_layer=0;collision_mask=0;velocity=Vector3.ZERO;var tw:=create_tween();tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN);tw.tween_property(body_root,"rotation_degrees:z",87.0,.42);tw.parallel().tween_property(body_root,"position:y",-.42,.42);killed.emit(self,archetype)
    if headshot:var label:=Label3D.new();label.text="HEADSHOT";label.font_size=22;label.position=Vector3(0,2.5,0);label.modulate=Color("ffb66d");label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;add_child(label)
