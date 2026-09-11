class_name BlacksitePlayer
extends CharacterBody3D

signal died
signal hud_state_changed(state: Dictionary)
signal interaction_prompt(text: String)
signal toast_requested(text: String)

var game: Node
var mouse_sensitivity := 0.075
var yaw := 0.0
var pitch := 0.0
var walk_speed := 4.1
var sprint_speed := 6.6
var crouch_speed := 2.25
var stamina := 100.0
var stamina_max := 100.0
var armor := 60.0
var body_health := {"head":35.0,"thorax":85.0,"stomach":70.0,"left_arm":60.0,"right_arm":60.0,"left_leg":65.0,"right_leg":65.0}
var max_health := {"head":35.0,"thorax":85.0,"stomach":70.0,"left_arm":60.0,"right_arm":60.0,"left_leg":65.0,"right_leg":65.0}
var dead := false
var current_weapon_index := 0
var weapon_ids := ["m4","g17","m870"]
var weapon_data: Dictionary = {}
var ammo := 0
var reserve := 0
var fire_cooldown := 0.0
var reloading := false
var reload_timer := 0.0
var aiming := false
var recoil_pitch := 0.0
var recoil_yaw := 0.0
var weapon_kick := 0.0
var sway := Vector2.ZERO
var bob_time := 0.0
var interaction_target: Object = null
var interaction_text := ""
var shot_audio: AudioStreamPlayer
var camera: Camera3D
var neck: Node3D
var weapon_anchor: Node3D
var viewmodel: Node3D
var muzzle_light: OmniLight3D
var muzzle_mesh: MeshInstance3D
var capsule: CollisionShape3D
var crouched := false

func setup(game_: Node) -> void:
    game = game_

func _ready() -> void:
    name = "Player"
    collision_layer = 1
    collision_mask = 1
    capsule = CollisionShape3D.new()
    var cap := CapsuleShape3D.new(); cap.radius=0.38; cap.height=1.75
    capsule.shape = cap
    capsule.position.y = 0.88
    add_child(capsule)
    neck = Node3D.new(); neck.name="Neck"; neck.position=Vector3(0,1.62,0); add_child(neck)
    camera = Camera3D.new();camera.name="Camera";camera.fov=70;camera.near=0.04;camera.far=180;neck.add_child(camera)
    weapon_anchor=Node3D.new();weapon_anchor.name="WeaponAnchor";camera.add_child(weapon_anchor);weapon_anchor.position=Vector3(0.33,-0.34,-0.72)
    _build_hands();_build_muzzle();_load_weapon(0)
    shot_audio=AudioStreamPlayer.new();add_child(shot_audio)
    if ResourceLoader.exists("res://assets/audio/rifle.wav"):shot_audio.stream=load("res://assets/audio/rifle.wav")
    Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
    set_process_input(true);set_physics_process(true);set_process(true);_emit_hud()

func _build_hands() -> void:
    var glove:=StandardMaterial3D.new();glove.albedo_color=Color("363a35");glove.roughness=.88
    var sleeve:=StandardMaterial3D.new();sleeve.albedo_color=Color("52604e");sleeve.roughness=.92
    for side in [-1.0,1.0]:
        var fore:=MeshInstance3D.new();var cm:=CylinderMesh.new();cm.top_radius=.07;cm.bottom_radius=.09;cm.height=.52;fore.mesh=cm;fore.material_override=sleeve;fore.position=Vector3(.20*side,-.26,-.36);fore.rotation_degrees=Vector3(73,0,12*side);weapon_anchor.add_child(fore)
        var hand:=MeshInstance3D.new();var sm:=SphereMesh.new();sm.radius=.095;sm.height=.18;hand.mesh=sm;hand.material_override=glove;hand.position=Vector3(.15*side,-.12,-.55 if side>0 else -.28);hand.scale=Vector3(1.0,.75,1.15);weapon_anchor.add_child(hand)

func _build_muzzle() -> void:
    muzzle_light=OmniLight3D.new();muzzle_light.light_color=Color("ffb258");muzzle_light.light_energy=0.0;muzzle_light.omni_range=5.0;muzzle_light.position=Vector3(0,0,-1.2);weapon_anchor.add_child(muzzle_light)
    muzzle_mesh=MeshInstance3D.new();var sm:=SphereMesh.new();sm.radius=.08;sm.height=.16;muzzle_mesh.mesh=sm
    var mm:=StandardMaterial3D.new();mm.albedo_color=Color("ffc26b");mm.emission_enabled=true;mm.emission=Color("ff8d33");mm.emission_energy_multiplier=5.0;muzzle_mesh.material_override=mm;muzzle_mesh.position=Vector3(0,0,-1.2);muzzle_mesh.visible=false;weapon_anchor.add_child(muzzle_mesh)

func _clear_viewmodel() -> void:
    if is_instance_valid(viewmodel):viewmodel.queue_free()
    viewmodel=null

func _fallback_weapon(id: String) -> Node3D:
    var root:=Node3D.new();root.name="Fallback_%s"%id
    var gunmat:=StandardMaterial3D.new();gunmat.albedo_color=Color("22282b");gunmat.metallic=.72;gunmat.roughness=.36
    var polymat:=StandardMaterial3D.new();polymat.albedo_color=Color("111618");polymat.roughness=.66
    var add_box=func(p:Vector3,s:Vector3,m:Material):
        var mi:=MeshInstance3D.new();var bm:=BoxMesh.new();bm.size=s;mi.mesh=bm;mi.material_override=m;mi.position=p;root.add_child(mi)
    var add_cyl=func(p:Vector3,r:float,h:float,m:Material,rot:Vector3):
        var mi:=MeshInstance3D.new();var cm:=CylinderMesh.new();cm.top_radius=r;cm.bottom_radius=r;cm.height=h;mi.mesh=cm;mi.material_override=m;mi.position=p;mi.rotation_degrees=rot;root.add_child(mi)
    if id=="g17":
        add_box.call(Vector3(0,.02,-.20),Vector3(.20,.12,.45),gunmat);add_box.call(Vector3(0,-.13,-.04),Vector3(.12,.32,.16),polymat);add_cyl.call(Vector3(0,.02,-.48),.022,.32,gunmat,Vector3(90,0,0))
    elif id=="m870":
        add_box.call(Vector3(0,0,-.15),Vector3(.15,.14,.76),gunmat);add_cyl.call(Vector3(0,.03,-.74),.028,.95,gunmat,Vector3(90,0,0));add_box.call(Vector3(0,-.04,-.49),Vector3(.18,.12,.33),polymat);add_box.call(Vector3(0,.01,.40),Vector3(.18,.16,.42),polymat)
    else:
        add_box.call(Vector3(0,0,-.12),Vector3(.24,.14,.58),gunmat);add_box.call(Vector3(0,.01,-.55),Vector3(.19,.12,.40),gunmat);add_cyl.call(Vector3(0,.01,-.96),.025,.62,gunmat,Vector3(90,0,0));add_box.call(Vector3(0,-.16,-.05),Vector3(.13,.33,.16),polymat);add_box.call(Vector3(0,.02,.38),Vector3(.25,.14,.35),polymat)
    return root

func _load_weapon(index: int) -> void:
    current_weapon_index=clampi(index,0,weapon_ids.size()-1)
    var id:=weapon_ids[current_weapon_index]
    weapon_data=ItemDB.get_item(id);ammo=int(weapon_data.get("mag",30));reserve=int(weapon_data.get("reserve",90));reloading=false;reload_timer=0
    _clear_viewmodel()
    var asset:=str(weapon_data.get("asset",""))
    if asset!="" and ResourceLoader.exists(asset):
        var packed=load(asset)
        if packed is PackedScene:viewmodel=packed.instantiate()
    if viewmodel==null:viewmodel=_fallback_weapon(id)
    weapon_anchor.add_child(viewmodel)
    if id=="m4":
        viewmodel.scale=Vector3.ONE*.46;viewmodel.rotation_degrees=Vector3(0,90,0);viewmodel.position=Vector3(.03,-.07,-.10);_add_optic()
    elif id=="g17":
        viewmodel.scale=Vector3.ONE*.62;viewmodel.rotation_degrees=Vector3(0,90,0);viewmodel.position=Vector3(.02,-.06,-.12)
    else:
        viewmodel.scale=Vector3.ONE*.52;viewmodel.rotation_degrees=Vector3(0,90,0);viewmodel.position=Vector3(.02,-.08,-.05)
    if shot_audio:
        if id=="m870" and ResourceLoader.exists("res://assets/audio/shotgun.wav"):shot_audio.stream=load("res://assets/audio/shotgun.wav")
        elif ResourceLoader.exists("res://assets/audio/rifle.wav"):shot_audio.stream=load("res://assets/audio/rifle.wav")
    toast_requested.emit("%s READY"%str(weapon_data.get("name",id)).to_upper());_emit_hud()

func _add_optic() -> void:
    var mount:=Node3D.new();mount.name="Optic";mount.position=Vector3(0,.17,-.23);weapon_anchor.add_child(mount)
    var mat:=StandardMaterial3D.new();mat.albedo_color=Color("11171a");mat.metallic=.7;mat.roughness=.32
    var lensmat:=StandardMaterial3D.new();lensmat.albedo_color=Color("193842");lensmat.metallic=.2;lensmat.roughness=.08;lensmat.emission_enabled=true;lensmat.emission=Color("183c48");lensmat.emission_energy_multiplier=.4
    var tube:=MeshInstance3D.new();var cm:=CylinderMesh.new();cm.top_radius=.065;cm.bottom_radius=.065;cm.height=.22;tube.mesh=cm;tube.material_override=mat;tube.rotation_degrees.x=90;mount.add_child(tube)
    var lens:=MeshInstance3D.new();var lm:=CylinderMesh.new();lm.top_radius=.057;lm.bottom_radius=.057;lm.height=.012;lens.mesh=lm;lens.material_override=lensmat;lens.rotation_degrees.x=90;lens.position.z=-.115;mount.add_child(lens)

func _unhandled_input(event: InputEvent) -> void:
    if dead:return
    if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
        yaw-=event.relative.x*mouse_sensitivity;pitch=clampf(pitch-event.relative.y*mouse_sensitivity,-72.0,68.0);sway=event.relative*.0018
    elif event is InputEventMouseButton:
        if event.button_index==MOUSE_BUTTON_LEFT and event.pressed:_try_fire()
        elif event.button_index==MOUSE_BUTTON_RIGHT:aiming=event.pressed
    elif event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_ESCAPE:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
            KEY_R:_start_reload()
            KEY_F:_try_interact()
            KEY_H:
                if game and game.has_method("use_med"):game.use_med()
            KEY_1:_load_weapon(0)
            KEY_2:_load_weapon(1)
            KEY_3:_load_weapon(2)
            KEY_TAB:
                if game and game.has_method("toggle_raid_inventory"):game.toggle_raid_inventory()

func _process(delta: float) -> void:
    if dead:return
    fire_cooldown=maxf(0.0,fire_cooldown-delta)
    if reloading:
        reload_timer-=delta;weapon_anchor.rotation_degrees.z=lerpf(weapon_anchor.rotation_degrees.z,11.0,delta*8.0)
        if reload_timer<=0:_finish_reload()
    else:weapon_anchor.rotation_degrees.z=lerpf(weapon_anchor.rotation_degrees.z,0.0,delta*10.0)
    if bool(weapon_data.get("automatic",false)) and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):_try_fire()
    recoil_pitch=lerpf(recoil_pitch,0.0,delta*11.0);recoil_yaw=lerpf(recoil_yaw,0.0,delta*13.0);weapon_kick=lerpf(weapon_kick,0.0,delta*15.0)
    var target_fov:=48.0 if aiming else 70.0;camera.fov=lerpf(camera.fov,target_fov,delta*12.0)
    var hip:=Vector3(.33,-.34,-.72);var ads:=Vector3(.0,-.205,-.51);var target_pos:=ads if aiming else hip;target_pos.z+=weapon_kick
    weapon_anchor.position=weapon_anchor.position.lerp(target_pos,clampf(delta*13.0,0.0,1.0));weapon_anchor.rotation_degrees.x=lerpf(weapon_anchor.rotation_degrees.x,-sway.y*18.0,delta*8.0);weapon_anchor.rotation_degrees.y=lerpf(weapon_anchor.rotation_degrees.y,-sway.x*15.0,delta*8.0);sway=sway.lerp(Vector2.ZERO,clampf(delta*8.0,0,1));_scan_interaction();_emit_hud()

func _physics_process(delta: float) -> void:
    if dead:return
    if not is_on_floor():velocity+=get_gravity()*delta
    var input:=Vector2.ZERO
    if Input.is_key_pressed(KEY_A):input.x-=1
    if Input.is_key_pressed(KEY_D):input.x+=1
    if Input.is_key_pressed(KEY_W):input.y+=1
    if Input.is_key_pressed(KEY_S):input.y-=1
    input=input.normalized();crouched=Input.is_key_pressed(KEY_CTRL)
    var sprinting:=Input.is_key_pressed(KEY_SHIFT) and input.y>0.2 and stamina>4.0 and not aiming and not crouched
    var speed:=crouch_speed if crouched else (sprint_speed if sprinting else walk_speed)
    if sprinting:stamina=maxf(0.0,stamina-delta*17.0)
    else:stamina=minf(stamina_max,stamina+delta*11.0)
    var basis:=Basis(Vector3.UP,deg_to_rad(yaw));var dir:Vector3=(basis*Vector3(input.x,0,-input.y)).normalized();velocity.x=move_toward(velocity.x,dir.x*speed,delta*20.0);velocity.z=move_toward(velocity.z,dir.z*speed,delta*20.0);move_and_slide();rotation_degrees.y=yaw;neck.rotation_degrees.x=pitch-recoil_pitch;neck.rotation_degrees.y=recoil_yaw
    var moving:=Vector2(velocity.x,velocity.z).length()>0.4 and is_on_floor()
    if moving:
        bob_time+=delta*(10.5 if sprinting else 7.2);var amp:=.035 if sprinting else .022;neck.position.y=lerpf(neck.position.y,(1.22 if crouched else 1.62)+sin(bob_time)*amp,delta*12.0);neck.position.x=lerpf(neck.position.x,cos(bob_time*.5)*amp*.65,delta*10.0)
    else:
        neck.position.y=lerpf(neck.position.y,1.22 if crouched else 1.62,delta*10.0);neck.position.x=lerpf(neck.position.x,0.0,delta*8.0)

func _try_fire() -> void:
    if dead or reloading or fire_cooldown>0:return
    if ammo<=0:toast_requested.emit("MAGAZINE EMPTY");return
    ammo-=1;fire_cooldown=60.0/float(weapon_data.get("rpm",600.0));weapon_kick=.12 if current_weapon_index!=2 else .22;recoil_pitch+=0.65 if aiming else 1.05;recoil_yaw+=randf_range(-.22,.22);muzzle_mesh.visible=true;muzzle_light.light_energy=4.8
    get_tree().create_timer(.045).timeout.connect(func():
        if is_instance_valid(muzzle_mesh):muzzle_mesh.visible=false
        if is_instance_valid(muzzle_light):muzzle_light.light_energy=0.0)
    if shot_audio and shot_audio.stream:shot_audio.play()
    var pellets:=int(weapon_data.get("pellets",1));for i in pellets:_fire_ray(i,pellets);_emit_hud()

func _fire_ray(_i:int,pellets:int) -> void:
    var spread:=0.0025 if aiming else 0.009
    if pellets>1:spread=0.035
    var origin:=camera.global_position;var dir:=-camera.global_transform.basis.z;dir=(dir+camera.global_transform.basis.x*randf_range(-spread,spread)+camera.global_transform.basis.y*randf_range(-spread,spread)).normalized()
    var query:=PhysicsRayQueryParameters3D.create(origin,origin+dir*140.0);query.exclude=[get_rid()];query.collide_with_areas=true;query.collide_with_bodies=true
    var hit:=get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():return
    var collider=hit.get("collider")
    if collider and collider.has_method("take_damage"):
        var hp:Vector3=hit.get("position",Vector3.ZERO);var rel_y:=hp.y-collider.global_position.y;var headshot:=rel_y>1.7;var dmg:=float(weapon_data.get("damage",30.0))*(1.85 if headshot else 1.0);collider.take_damage(dmg,hp,headshot);if game and game.has_method("register_hit"):game.register_hit(headshot)
    elif game and game.has_method("spawn_impact"):game.spawn_impact(hit.get("position",Vector3.ZERO),hit.get("normal",Vector3.UP))

func _start_reload() -> void:
    if reloading or ammo>=int(weapon_data.get("mag",30)) or reserve<=0:return
    reloading=true;reload_timer=2.15 if current_weapon_index==2 else 1.55;toast_requested.emit("RELOADING")

func _finish_reload() -> void:
    reloading=false;var cap:=int(weapon_data.get("mag",30));var needed:=cap-ammo;var take:=mini(needed,reserve);ammo+=take;reserve-=take;toast_requested.emit("MAGAZINE SEATED")

func _scan_interaction() -> void:
    interaction_target=null;interaction_text="";var origin:=camera.global_position;var dir:=-camera.global_transform.basis.z;var q:=PhysicsRayQueryParameters3D.create(origin,origin+dir*3.2);q.exclude=[get_rid()];q.collide_with_areas=true;q.collide_with_bodies=true;var hit:=get_world_3d().direct_space_state.intersect_ray(q)
    if not hit.is_empty():
        var c=hit.get("collider")
        if c and c.has_method("get_interaction_prompt"):interaction_target=c;interaction_text=str(c.get_interaction_prompt())
    interaction_prompt.emit(interaction_text)

func _try_interact() -> void:
    if interaction_target and is_instance_valid(interaction_target) and interaction_target.has_method("interact"):interaction_target.interact(self)

func apply_damage(amount: float, body_part: String="thorax", armor_pen: float=.25) -> void:
    if dead:return
    var part:=body_part if body_health.has(body_part) else "thorax";var dmg:=amount
    if (part=="thorax" or part=="stomach") and armor>0:
        var absorbed:=minf(armor,dmg*(1.0-armor_pen)*.78);armor-=absorbed;dmg-=absorbed*.58
    body_health[part]=maxf(0.0,float(body_health[part])-dmg)
    if part=="head" and float(body_health[part])<=0:_die()
    if part=="thorax" and float(body_health[part])<=0:_die()
    var total:=0.0;for v in body_health.values():total+=float(v)
    if total<=80.0:_die()
    _emit_hud()

func heal(amount: float) -> void:
    for k in body_health.keys():body_health[k]=minf(float(max_health[k]),float(body_health[k])+amount/7.0)
    _emit_hud()

func _die() -> void:
    if dead:return
    dead=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;died.emit()

func _emit_hud() -> void:hud_state_changed.emit(get_hud_state())

func get_hud_state() -> Dictionary:
    var total:=0.0;var max_total:=0.0;for k in body_health.keys():total+=float(body_health[k]);max_total+=float(max_health[k])
    return {"hp":int(round(total/max_total*100.0)),"armor":int(round(armor)),"stamina":int(round(stamina)),"ammo":ammo,"reserve":reserve,"weapon":str(weapon_data.get("name","")),"caliber":str(weapon_data.get("caliber","")),"body":body_health.duplicate(),"body_max":max_health.duplicate(),"reloading":reloading,"reload_progress":0.0 if not reloading else 1.0-clampf(reload_timer/(2.15 if current_weapon_index==2 else 1.55),0.0,1.0)}
