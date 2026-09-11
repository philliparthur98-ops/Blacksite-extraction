class_name BlacksiteUI
extends CanvasLayer

signal deploy_requested
signal return_requested
signal quit_requested

const BG:=Color("061016")
const PANEL:=Color("0a161ee8")
const PANEL2:=Color("0d2029ee")
const LINE:=Color("385967a8")
const TEXT:=Color("edf4f5")
const MUTED:=Color("8499a1")
const CYAN:=Color("5bd4e8")
const GREEN:=Color("88d96f")
const ORANGE:=Color("e9a458")
const RED:=Color("ef6d65")

var menu:Control
var hud:Control
var result:Control
var raid_inventory:Control
var stash_grid:GridContainer
var stash_count:Label
var cash_label:Label
var operator_stats:Label
var inspector_title:Label
var inspector_meta:Label
var inspector_desc:Label
var inspector_value:Label
var raid_timer_label:Label
var objective_label:Label
var weapon_label:Label
var ammo_label:Label
var armor_bar:ProgressBar
var stamina_bar:ProgressBar
var prompt_label:Label
var toast_label:Label
var loot_label:Label
var hit_marker:Label
var result_title:Label
var result_copy:Label
var result_loot:VBoxContainer
var raid_bag_grid:GridContainer
var body_rows:Dictionary={}
var toast_tween:Tween

func _ready()->void:
    layer=20
    _build_menu()
    _build_hud()
    _build_result()
    _build_raid_inventory()

func _style(bg:Color=PANEL,border:Color=LINE,radius:int=8,width:int=1)->StyleBoxFlat:
    var s:=StyleBoxFlat.new()
    s.bg_color=bg;s.border_color=border
    s.border_width_left=width;s.border_width_right=width;s.border_width_top=width;s.border_width_bottom=width
    s.corner_radius_top_left=radius;s.corner_radius_top_right=radius;s.corner_radius_bottom_left=radius;s.corner_radius_bottom_right=radius
    s.content_margin_left=12;s.content_margin_right=12;s.content_margin_top=10;s.content_margin_bottom=10
    return s

func _label(t:String,size:int=14,color:Color=TEXT)->Label:
    var l:=Label.new();l.text=t;l.add_theme_font_size_override("font_size",size);l.add_theme_color_override("font_color",color);return l
func _small(t:String,color:Color=MUTED)->Label:return _label(t,10,color)
func _section(t:String)->Label:
    var l:=_label(t.to_upper(),10,Color("81adbd"));l.add_theme_constant_override("outline_size",2);return l
func _panel(bg:Color=PANEL,border:Color=LINE,radius:int=10)->PanelContainer:
    var p:=PanelContainer.new();p.add_theme_stylebox_override("panel",_style(bg,border,radius));return p
func _button(t:String,accent:=false)->Button:
    var b:=Button.new();b.text=t;b.custom_minimum_size=Vector2(0,46);b.add_theme_font_size_override("font_size",12)
    var bg:=Color("142832");var border:=LINE;var font:=TEXT
    if accent:bg=Color("83d76c");border=Color("a5ef92");font=Color("071006")
    b.add_theme_stylebox_override("normal",_style(bg,border,7));b.add_theme_stylebox_override("hover",_style(bg.lightened(.08),border.lightened(.12),7));b.add_theme_stylebox_override("pressed",_style(bg.darkened(.12),border,7));b.add_theme_color_override("font_color",font)
    return b
func _spacer(h:float=8.0)->Control:
    var c:=Control.new();c.custom_minimum_size=Vector2(1,h);return c

func _build_menu()->void:
    menu=Control.new();menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(menu)
    var bg:=ColorRect.new();bg.color=BG;bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);menu.add_child(bg)
    var glow:=ColorRect.new();glow.color=Color("12374570");glow.anchor_right=1.0;glow.offset_bottom=220;menu.add_child(glow)
    var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);margin.add_theme_constant_override("margin_left",28);margin.add_theme_constant_override("margin_right",28);margin.add_theme_constant_override("margin_top",20);margin.add_theme_constant_override("margin_bottom",24);menu.add_child(margin)
    var root:=VBoxContainer.new();root.add_theme_constant_override("separation",11);margin.add_child(root)
    var top:=HBoxContainer.new();top.add_theme_constant_override("separation",12);root.add_child(top)
    var title:=VBoxContainer.new();title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;top.add_child(title);title.add_child(_small("BLACKSITE CONTRACTOR NETWORK  //  SECURE LOCAL TERMINAL",Color("79a8b8")));title.add_child(_label("BLACKSITE  /  EXTRACTION",34,TEXT))
    cash_label=_label("$ 18,500",18,Color("b9e7ac"));cash_label.custom_minimum_size.x=170;cash_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;top.add_child(cash_label)
    var quit:=_button("QUIT");quit.custom_minimum_size=Vector2(90,44);quit.pressed.connect(func():quit_requested.emit());top.add_child(quit)
    var nav:=HBoxContainer.new();nav.add_theme_constant_override("separation",6);root.add_child(nav)
    for tab in ["DEPLOY","LOADOUT","STASH","CONTRACTS","HIDEOUT"]:
        var tb:=_button(tab);tb.custom_minimum_size=Vector2(120,34);tb.disabled=tab!="DEPLOY"
        if tab=="DEPLOY":tb.add_theme_stylebox_override("normal",_style(Color("15333d"),Color("4eafc3"),7))
        nav.add_child(tb)
    var body:=HBoxContainer.new();body.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",12);root.add_child(body)
    _menu_operator(body)
    _menu_contract(body)
    _menu_stash(body)

func _menu_operator(body:HBoxContainer)->void:
    var p:=_panel(Color("09151ce8"),LINE,12);p.custom_minimum_size.x=280;body.add_child(p)
    var v:=VBoxContainer.new();v.add_theme_constant_override("separation",9);p.add_child(v);v.add_child(_section("OPERATOR"))
    var portrait:=_panel(Color("132a34"),Color("3d6676"),9);portrait.custom_minimum_size.y=255;portrait.size_flags_vertical=Control.SIZE_EXPAND_FILL;v.add_child(portrait)
    var pv:=VBoxContainer.new();portrait.add_child(pv);var space:=Control.new();space.size_flags_vertical=Control.SIZE_EXPAND_FILL;pv.add_child(space);pv.add_child(_label("RAVEN-6",25,TEXT));pv.add_child(_small("PMC CONTRACTOR  ·  LVL 07"));pv.add_child(_label("●  COMBAT READY",11,GREEN))
    operator_stats=_label("0 EXTRACTIONS\n0 KIA\n0 KILLS",13,Color("cad6d9"));v.add_child(operator_stats)
    var note:=_small("FIELD NOTE\nPier 6 radio traffic stopped at 02:17. Last security log mentions Channel 4 and an unopened contractor archive.");note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;v.add_child(note)

func _menu_contract(body:HBoxContainer)->void:
    var p:=_panel(PANEL,LINE,12);p.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_child(p)
    var v:=VBoxContainer.new();v.add_theme_constant_override("separation",9);p.add_child(v)
    var h:=HBoxContainer.new();v.add_child(h);var text:=VBoxContainer.new();text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;h.add_child(text);text.add_child(_section("ACTIVE CONTRACT"));text.add_child(_label("BLACK TIDE",23,ORANGE));text.add_child(_small("Recover the encrypted archive drive. Extract through Gate 3."));h.add_child(_label("THREAT  HIGH",11,RED))
    var map:=_panel(Color("13252de8"),Color("4b7889"),10);map.size_flags_vertical=Control.SIZE_EXPAND_FILL;map.custom_minimum_size.y=250;v.add_child(map)
    var mv:=VBoxContainer.new();mv.add_theme_constant_override("separation",7);map.add_child(mv);mv.add_child(_label("HARBOR DISTRICT 07",29,TEXT));mv.add_child(_small("17:42 LOCAL  ·  12°C  ·  LOW CLOUD  ·  WIND WSW"));mv.add_child(_spacer(8))
    var d:=_label("Container lanes, working warehouses, abandoned triage and Pier 6 cargo infrastructure.",13,Color("bdcbd0"));d.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;mv.add_child(d)
    var intel:=_label("INTEL // Dock security logged a failed breach shortly before evacuation. Archive 3 remained powered after the district went dark.",12,Color("d8b789"));intel.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;mv.add_child(intel)
    var flex:=Control.new();flex.size_flags_vertical=Control.SIZE_EXPAND_FILL;mv.add_child(flex);mv.add_child(_label("[ INDUSTRIAL ]   [ CLOSE / MID RANGE ]   [ 15 MIN ]   [ LOOT: HIGH ]",10,CYAN))
    v.add_child(_section("RAID LOADOUT"));var grid:=GridContainer.new();grid.columns=4;grid.add_theme_constant_override("h_separation",7);v.add_child(grid);grid.add_child(_loadout_card("PRIMARY","M4A1 SOPMOD","5.56×45"));grid.add_child(_loadout_card("SIDEARM","G17 DUTY","9×19"));grid.add_child(_loadout_card("ARMOR","AEGIS IV","60 ARMOR"));grid.add_child(_loadout_card("MEDICAL","IFAK","4 USES"))
    var ready:=_panel(Color("0a1d15"),Color("547a4c"),8);var rv:=HBoxContainer.new();ready.add_child(rv);var rt:=_label("COMBAT EFFECTIVE  ·  18.4 KG  ·  PRIMARY INSURED",10,Color("b7dda9"));rt.size_flags_horizontal=Control.SIZE_EXPAND_FILL;rv.add_child(rt);rv.add_child(_label("78% READINESS",10,GREEN));v.add_child(ready)
    var deploy:=_button("DEPLOY TO HARBOR DISTRICT",true);deploy.custom_minimum_size.y=62;deploy.pressed.connect(func():deploy_requested.emit());v.add_child(deploy)

func _loadout_card(kind:String,name_:String,sub:String)->PanelContainer:
    var p:=_panel(Color("0a171e"),LINE,7);p.custom_minimum_size=Vector2(150,76);var v:=VBoxContainer.new();p.add_child(v);v.add_child(_small(kind,Color("7897a2")));v.add_child(_label(name_,11,TEXT));v.add_child(_small(sub,CYAN));return p

func _menu_stash(body:HBoxContainer)->void:
    var p:=_panel(Color("09141ce8"),LINE,12);p.custom_minimum_size.x=470;body.add_child(p)
    var v:=VBoxContainer.new();v.add_theme_constant_override("separation",7);p.add_child(v)
    var h:=HBoxContainer.new();v.add_child(h);var ht:=VBoxContainer.new();ht.size_flags_horizontal=Control.SIZE_EXPAND_FILL;h.add_child(ht);ht.add_child(_section("STASH"));ht.add_child(_label("READY GEAR",19,TEXT));stash_count=_small("0 / 60");h.add_child(stash_count)
    var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.custom_minimum_size.y=270;v.add_child(scroll);stash_grid=GridContainer.new();stash_grid.columns=3;stash_grid.add_theme_constant_override("h_separation",7);stash_grid.add_theme_constant_override("v_separation",7);scroll.add_child(stash_grid)
    v.add_child(_section("INSPECT"));var inspect:=_panel(Color("0b1820"),LINE,8);inspect.custom_minimum_size.y=170;v.add_child(inspect);var iv:=VBoxContainer.new();inspect.add_child(iv);inspector_title=_label("Select an item",16,TEXT);inspector_meta=_small("—");inspector_desc=_label("Select an item to inspect condition, weight and role.",11,MUTED);inspector_desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;inspector_desc.size_flags_vertical=Control.SIZE_EXPAND_FILL;inspector_value=_label("",11,GREEN);iv.add_child(inspector_title);iv.add_child(inspector_meta);iv.add_child(inspector_desc);iv.add_child(inspector_value)

func _build_hud()->void:
    hud=Control.new();hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);hud.visible=false;add_child(hud)
    var tl:=_panel(Color("071118d8"),LINE,8);tl.position=Vector2(18,18);tl.custom_minimum_size=Vector2(470,78);hud.add_child(tl);var tv:=VBoxContainer.new();tl.add_child(tv);raid_timer_label=_label("15:00",20,TEXT);objective_label=_small("BLACK TIDE // SECURE ARCHIVE DRIVE",Color("c9dade"));tv.add_child(raid_timer_label);tv.add_child(objective_label)
    var tr:=_panel(Color("071118d8"),LINE,8);tr.anchor_left=1.0;tr.anchor_right=1.0;tr.offset_left=-330;tr.offset_right=-18;tr.offset_top=18;tr.offset_bottom=96;hud.add_child(tr);var rv:=VBoxContainer.new();tr.add_child(rv);weapon_label=_small("M4A1 SOPMOD  ·  5.56×45",Color("9eb6bf"));weapon_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;ammo_label=_label("30  /  120",25,TEXT);ammo_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;rv.add_child(weapon_label);rv.add_child(ammo_label)
    var vitals:=_panel(Color("071118df"),LINE,8);vitals.anchor_top=1.0;vitals.anchor_bottom=1.0;vitals.offset_left=18;vitals.offset_top=-235;vitals.offset_right=345;vitals.offset_bottom=-18;hud.add_child(vitals);var vv:=VBoxContainer.new();vv.add_theme_constant_override("separation",5);vitals.add_child(vv);vv.add_child(_section("OPERATOR"))
    for part in ["head","thorax","stomach","left_arm","right_arm","left_leg","right_leg"]:_body_row(vv,part)
    armor_bar=_meter(60,Color("63a3c6"));vv.add_child(_small("ARMOR"));vv.add_child(armor_bar);stamina_bar=_meter(100,GREEN);vv.add_child(_small("STAMINA"));vv.add_child(stamina_bar)
    loot_label=_small("FIELD LOOT  0 ITEMS  ·  $0",Color("c3d2d6"));loot_label.anchor_top=1.0;loot_label.anchor_bottom=1.0;loot_label.offset_left=370;loot_label.offset_top=-48;loot_label.offset_right=790;loot_label.offset_bottom=-18;hud.add_child(loot_label)
    prompt_label=_label("",12,Color("e8f8f8"));prompt_label.anchor_left=.5;prompt_label.anchor_right=.5;prompt_label.anchor_top=.72;prompt_label.anchor_bottom=.72;prompt_label.offset_left=-300;prompt_label.offset_right=300;prompt_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hud.add_child(prompt_label)
    toast_label=_label("",12,TEXT);toast_label.anchor_left=.5;toast_label.anchor_right=.5;toast_label.anchor_top=.82;toast_label.anchor_bottom=.82;toast_label.offset_left=-320;toast_label.offset_right=320;toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hud.add_child(toast_label)
    hit_marker=_label("×",36,TEXT);hit_marker.anchor_left=.5;hit_marker.anchor_right=.5;hit_marker.anchor_top=.5;hit_marker.anchor_bottom=.5;hit_marker.offset_left=-22;hit_marker.offset_right=22;hit_marker.offset_top=-26;hit_marker.offset_bottom=26;hit_marker.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hit_marker.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;hit_marker.modulate.a=0;hud.add_child(hit_marker);_crosshair(hud)

func _meter(maxv:float,color:Color)->ProgressBar:
    var b:=ProgressBar.new();b.max_value=maxv;b.value=maxv;b.show_percentage=false;b.custom_minimum_size.y=6;b.add_theme_stylebox_override("background",_style(Color("152026"),Color.TRANSPARENT,3,0));b.add_theme_stylebox_override("fill",_style(color,Color.TRANSPARENT,3,0));return b
func _body_row(parent:VBoxContainer,part:String)->void:
    var row:=HBoxContainer.new();parent.add_child(row);var n:=_small(part.replace("_"," ").to_upper());n.custom_minimum_size.x=82;row.add_child(n);var bar:=_meter(100,GREEN);bar.custom_minimum_size.x=170;bar.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(bar);body_rows[part]=bar
func _crosshair(parent:Control)->void:
    var root:=Control.new();root.anchor_left=.5;root.anchor_right=.5;root.anchor_top=.5;root.anchor_bottom=.5;parent.add_child(root)
    for d in [Vector4(-18,-1,8,2),Vector4(10,-1,8,2),Vector4(-1,-18,2,8),Vector4(-1,10,2,8)]:
        var c:=ColorRect.new();c.color=Color("edf8f4cc");c.position=Vector2(d.x,d.y);c.size=Vector2(d.z,d.w);root.add_child(c)

func _build_result()->void:
    result=Control.new();result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);result.visible=false;add_child(result);var dim:=ColorRect.new();dim.color=Color("020609ed");dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);result.add_child(dim)
    var card:=_panel(Color("0b1720f7"),Color("426273"),12);card.anchor_left=.5;card.anchor_right=.5;card.anchor_top=.5;card.anchor_bottom=.5;card.offset_left=-430;card.offset_right=430;card.offset_top=-340;card.offset_bottom=340;result.add_child(card)
    var v:=VBoxContainer.new();v.add_theme_constant_override("separation",12);card.add_child(v);v.add_child(_section("AFTER ACTION REPORT"));result_title=_label("EXTRACTION SUCCESSFUL",30,GREEN);v.add_child(result_title);result_copy=_label("",13,Color("bac9cd"));result_copy.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;v.add_child(result_copy);v.add_child(HSeparator.new());v.add_child(_section("RECOVERED MATERIAL"));result_loot=VBoxContainer.new();result_loot.add_theme_constant_override("separation",4);result_loot.size_flags_vertical=Control.SIZE_EXPAND_FILL;v.add_child(result_loot);var ret:=_button("RETURN TO TERMINAL",true);ret.pressed.connect(func():return_requested.emit());v.add_child(ret)

func _build_raid_inventory()->void:
    raid_inventory=Control.new();raid_inventory.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);raid_inventory.visible=false;add_child(raid_inventory);var dim:=ColorRect.new();dim.color=Color("03070ac0");dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);raid_inventory.add_child(dim)
    var card:=_panel(Color("08151df7"),Color("385c6b"),12);card.anchor_left=.5;card.anchor_right=.5;card.anchor_top=.5;card.anchor_bottom=.5;card.offset_left=-570;card.offset_right=570;card.offset_top=-380;card.offset_bottom=380;raid_inventory.add_child(card);var v:=VBoxContainer.new();v.add_theme_constant_override("separation",10);card.add_child(v);var h:=HBoxContainer.new();v.add_child(h);var title:=_label("FIELD INVENTORY",24,TEXT);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;h.add_child(title);h.add_child(_small("TAB TO CLOSE"));v.add_child(_small("Items are secured only after extraction. Death forfeits all field loot."));var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;v.add_child(scroll);raid_bag_grid=GridContainer.new();raid_bag_grid.columns=5;raid_bag_grid.add_theme_constant_override("h_separation",8);raid_bag_grid.add_theme_constant_override("v_separation",8);scroll.add_child(raid_bag_grid)

func set_profile(profile:Dictionary)->void:
    if cash_label==null:return
    cash_label.text="$ %s"%str(profile.get("cash",0));operator_stats.text="%d EXTRACTIONS\n%d KIA\n%d KILLS"%[int(profile.get("extractions",0)),int(profile.get("deaths",0)),int(profile.get("kills",0))];_refresh_stash(profile)
func _refresh_stash(profile:Dictionary)->void:
    for c in stash_grid.get_children():c.queue_free()
    var stash:Array=profile.get("stash",[]);stash_count.text="%d / 60  ·  $%d"%[stash.size(),ItemDB.stash_value(stash)]
    for raw in stash:
        var id:=str(raw);var d:=ItemDB.get_item(id)
        if d.is_empty():continue
        var color:=ItemDB.rarity_color(str(d.get("rarity","common")));var b:=Button.new();b.custom_minimum_size=Vector2(138,108);b.text="%s\n%s\n$%d"%[str(d.get("name",id)),str(d.get("type","")),int(d.get("value",0))];b.alignment=HORIZONTAL_ALIGNMENT_LEFT;b.add_theme_font_size_override("font_size",10);b.add_theme_color_override("font_color",TEXT);b.add_theme_stylebox_override("normal",_style(Color("0b1820"),color.darkened(.35),7));b.add_theme_stylebox_override("hover",_style(Color("10232d"),color,7));b.pressed.connect(func():_inspect(id));stash_grid.add_child(b)
func _inspect(id:String)->void:
    var d:=ItemDB.get_item(id)
    if d.is_empty():return
    inspector_title.text=str(d.get("name",id));inspector_title.add_theme_color_override("font_color",ItemDB.rarity_color(str(d.get("rarity","common"))));inspector_meta.text="%s  ·  %.1f KG  ·  %s"%[str(d.get("type","")),float(d.get("weight",0)),str(d.get("caliber",str(d.get("rarity","")))).to_upper()];inspector_desc.text=_item_description(id,d);inspector_value.text="MARKET VALUE  $%d"%int(d.get("value",0))
func _item_description(id:String,d:Dictionary)->String:
    match id:
        "m4":return "Contractor-configured carbine with compact optic, weapon light and suppressor-ready muzzle. Balanced for Harbor sight lines."
        "g17":return "Reliable polymer sidearm carried as a contingency weapon when a primary goes dry."
        "m870":return "Pump shotgun configured for warehouse interiors and container lanes."
        "carrier":return "Low-profile plate carrier with ceramic inserts and integrated magazine cells."
        "gpu":return "High-value industrial compute module. Brokers pay heavily for intact control hardware."
        "intel":return "Stamped contractor documents containing shift routes, access windows and cargo manifests."
        _:return "%s. Field condition varies; extraction is required before it is added permanently to the stash."%str(d.get("name",id))

func show_menu(profile:Dictionary)->void:
    menu.visible=true;hud.visible=false;result.visible=false;raid_inventory.visible=false;set_profile(profile);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
func show_raid()->void:
    menu.visible=false;hud.visible=true;result.visible=false;raid_inventory.visible=false
func show_result(extracted:bool,stats:Dictionary,loot:Array)->void:
    hud.visible=false;raid_inventory.visible=false;result.visible=true;menu.visible=false;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;result_title.text="EXTRACTION SUCCESSFUL" if extracted else "OPERATOR LOST";result_title.add_theme_color_override("font_color",GREEN if extracted else RED)
    var value:=0
    for id in loot:value+=int(ItemDB.get_item(str(id)).get("value",0))
    if extracted:result_copy.text="Contract item secured. %d hostiles eliminated. %d hits / %d headshots. Field loot recovered at an estimated $%d."%[int(stats.get("kills",0)),int(stats.get("hits",0)),int(stats.get("headshots",0)),value]
    else:result_copy.text="Contract failed after %d eliminations. All unsecured field loot was lost."%int(stats.get("kills",0))
    for c in result_loot.get_children():c.queue_free()
    if loot.is_empty():result_loot.add_child(_small("NO FIELD LOOT RECOVERED"))
    else:
        for id in loot:
            var d:=ItemDB.get_item(str(id));var row:=HBoxContainer.new();var n:=_label(str(d.get("name",id)),12,ItemDB.rarity_color(str(d.get("rarity","common"))));n.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(n);row.add_child(_label("$%d"%int(d.get("value",0)),11,TEXT));result_loot.add_child(row)

func update_hud(state:Dictionary,raid_time:float,objective:String,loot:Array)->void:
    var sec:=int(maxf(raid_time,0.0));raid_timer_label.text="%02d:%02d"%[sec/60,sec%60];objective_label.text=objective.to_upper();ammo_label.text="%02d  /  %03d"%[int(state.get("ammo",0)),int(state.get("reserve",0))];weapon_label.text="%s  ·  %s"%[str(state.get("weapon","")),str(state.get("caliber",""))];stamina_bar.value=float(state.get("stamina",100));armor_bar.value=float(state.get("armor",0))
    var body:Dictionary=state.get("body",{});var body_max:Dictionary=state.get("body_max",{})
    for k in body_rows.keys():
        var bar:ProgressBar=body_rows[k];var ratio:=float(body.get(k,0))/maxf(float(body_max.get(k,1)),1.0);bar.value=ratio*100.0;bar.add_theme_stylebox_override("fill",_style(RED.lerp(GREEN,ratio),Color.TRANSPARENT,3,0))
    var value:=0
    for id in loot:value+=int(ItemDB.get_item(str(id)).get("value",0))
    loot_label.text="FIELD LOOT  %d ITEMS  ·  $%d"%[loot.size(),value]
func set_prompt(t:String)->void:prompt_label.text="[ F ]  "+t if t!="" else ""
func toast(t:String,color:Color=TEXT)->void:
    toast_label.text=t;toast_label.add_theme_color_override("font_color",color)
    if toast_tween and toast_tween.is_valid():toast_tween.kill()
    toast_label.modulate.a=1;toast_tween=create_tween();toast_tween.tween_interval(1.0);toast_tween.tween_property(toast_label,"modulate:a",0.0,.5)
func hit(headshot:=false)->void:
    hit_marker.text="✦" if headshot else "×";hit_marker.add_theme_color_override("font_color",ORANGE if headshot else TEXT);hit_marker.modulate.a=1;var tw:=create_tween();tw.tween_property(hit_marker,"modulate:a",0.0,.18)
func toggle_raid_inventory(loot:Array)->void:
    raid_inventory.visible=not raid_inventory.visible
    if raid_inventory.visible:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;_refresh_raid_bag(loot)
    else:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
func _refresh_raid_bag(loot:Array)->void:
    for c in raid_bag_grid.get_children():c.queue_free()
    if loot.is_empty():raid_bag_grid.add_child(_small("BACKPACK EMPTY"));return
    for id in loot:
        var d:=ItemDB.get_item(str(id));var p:=_panel(Color("0b1820"),ItemDB.rarity_color(str(d.get("rarity","common"))).darkened(.35),7);p.custom_minimum_size=Vector2(185,122);var v:=VBoxContainer.new();p.add_child(v);v.add_child(_small(str(d.get("type",""))));v.add_child(_label(str(d.get("name",id)),12,TEXT));v.add_child(_label("$%d  ·  %.1f KG"%[int(d.get("value",0)),float(d.get("weight",0))],10,ItemDB.rarity_color(str(d.get("rarity","common")))));raid_bag_grid.add_child(p)
