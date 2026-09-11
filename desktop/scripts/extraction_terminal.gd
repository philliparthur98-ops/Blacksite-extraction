class_name ExtractionTerminal
extends Area3D

var game: Node
var enabled_for_extract := false

func configure(game_: Node) -> void:
    game=game_;name="Gate3Extraction";collision_layer=4;collision_mask=0
    var shape:=CollisionShape3D.new();var bs:=BoxShape3D.new();bs.size=Vector3(4,3,2);shape.shape=bs;add_child(shape)
    var pole:=MeshInstance3D.new();var pm:=CylinderMesh.new();pm.top_radius=.12;pm.bottom_radius=.12;pm.height=3.3;pole.mesh=pm;pole.position.y=1.65
    var mat:=StandardMaterial3D.new();mat.albedo_color=Color("17434b");mat.emission_enabled=true;mat.emission=Color("55e3ec");mat.emission_energy_multiplier=2.3;pole.material_override=mat;add_child(pole)
    var label:=Label3D.new();label.text="GATE 3\nEXTRACTION";label.font_size=28;label.position=Vector3(0,2.5,0);label.modulate=Color("83f4f5");label.outline_size=6;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;add_child(label)

func get_interaction_prompt() -> String:
    if enabled_for_extract:
        return "EXTRACT · GATE 3"
    return "GATE 3 LOCKED · CONTRACT ITEM REQUIRED"

func interact(_player: Node) -> void:
    if game and enabled_for_extract and game.has_method("request_extract"):
        game.request_extract()
