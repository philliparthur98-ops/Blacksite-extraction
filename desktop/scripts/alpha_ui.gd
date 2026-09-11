class_name BlacksiteAlphaUI
extends BlacksiteUI

signal buy_requested(item_id: String)
signal sell_requested(item_id: String)
signal equip_requested(slot: String, item_id: String)
signal contract_requested(contract_id: String)
signal hideout_upgrade_requested
signal settings_requested(settings: Dictionary)

var alpha_root: Control
var alpha_content: VBoxContainer
var alpha_profile: Dictionary = {}
var current_tab: String = "DEPLOY"
var header_cash: Label
var header_level: Label
var header_stash: Label
var status_label: Label

const CONTRACTS := {
    "black_tide": {"name":"BLACK TIDE","desc":"Recover the encrypted archive drive and extract.","reward":4200,"xp":650,"unlock":1},
    "clean_sweep": {"name":"CLEAN SWEEP","desc":"Eliminate at least 4 hostiles and extract.","reward":3400,"xp":520,"unlock":2},
    "salvage": {"name":"SALVAGE RIGHTS","desc":"Extract with at least 3 non-contract loot items.","reward":3000,"xp":460,"unlock":2},
    "no_trace": {"name":"NO TRACE","desc":"Land 2 headshots and extract alive.","reward":5000,"xp":800,"unlock":3}
}

func _ready() -> void:
    super._ready()
    if menu:
        menu.visible = false
    _build_alpha_terminal()
    alpha_root.visible = true

func _build_alpha_terminal() -> void:
    alpha_root = Control.new()
    alpha_root.name = "AlphaTerminal"
    alpha_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(alpha_root)

    var bg := ColorRect.new()
    bg.color = Color("050b10")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    alpha_root.add_child(bg)

    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left",28)
    margin.add_theme_constant_override("margin_right",28)
    margin.add_theme_constant_override("margin_top",22)
    margin.add_theme_constant_override("margin_bottom",22)
    alpha_root.add_child(margin)

    var root := VBoxContainer.new()
    root.add_theme_constant_override("separation",12)
    margin.add_child(root)

    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation",14)
    root.add_child(header)
    var title := VBoxContainer.new()
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)
    title.add_child(_small("BLACKSITE CONTRACTOR NETWORK // FULL ALPHA",Color("78a9b8")))
    title.add_child(_label("OPERATIONS TERMINAL",31,TEXT))
    header_cash = _label("$0",18,GREEN)
    header_level = _label("LVL 1",14,CYAN)
    header_stash = _small("STASH 0")
    header.add_child(header_level)
    header.add_child(header_cash)
    header.add_child(header_stash)
    var quit := _button("QUIT")
    quit.custom_minimum_size.x = 90
    quit.pressed.connect(func(): quit_requested.emit())
    header.add_child(quit)

    var nav := HBoxContainer.new()
    nav.add_theme_constant_override("separation",6)
    root.add_child(nav)
    for tab in ["DEPLOY","LOADOUT","STASH","TRADER","CONTRACTS","HIDEOUT","SETTINGS"]:
        var b := _button(tab)
        b.custom_minimum_size = Vector2(112,36)
        b.pressed.connect(func(t:=tab): _show_tab(t))
        nav.add_child(b)

    var content_panel := _panel(Color("08141be8"),LINE,12)
    content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(content_panel)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content_panel.add_child(scroll)
    alpha_content = VBoxContainer.new()
    alpha_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    alpha_content.add_theme_constant_override("separation",10)
    scroll.add_child(alpha_content)

    status_label = _small("READY",Color("89b6c2"))
    root.add_child(status_label)
    _show_tab("DEPLOY")

func _clear_content() -> void:
    if alpha_content == null:
        return
    for child in alpha_content.get_children():
        child.queue_free()

func _show_tab(tab: String) -> void:
    current_tab = tab
    _clear_content()
    match tab:
        "DEPLOY": _build_deploy_tab()
        "LOADOUT": _build_loadout_tab()
        "STASH": _build_stash_tab()
        "TRADER": _build_trader_tab()
        "CONTRACTS": _build_contracts_tab()
        "HIDEOUT": _build_hideout_tab()
        "SETTINGS": _build_settings_tab()
    _refresh_header()

func _refresh_header() -> void:
    if header_cash == null:
        return
    header_cash.text = "$%,d" % int(alpha_profile.get("cash",0))
    header_level.text = "LVL %d" % int(alpha_profile.get("level",1))
    var stash: Array = alpha_profile.get("stash",[])
    header_stash.text = "STASH %d / 80" % stash.size()

func _card(title_: String, body_: String, accent: Color = CYAN) -> PanelContainer:
    var p := _panel(Color("0a1820"),Color(accent,0.42),9)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation",5)
    p.add_child(v)
    v.add_child(_label(title_,16,TEXT))
    var body := _label(body_,11,Color("b7c7cc"))
    body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    v.add_child(body)
    return p

func _build_deploy_tab() -> void:
    alpha_content.add_child(_section("CURRENT OPERATION"))
    var active := str(alpha_profile.get("active_contract","black_tide"))
    var c: Dictionary = CONTRACTS.get(active,CONTRACTS["black_tide"])
    var summary := _card(str(c.get("name","BLACK TIDE")),str(c.get("desc","")),ORANGE)
    summary.custom_minimum_size.y = 150
    alpha_content.add_child(summary)

    var stats := HBoxContainer.new()
    stats.add_theme_constant_override("separation",8)
    alpha_content.add_child(stats)
    stats.add_child(_card("OPERATOR","Level %d\nXP %d\n%d extractions" % [int(alpha_profile.get("level",1)),int(alpha_profile.get("xp",0)),int(alpha_profile.get("extractions",0))],CYAN))
    stats.add_child(_card("HARBOR DISTRICT 07","15 minute raid\nHigh-value industrial salvage\nMultiple hostile archetypes",Color("7da0ac")))
    stats.add_child(_card("ACTIVE LOADOUT",_loadout_summary(),GREEN))

    var deploy := _button("DEPLOY TO HARBOR DISTRICT",true)
    deploy.custom_minimum_size.y = 64
    deploy.pressed.connect(func(): deploy_requested.emit())
    alpha_content.add_child(deploy)

func _loadout_summary() -> String:
    var l: Dictionary = alpha_profile.get("loadout",{})
    var parts: Array[String] = []
    for key in ["primary","sidearm","armor","med"]:
        var id := str(l.get(key,""))
        parts.append("%s: %s" % [key.capitalize(),str(ItemDB.get_item(id).get("name","EMPTY"))])
    return "\n".join(parts)

func _build_loadout_tab() -> void:
    alpha_content.add_child(_section("PERSISTENT LOADOUT"))
    alpha_content.add_child(_small("Equipment must exist in your stash. Dying in a raid can destroy equipped gear."))
    var stash: Array = alpha_profile.get("stash",[])
    var slots := {"primary":"PRIMARY","sidearm":"SIDEARM","armor":"ARMOR / RIG","med":"MEDICAL"}
    for slot in slots.keys():
        alpha_content.add_child(_label(str(slots[slot]),14,CYAN))
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation",6)
        alpha_content.add_child(row)
        for id_value in stash:
            var id := str(id_value)
            var d := ItemDB.get_item(id)
            var kind := str(d.get("kind",""))
            var valid := (slot == "primary" and id in ["m4","m870"]) or (slot == "sidearm" and id == "g17") or (slot == "armor" and kind == "armor") or (slot == "med" and kind == "med")
            if not valid:
                continue
            var selected := str((alpha_profile.get("loadout",{}) as Dictionary).get(slot,"")) == id
            var b := _button(("✓ " if selected else "") + str(d.get("name",id)))
            b.custom_minimum_size.x = 180
            b.pressed.connect(func(s:=str(slot),item:=id): equip_requested.emit(s,item))
            row.add_child(b)

func _build_stash_tab() -> void:
    alpha_content.add_child(_section("STASH INVENTORY"))
    var stash: Array = alpha_profile.get("stash",[])
    alpha_content.add_child(_small("Total stored value: $%,d" % ItemDB.stash_value(stash)))
    var grid := GridContainer.new()
    grid.columns = 3
    grid.add_theme_constant_override("h_separation",8)
    grid.add_theme_constant_override("v_separation",8)
    alpha_content.add_child(grid)
    for i in range(stash.size()):
        var id := str(stash[i])
        var d := ItemDB.get_item(id)
        var p := _panel(Color("0b1920"),ItemDB.rarity_color(str(d.get("rarity","common"))),8)
        p.custom_minimum_size = Vector2(265,105)
        var v := VBoxContainer.new()
        p.add_child(v)
        v.add_child(_label(str(d.get("name",id)),12,TEXT))
        v.add_child(_small("%s  •  %.1f KG  •  $%,d" % [str(d.get("type","ITEM")),float(d.get("weight",0.0)),int(d.get("value",0))]))
        var sell := _button("SELL  $%,d" % int(float(d.get("value",0))*0.72))
        sell.disabled = id == "quest_drive"
        sell.pressed.connect(func(item:=id): sell_requested.emit(item))
        v.add_child(sell)
        grid.add_child(p)

func _build_trader_tab() -> void:
    alpha_content.add_child(_section("QUARTERMASTER // MARKET"))
    alpha_content.add_child(_small("Buy field equipment at contractor rates. Sell recovered gear from your stash."))
    var grid := GridContainer.new()
    grid.columns = 3
    grid.add_theme_constant_override("h_separation",8)
    grid.add_theme_constant_override("v_separation",8)
    alpha_content.add_child(grid)
    for id in ["m4","g17","m870","carrier","plate","ifak","salewa"]:
        var d := ItemDB.get_item(id)
        var price := int(float(d.get("value",0))*1.25)
        var p := _panel(Color("0b1920"),ItemDB.rarity_color(str(d.get("rarity","common"))),8)
        p.custom_minimum_size = Vector2(270,112)
        var v := VBoxContainer.new()
        p.add_child(v)
        v.add_child(_label(str(d.get("name",id)),12,TEXT))
        v.add_child(_small("%s  •  %.1f KG" % [str(d.get("type","ITEM")),float(d.get("weight",0.0))]))
        var buy := _button("BUY  $%,d" % price)
        buy.disabled = int(alpha_profile.get("cash",0)) < price
        buy.pressed.connect(func(item:=str(id)): buy_requested.emit(item))
        v.add_child(buy)
        grid.add_child(p)

func _build_contracts_tab() -> void:
    alpha_content.add_child(_section("CONTRACT BOARD"))
    var level := int(alpha_profile.get("level",1))
    var completed: Array = alpha_profile.get("completed_contracts",[])
    var active := str(alpha_profile.get("active_contract","black_tide"))
    for id in CONTRACTS.keys():
        var c: Dictionary = CONTRACTS[id]
        var unlocked := level >= int(c.get("unlock",1))
        var done := completed.has(id)
        var p := _card(str(c.get("name",id)),"%s\nReward $%,d  •  %d XP" % [str(c.get("desc","")),int(c.get("reward",0)),int(c.get("xp",0))],GREEN if unlocked else MUTED)
        var v := p.get_child(0) as VBoxContainer
        var b := _button("ACTIVE" if active == id else ("COMPLETED" if done else ("ACCEPT" if unlocked else "LOCKED — LVL %d" % int(c.get("unlock",1)))))
        b.disabled = not unlocked or active == id
        b.pressed.connect(func(contract_id:=str(id)): contract_requested.emit(contract_id))
        v.add_child(b)
        alpha_content.add_child(p)

func _build_hideout_tab() -> void:
    alpha_content.add_child(_section("OPERATIONS CELL"))
    var level := int(alpha_profile.get("hideout_level",1))
    var cost := 6000*level
    alpha_content.add_child(_card("HIDEOUT LEVEL %d" % level,"Current bonuses:\n• +%d%% contract cash\n• +%d%% raid XP\n• +%d IFAK field use(s)" % [(level-1)*5,(level-1)*5,maxi(0,level-1)],GREEN))
    var upgrade := _button("UPGRADE OPERATIONS CELL  $%,d" % cost,true)
    upgrade.disabled = int(alpha_profile.get("cash",0)) < cost or level >= 5
    upgrade.pressed.connect(func(): hideout_upgrade_requested.emit())
    alpha_content.add_child(upgrade)

func _build_settings_tab() -> void:
    alpha_content.add_child(_section("SETTINGS / ACCESSIBILITY"))
    var settings: Dictionary = alpha_profile.get("settings",{})
    var sensitivity := HSlider.new()
    sensitivity.min_value = 0.02
    sensitivity.max_value = 0.18
    sensitivity.step = 0.005
    sensitivity.value = float(settings.get("sensitivity",0.075))
    alpha_content.add_child(_label("MOUSE SENSITIVITY",12,TEXT))
    alpha_content.add_child(sensitivity)

    var fov := HSlider.new()
    fov.min_value = 60
    fov.max_value = 100
    fov.step = 1
    fov.value = float(settings.get("fov",70.0))
    alpha_content.add_child(_label("FIELD OF VIEW",12,TEXT))
    alpha_content.add_child(fov)

    var volume := HSlider.new()
    volume.min_value = 0
    volume.max_value = 1
    volume.step = 0.05
    volume.value = float(settings.get("master_volume",0.85))
    alpha_content.add_child(_label("MASTER VOLUME",12,TEXT))
    alpha_content.add_child(volume)

    var apply := _button("APPLY SETTINGS",true)
    apply.pressed.connect(func(): settings_requested.emit({"sensitivity":sensitivity.value,"fov":fov.value,"master_volume":volume.value}))
    alpha_content.add_child(apply)

    var res_row := HBoxContainer.new()
    res_row.add_theme_constant_override("separation",6)
    alpha_content.add_child(_label("WINDOW / DISPLAY",12,TEXT))
    alpha_content.add_child(res_row)
    for pair in [["1920×1080",Vector2i(1920,1080)],["2560×1440",Vector2i(2560,1440)],["3440×1440",Vector2i(3440,1440)],["5120×2160",Vector2i(5120,2160)]]:
        var b := _button(str(pair[0]))
        b.pressed.connect(func(size:=pair[1]):
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
            DisplayServer.window_set_size(size)
        )
        res_row.add_child(b)
    var fs := _button("TOGGLE FULLSCREEN")
    fs.pressed.connect(func():
        var mode := DisplayServer.window_get_mode()
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
    )
    alpha_content.add_child(fs)

func set_profile(profile_: Dictionary) -> void:
    super.set_profile(profile_)
    alpha_profile = profile_.duplicate(true)
    if alpha_root != null:
        _show_tab(current_tab)

func show_raid() -> void:
    if alpha_root:
        alpha_root.visible = false
    super.show_raid()

func show_result(extracted: bool, stats: Dictionary, recovered: Array) -> void:
    if alpha_root:
        alpha_root.visible = false
    super.show_result(extracted,stats,recovered)

func show_menu(profile_: Dictionary) -> void:
    super.show_menu(profile_)
    if menu:
        menu.visible = false
    alpha_profile = profile_.duplicate(true)
    if alpha_root:
        alpha_root.visible = true
        _show_tab("DEPLOY")

func alpha_status(text: String, color: Color = CYAN) -> void:
    if status_label:
        status_label.text = text
        status_label.add_theme_color_override("font_color",color)
