class_name BlacksiteUI
extends CanvasLayer

signal deploy_requested
signal return_requested
signal quit_requested

var menu: Control
var hud: Control
var result: Control
var raid_inventory: Control
var stash_grid: GridContainer
var inspector_title: Label
var inspector_meta: Label
var inspector_desc: Label
var inspector_value: Label
var operator_stats: Label
var cash_label: Label
var raid_timer_label: Label
var objective_label: Label
var ammo_label: Label
var weapon_label: Label
var stamina_bar: ProgressBar
var armor_bar: ProgressBar
var prompt_label: Label
var toast_label: Label
var loot_label: Label
var hit_marker: Label
var body_rows: Dictionary = {}
var result_title: Label
var result_copy: Label
var result_loot: VBoxContainer
var raid_bag_grid: GridContainer
var toast_tween: Tween

const BG=Color("071017")
const PANEL=Color("0b1720e8")
const LINE=Color("34516188")
const TEXT=Color("e8f0f2")
const MUTED=Color("8299a2")
const CYAN=Color("61d9ee")
const GREEN=Color("85d66e")
const ORANGE=Color("e6a257")
const RED=Color("ed6860")

func _ready() -> void:
    layer=20
    _build_menu()
    _build_hud()
    _build_result()
    _build_raid_inventory()
    show_menu(ProfileStore.default_profile())

func _style(bg:Color=PANEL,border:Color=LINE,radius:=10,width:=1)->StyleBoxFlat:
    var s:=StyleBoxFlat.new()
    s.bg_color=bg;s.border_color=border
    s.border_width_left=width;s.border_width_right=width;s.border_width_top=width;s.border_width_bottom=width
    s.corner_radius_top_left=radius;s.corner_radius_top_right=radius;s.corner_radius_bottom_left=radius;s.corner_radius_bottom_right=radius
    s.content_margin_left=12;s.content_margin_right=12;s.content_margin_top=10;s.content_margin_bottom=10
    return s

func _panel(bg:Color=PANEL,border:Color=LINE,radius:=10)->PanelContainer:
    var p:=PanelContainer.new();p.add_theme_stylebox_override("panel",_style(bg,border,radius));return p
func _label(text_:String,size:=14,color:Color=TEXT)->Label:
    var l:=Label.new();l.text=text_;l.add_theme_font_size_override("font_size",size);l.add_theme_color_override("font_color",color);return l
func _small(text_:String)->Label:return _label(text_,10,MUTED)
func _section(text_:String)->Label:return _label(text_.to_upper(),10,Color("7fa8b8"))
func _spacer(h:=8)->Control:var c:=Control.new();c.custom_minimum_size=Vector2(1,h);return c
func _button(text_:String,accent:=false)->Button:
    var b:=Button.new();b.text=text_;b.custom_minimum_size=Vector2(0,48);b.add_theme_font_size_override("font_size",12)
    var col:=GREEN if accent else Color("152732");var border:=Color("9bdb89") if accent else LINE
    b.add_theme_stylebox_override("normal",_style(col,border,8));b.add_theme_stylebox_override("hover",_style(col.lightened(.09),border.lightened(.12),8));b.add_theme_stylebox_override("pressed",_style(col.darkened(.12),border,8));b.add_theme_color_override("font_color",Color("09100c") if accent else TEXT);return b

func _build_menu()->void:
    menu=Control.new();menu.name="Menu";menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(menu)
    var bg:=ColorRect.new();bg.color=BG;bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);menu.add_child(bg)
    var glow:=ColorRect.new();glow.color=Color("0d2c3a55");glow.position=Vector2.ZERO;glow.size=Vector2(1920,280);menu.add_child(glow)
    var outer:=MarginContainer.new();outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);outer.add_theme_constant_override("margin_left",28);outer.add_theme_constant_override("margin_right",28);outer.add_theme_constant_override("margin_top",22);outer.add_theme_constant_override("margin_bottom",24);menu.add_child(outer)
    var root:=VBoxContainer.new();root.add_theme_constant_override("separation",13);outer.add_child(root)
    var top:=HBoxContainer.new();top.add_theme_constant_override("separation",12);root.add_child(top)
    var titlebox:=VBoxContainer.new();titlebox.size_flags_horizontal=Control.SIZE_EXPAND_FILL;top.add_child(titlebox);titlebox.add_child(_small("BLACKSITE CONTRACTOR NETWORK  //  LOCAL SECURE NODE"));titlebox.add_child(_label("BLACKSITE  /  EXTRACTION",34,TEXT))
    cash_label=_label("$ 18,500",18,Color("b8eaa7"));cash_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;cash_label.custom_minimum_size.x=170;top.add_child(cash_label)
    var quit:=_button("QUIT",false);quit.custom_minimum_size=Vector2(100,45);quit.pressed.connect(func():quit_requested.emit());top.add_child(quit)
    var nav:=HBoxContainer.new();nav.add_theme_constant_override("separation",7);root.add_child(nav)
    for t in ["DEPLOY","LOADOUT","STASH","CONTRACTS","HIDEOUT"]:
        var b:=_button(t,false);b.custom_minimum_size=Vector2(122,34);b.disabled=t!="DEPLOY";if t=="DEPLOY":b.add_theme_stylebox_override("normal",_style(Color("14303b"),Color("4aaac0"),7));nav.add_child(b)
    root.add_child(HSeparator.new())
    var body:=HBoxContainer.new();body.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",12);root.add_child(body)
    var op:=_panel(Color("0a151de8"),LINE,12);op.custom_minimum_size.x=285;body.add_child(op);var ov:=VBoxContainer.new();ov.add_theme_constant_override("separation",10);op.add_child(ov);ov.add_child(_section("OPERATOR"))
    var portrait:=_panel(Color("16242b"),Color("355768"),9);portrait.custom_minimum_size.y=250;ov.add_child(portrait);var pv:=VBoxContainer.new();portrait.add_child(pv);var callsign:=_label("RAVEN-6",25,TEXT);callsign.vertical_alignment=VERTICAL_ALIGNMENT_BOTTOM;callsign.size_flags_vertical=Control.SIZE_EXPAND_FILL;pv.add_child(callsign);pv.add_child(_small("PMC CONTRACTOR  ·  LVL 07"));pv.add_child(_label("●  READY",12,GREEN))
    operator_stats=_label("0 EXTRACTIONS\n0 KIA\n0 KILLS",13,TEXT);ov.add_child(operator_stats);var opnote:=_small("FIELD NOTE\nPier 6 radio traffic stopped at 02:17. Gate 3 remains under contractor control.");opnote.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;opnote.size_flags_vertical=Control.SIZE_EXPAND_FILL;ov.add_child(opnote)
    var center:=_panel(PANEL,LINE,12);center.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_child(center);var cv:=VBoxContainer.new();cv.add_theme_constant_override("separation",9);center.add_child(cv)
    var contract:=HBoxContainer.new();cv.add_child(contract);var cl:=VBoxContainer.new();cl.size_flags_horizontal=Control.SIZE_EXPAND_FILL;contract.add_child(cl);cl.add_child(_section("ACTIVE CONTRACT"));cl.add_child(_label("BLACK TIDE",22,ORANGE));cl.add_child(_small("Recover the encrypted archive drive. Extract through Gate 3."));contract.add_child(_label("THREAT  HIGH",11,RED))
    var map:=_panel(Color("14252de8"),Color("4b7889"),10);map.size_flags_vertical=Control.SIZE_EXPAND_FILL;map.custom_minimum_size.y=260;cv.add_child(map);var mv:=VBoxContainer.new();mv.add_theme_constant_override("separation",5);map.add_child(mv);mv.add_child(_label("HARBOR DISTRICT 07",29,TEXT));mv.add_child(_small("17:42 LOCAL  ·  12°C  ·  LOW CLOUD  ·  WIND FROM WSW"));mv.add_child(_spacer(8));var desc:=_label("Container lanes, brick warehouses, abandoned triage station and Pier 6 cargo apron.",13,Color("b7c7cc"));desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;mv.add_child(desc);mv.add_child(_spacer(6));var story:=_label("INTEL // Dock security logged a failed breach twenty minutes before the evacuation order. A contractor archive server remained online after the district went dark.",12,Color("d6b486"));story.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;mv.add_child(story);var tags:=_label("[ INDUSTRIAL ]   [ CLOSE / MID RANGE ]   [ 15–20 MIN ]   [ LOOT: HIGH ]",10,CYAN);tags.size_flags_vertical=Control.SIZE_EXPAND_FILL;tags.vertical_alignment=VERTICAL_ALIGNMENT_BOTTOM;mv.add_child(tags)
    cv.add_child(_section("RAID LOADOUT"));var load:=GridContainer.new();load.columns=4;load.add_theme_constant_override("h_separation",7);load.add_theme_constant_override("v_separation",7);cv.add_child(load)
    for d in [["PRIMARY","M4A1 SOPMOD","5.56×45"],["SIDEARM","G17 DUTY","9×19"],["ARMOR","AEGIS IV","60 ARMOR"],["MEDICAL","IFAK","4 USES"]]:load.add_child(_loadout_card(d[0],d[1],d[2]))
    var ready:=_panel(Color("0b1b15"),Color("53754c"),8);var rv:=HBoxContainer.new();ready.add_child(rv);var rtxt:=_label("COMBAT EFFECTIVE  ·  18.4 KG  ·  INSURED PRIMARY",10,Color("b4dca7"));rtxt.size_flags_horizontal=Control.SIZE_EXPAND_FILL;rv.add_child(rtxt);rv.add_child(_label("78% READINESS",10,GREEN));cv.add_child(ready);var deploy:=_button("DEPLOY TO HARBOR DISTRICT",true);deploy.custom_minimum_size.y=64;deploy.pressed.connect(func():deploy_requested.emit());cv.add_child(deploy)
    var stash:=_panel(Color("09141ce8"),LINE,12);stash.custom_minimum_size.x=465;body.add_child(stash);var sv:=VBoxContainer.new();sv.add_theme_constant_override("separation",7);stash.add_child(sv);var sh:=HBoxContainer.new();sv.add_child(sh);var sht:=VBoxContainer.new();sht.size_flags_horizontal=Control.SIZE_EXPAND_FILL;sh.add_child(sht);sht.add_child(_section("STASH"));sht.add_child(_label("READY GEAR",19,TEXT));var sval:=_small("0 / 60");sval.name="StashCount";sh.add_child(sval)
    var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;sv.add_child(scroll);stash_grid=GridContainer.new();stash_grid.columns=3;stash_grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;stash_grid.add_theme_constant_override("h_separation",6);stash_grid.add_theme_constant_override("v_separation",6);scroll.add_child(stash_grid)
    var inspect:=_panel(Color("0c1d26"),Color("355664"),8);inspect.custom_minimum_size.y=122;sv.add_child(inspect);var iv:=VBoxContainer.new();inspect.add_child(iv);inspector_title=_label("SELECT AN ITEM",15,TEXT);iv.add_child(inspector_title);inspector_meta=_small("CATEGORY  ·  CONDITION  ·  WEIGHT");iv.add_child(inspector_meta);inspector_desc=_small("Inspect stash gear to view field information.");inspector_desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;iv.add_child(inspector_desc);inspector_value=_label("",12,GREEN);iv.add_child(inspector_value)

func _loadout_card(type_:String,name_:String,sub:String)->PanelContainer:
    var p:=_panel(Color("0b171f"),Color("2e4a57"),8);p.custom_minimum_size=Vector2(0,76);var v:=VBoxContainer.new();p.add_child(v);v.add_child(_small(type_));v.add_child(_label(name_,11,TEXT));v.add_child(_label(sub,9,Color("7bc8d8")));return p

func _build_hud()->void:
    hud=Control.new();hud.name="HUD";hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);hud.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(hud);hud.visible=false
    var top_left:=_panel(Color("061016bb"),Color("37576766"),8);top_left.position=Vector2(22,20);top_left.custom_minimum_size=Vector2(390,78);hud.add_child(top_left);var tlv:=VBoxContainer.new();top_left.add_child(tlv);var r:=HBoxContainer.new();tlv.add_child(r);raid_timer_label=_label("20:00",18,TEXT);r.add_child(raid_timer_label);var zone:=_label("HARBOR // DISTRICT 07",10,CYAN);zone.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;zone.size_flags_horizontal=Control.SIZE_EXPAND_FILL;r.add_child(zone);objective_label=_label("BLACK TIDE · RECOVER ARCHIVE DRIVE",10,Color("d9b879"));tlv.add_child(objective_label)
    var body:=_panel(Color("061016c8"),Color("37576766"),8);body.position=Vector2(22,690);body.custom_minimum_size=Vector2(330,330);hud.add_child(body);var bv:=VBoxContainer.new();body.add_child(bv);bv.add_child(_section("VITALS / TRAUMA"));for part in ["head","thorax","stomach","left_arm","right_arm","left_leg","right_leg"]:_body_row(bv,part)
    armor_bar=ProgressBar.new();armor_bar.max_value=60;armor_bar.value=60;armor_bar.show_percentage=false;armor_bar.custom_minimum_size.y=7;bv.add_child(_small("ARMOR"));bv.add_child(armor_bar);stamina_bar=ProgressBar.new();stamina_bar.max_value=100;stamina_bar.value=100;stamina_bar.show_percentage=false;stamina_bar.custom_minimum_size.y=6;bv.add_child(_small("STAMINA"));bv.add_child(stamina_bar)
    var gun:=_panel(Color("061016c8"),Color("37576766"),8);gun.position=Vector2(1570,820);gun.custom_minimum_size=Vector2(320,150);hud.add_child(gun);var gv:=VBoxContainer.new();gun.add_child(gv);weapon_label=_small("M4A1 SOPMOD · 5.56×45");gv.add_child(weapon_label);ammo_label=_label("30  /  120",34,TEXT);ammo_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;gv.add_child(ammo_label);loot_label=_label("FIELD LOOT  $0",10,GREEN);loot_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;gv.add_child(loot_label)
    prompt_label=_label("",12,TEXT);prompt_label.position=Vector2(620,800);prompt_label.size=Vector2(680,50);prompt_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;prompt_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;hud.add_child(prompt_label);toast_label=_label("",12,Color("d8edf1"));toast_label.position=Vector2(640,735);toast_label.size=Vector2(640,45);toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;toast_label.modulate.a=0;hud.add_child(toast_label);hit_marker=_label("×",32,Color("eefbff"));hit_marker.position=Vector2(930,498);hit_marker.modulate.a=0;hud.add_child(hit_marker);_crosshair(hud)

func _body_row(parent:VBoxContainer,part:String)->void:
    var r:=HBoxContainer.new();parent.add_child(r);var n:=_small(part.replace("_"," ").to_upper());n.custom_minimum_size.x=78;r.add_child(n);var bar:=ProgressBar.new();bar.max_value=100;bar.value=100;bar.show_percentage=false;bar.custom_minimum_size=Vector2(160,6);bar.size_flags_horizontal=Control.SIZE_EXPAND_FILL;r.add_child(bar);body_rows[part]=bar
func _crosshair(parent:Control)->void:
    var root:=Control.new();root.position=Vector2(960,540);parent.add_child(root);for d in [[-16,-1,8,2],[8,-1,8,2],[-1,-16,2,8],[-1,8,2,8]]:var c:=ColorRect.new();c.color=Color("edf8f4cc");c.position=Vector2(d[0],d[1]);c.size=Vector2(d[2],d[3]);root.add_child(c)

func _build_result()->void:
    result=Control.new();result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(result);result.visible=false;var dim:=ColorRect.new();dim.color=Color("020609e8");dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);result.add_child(dim);var card:=_panel(Color("0b1720f7"),Color("426273"),12);card.position=Vector2(510,210);card.custom_minimum_size=Vector2(900,650);result.add_child(card);var v:=VBoxContainer.new();v.add_theme_constant_override("separation",12);card.add_child(v);v.add_child(_section("AFTER ACTION REPORT"));result_title=_label("EXTRACTION SUCCESSFUL",30,GREEN);v.add_child(result_title);result_copy=_label("",13,Color("bac9cd"));result_copy.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;v.add_child(result_copy);v.add_child(HSeparator.new());v.add_child(_section("RECOVERED MATERIAL"));result_loot=VBoxContainer.new();result_loot.size_flags_vertical=Control.SIZE_EXPAND_FILL;v.add_child(result_loot);var ret:=_button("RETURN TO TERMINAL",true);ret.pressed.connect(func():return_requested.emit());v.add_child(ret)
func _build_raid_inventory()->void:
    raid_inventory=Control.new();raid_inventory.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);raid_inventory.visible=false;add_child(raid_inventory);var dim:=ColorRect.new();dim.color=Color("03070aaf");dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);raid_inventory.add_child(dim);var card:=_panel(Color("08151df5"),Color("385c6b"),12);card.position=Vector2(390,130);card.custom_minimum_size=Vector2(1140,760);raid_inventory.add_child(card);var v:=VBoxContainer.new();card.add_child(v);v.add_child(_label("FIELD INVENTORY",24,TEXT));v.add_child(_small("Items are secured only after extraction. TAB closes this screen."));var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;v.add_child(scroll);raid_bag_grid=GridContainer.new();raid_bag_grid.columns=5;scroll.add_child(raid_bag_grid)

func set_profile(profile:Dictionary)->void:
    cash_label.text="$ %s"%str(profile.get("cash",0));operator_stats.text="%d EXTRACTIONS\n%d KIA\n%d KILLS"%[int(profile.get("extractions",0)),int(profile.get("deaths",0)),int(profile.get("kills",0))];_refresh_stash(profile)
func _refresh_stash(profile:Dictionary)->void:
    for c in stash_grid.get_children():c.queue_free()
    var stash:Array=profile.get("stash",[]);var count:=menu.find_child("StashCount",true,false) as Label;if count:count.text="%d / 60  ·  $%d"%[stash.size(),ItemDB.stash_value(stash)]
    for raw in stash:
        var id:=str(raw);var d:=ItemDB.get_item(id);if d.is_empty():continue;var color:=ItemDB.rarity_color(str(d.get("rarity","common")));var b:=Button.new();b.custom_minimum_size=Vector2(132,105);b.text="%s\n%s\n$%d"%[str(d.get("name",id)),str(d.get("type","")),int(d.get("value",0))];b.alignment=HORIZONTAL_ALIGNMENT_LEFT;b.add_theme_font_size_override("font_size",10);b.add_theme_stylebox_override("normal",_style(Color("0b1820"),color.darkened(.35),7));b.add_theme_stylebox_override("hover",_style(Color("10232d"),color,7));b.pressed.connect(func():_inspect(id));stash_grid.add_child(b)
func _inspect(id:String)->void:
    var d:=ItemDB.get_item(id);if d.is_empty():return;inspector_title.text=str(d.get("name",id));inspector_title.add_theme_color_override("font_color",ItemDB.rarity_color(str(d.get("rarity","common"))));inspector_meta.text="%s  ·  %.1f KG  ·  %s"%[str(d.get("type","")),float(d.get("weight",0)),str(d.get("caliber",str(d.get("rarity","")))).to_upper()];inspector_desc.text=_item_description(id,d);inspector_value.text="MARKET VALUE  $%d"%int(d.get("value",0))
func _item_description(id:String,d:Dictionary)->String:
    match id:
        "m4":return "Contractor-configured carbine with compact optic, weapon light and suppressor-ready muzzle. Balanced for Harbor sight lines."
        "g17":return "Reliable polymer sidearm carried as a contingency weapon when a primary goes dry."
        "m870":return "Pump shotgun configured for warehouse interiors and close container lanes."
        "carrier":return "Low-profile plate carrier with ceramic inserts and integrated magazine cells."
        "gpu":return "High-value industrial compute module. Brokers pay heavily for intact control hardware."
        "intel":return "Stamped contractor documents containing shift routes, access windows and cargo manifests."
        _:return "%s. Field condition varies; extraction is required before the item is added permanently to the stash."%str(d.get("name",id))

func show_menu(profile:Dictionary)->void:menu.visible=true;hud.visible=false;result.visible=false;raid_inventory.visible=false;set_profile(profile);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
func show_raid()->void:menu.visible=false;hud.visible=true;result.visible=false;raid_inventory.visible=false
func show_result(extracted:bool,stats:Dictionary,loot:Array)->void:
    hud.visible=false;raid_inventory.visible=false;result.visible=true;menu.visible=false;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;result_title.text="EXTRACTION SUCCESSFUL" if extracted else "OPERATOR LOST";result_title.add_theme_color_override("font_color",GREEN if extracted else RED);var value:=0;for id in loot:value+=int(ItemDB.get_item(str(id)).get("value",0));result_copy.text=("Contract item secured. %d hostiles eliminated. Field loot recovered at an estimated $%d."%[int(stats.get("kills",0)),value]) if extracted else ("Contract failed after %d eliminations. All unsecured field loot was lost."%int(stats.get("kills",0)));for c in result_loot.get_children():c.queue_free();if loot.is_empty():result_loot.add_child(_small("NO FIELD LOOT RECOVERED"))
    else:
        for id in loot:var d:=ItemDB.get_item(str(id));var row:=HBoxContainer.new();var nm:=_label(str(d.get("name",id)),12,ItemDB.rarity_color(str(d.get("rarity","common"))));nm.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(nm);row.add_child(_label("$%d"%int(d.get("value",0)),11,TEXT));result_loot.add_child(row)
func update_hud(state:Dictionary,raid_time:float,objective:String,loot:Array)->void:
    var m:=int(maxf(raid_time,0))/60;var s:=int(maxf(raid_time,0))%60;raid_timer_label.text="%02d:%02d"%[m,s];objective_label.text=objective.to_upper();ammo_label.text="%02d  /  %03d"%[int(state.get("ammo",0)),int(state.get("reserve",0))];weapon_label.text="%s  ·  %s"%[str(state.get("weapon","")),str(state.get("caliber",""))];stamina_bar.value=float(state.get("stamina",100));armor_bar.value=float(state.get("armor",0));var body:Dictionary=state.get("body",{});var bm:Dictionary=state.get("body_max",{});for k in body_rows.keys():var bar:ProgressBar=body_rows[k];bar.value=float(body.get(k,0))/maxf(float(bm.get(k,1)),1)*100.0;var value:=0;for id in loot:value+=int(ItemDB.get_item(str(id)).get("value",0));loot_label.text="FIELD LOOT  %d ITEMS  ·  $%d"%[loot.size(),value]
func set_prompt(text_:String)->void:prompt_label.text=("[ F ]  "+text_) if text_!="" else ""
func toast(text_:String,color:Color=TEXT)->void:
    toast_label.text=text_;toast_label.add_theme_color_override("font_color",color);if toast_tween and toast_tween.is_valid():toast_tween.kill();toast_label.modulate.a=1.0;toast_tween=create_tween();toast_tween.tween_interval(1.0);toast_tween.tween_property(toast_label,"modulate:a",0.0,.5)
func hit(headshot:=false)->void:
    hit_marker.text="✦" if headshot else "×";hit_marker.add_theme_color_override("font_color",ORANGE if headshot else TEXT);hit_marker.modulate.a=1.0;var tw:=create_tween();tw.tween_property(hit_marker,"modulate:a",0.0,.18)
func toggle_raid_inventory(loot:Array)->void:
    raid_inventory.visible=not raid_inventory.visible
    if raid_inventory.visible:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;_refresh_raid_bag(loot)
    else:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
func _refresh_raid_bag(loot:Array)->void:
    for c in raid_bag_grid.get_children():c.queue_free()
    if loot.is_empty():var l:=_small("BACKPACK EMPTY");raid_bag_grid.add_child(l);return
    for id in loot:var d:=ItemDB.get_item(str(id));var p:=_panel(Color("0b1820"),ItemDB.rarity_color(str(d.get("rarity","common"))).darkened(.35),7);p.custom_minimum_size=Vector2(180,120);var v:=VBoxContainer.new();p.add_child(v);v.add_child(_small(str(d.get("type",""))));v.add_child(_label(str(d.get("name",id)),12,TEXT));v.add_child(_label("$%d  ·  %.1f KG"%[int(d.get("value",0)),float(d.get("weight",0))],10,ItemDB.rarity_color(str(d.get("rarity","common")))));raid_bag_grid.add_child(p)
