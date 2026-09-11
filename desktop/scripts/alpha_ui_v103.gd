class_name BlacksiteAlphaUIV103
extends BlacksiteAlphaUI

var operator_summary: Label
var operation_summary: Label
var detail_summary: Label
var active_tab_label: Label

func _format_int(value: int) -> String:
    var negative := value < 0
    var digits := str(absi(value))
    var out := ""
    var group := 0
    for i in range(digits.length()-1,-1,-1):
        if group > 0 and group % 3 == 0:
            out = "," + out
        out = digits.substr(i,1) + out
        group += 1
    return ("-" if negative else "") + out

func _money(value: int) -> String:
    return "$" + _format_int(value)

func _build_alpha_terminal() -> void:
    alpha_root = Control.new()
    alpha_root.name = "OperationsWorkspaceV103"
    alpha_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(alpha_root)

    var bg := ColorRect.new()
    bg.color = Color("03080c")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    alpha_root.add_child(bg)

    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left",24)
    margin.add_theme_constant_override("margin_right",24)
    margin.add_theme_constant_override("margin_top",18)
    margin.add_theme_constant_override("margin_bottom",18)
    alpha_root.add_child(margin)

    var shell := VBoxContainer.new()
    shell.add_theme_constant_override("separation",10)
    margin.add_child(shell)

    var header_panel := _panel(Color("071117f2"),Color("23404b"),10)
    header_panel.custom_minimum_size.y = 78
    shell.add_child(header_panel)
    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation",18)
    header_panel.add_child(header)
    var identity := VBoxContainer.new()
    identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(identity)
    identity.add_child(_small("BSI // PRIVATE CONTRACTOR NETWORK",Color("6d91a0")))
    identity.add_child(_label("BLACKSITE OPERATIONS",28,TEXT))
    active_tab_label = _label("DEPLOY",12,ORANGE)
    identity.add_child(active_tab_label)
    header_level = _label("LVL 1",14,CYAN)
    header_cash = _label("$0",19,GREEN)
    header_stash = _small("STASH 0 / 80")
    header.add_child(header_level)
    header.add_child(header_cash)
    header.add_child(header_stash)
    var quit := _button("EXIT")
    quit.custom_minimum_size = Vector2(82,38)
    quit.pressed.connect(func(): quit_requested.emit())
    header.add_child(quit)

    var workspace := HBoxContainer.new()
    workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
    workspace.add_theme_constant_override("separation",10)
    shell.add_child(workspace)

    var left := _panel(Color("061017f2"),Color("1b333d"),10)
    left.custom_minimum_size.x = 238
    workspace.add_child(left)
    var left_v := VBoxContainer.new()
    left_v.add_theme_constant_override("separation",8)
    left.add_child(left_v)
    left_v.add_child(_small("OPERATOR DOSSIER",Color("668b98")))
    operator_summary = _label("LEVEL 1\n0 XP\n0 EXTRACTS",13,TEXT)
    operator_summary.custom_minimum_size.y = 82
    left_v.add_child(operator_summary)
    left_v.add_child(HSeparator.new())
    left_v.add_child(_small("WORKSPACES",Color("668b98")))
    for tab_value in ["DEPLOY","LOADOUT","STASH","TRADER","CONTRACTS","HIDEOUT","SETTINGS"]:
        var tab := str(tab_value)
        var b := _button(tab)
        b.custom_minimum_size = Vector2(210,42)
        b.pressed.connect(_show_tab.bind(tab))
        left_v.add_child(b)
    var spacer := Control.new()
    spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    left_v.add_child(spacer)
    operation_summary = _small("HARBOR DISTRICT 07\nSTATUS // CONTESTED",Color("88a4ac"))
    left_v.add_child(operation_summary)

    var center := _panel(Color("08141bea"),Color("24424d"),12)
    center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    center.size_flags_vertical = Control.SIZE_EXPAND_FILL
    workspace.add_child(center)
    var center_margin := MarginContainer.new()
    center_margin.add_theme_constant_override("margin_left",14)
    center_margin.add_theme_constant_override("margin_right",14)
    center_margin.add_theme_constant_override("margin_top",12)
    center_margin.add_theme_constant_override("margin_bottom",12)
    center.add_child(center_margin)
    var scroll := ScrollContainer.new()
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    center_margin.add_child(scroll)
    alpha_content = VBoxContainer.new()
    alpha_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    alpha_content.add_theme_constant_override("separation",11)
    scroll.add_child(alpha_content)

    var right := _panel(Color("061017f2"),Color("1b333d"),10)
    right.custom_minimum_size.x = 286
    workspace.add_child(right)
    var right_v := VBoxContainer.new()
    right_v.add_theme_constant_override("separation",9)
    right.add_child(right_v)
    right_v.add_child(_small("READY STATE",Color("668b98")))
    detail_summary = _label("LOADOUT\n—\nCONTRACT\n—",12,Color("c4d3d7"))
    detail_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    right_v.add_child(detail_summary)
    right_v.add_child(HSeparator.new())
    right_v.add_child(_small("RAID PRINCIPLE",Color("668b98")))
    var doctrine := _small("What leaves the terminal can be lost.\nWhat reaches extraction becomes yours.\nChoose value against survival.",Color("9aafb6"))
    doctrine.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    right_v.add_child(doctrine)

    status_label = _small("SYSTEM READY // PROFILE SYNCHRONIZED",Color("81a9b4"))
    shell.add_child(status_label)
    _show_tab("DEPLOY")

func _show_tab(tab: String) -> void:
    super._show_tab(tab)
    if active_tab_label:
        active_tab_label.text = "WORKSPACE // %s" % tab
    _refresh_context()

func _refresh_header() -> void:
    if header_cash == null:
        return
    header_cash.text = _money(int(alpha_profile.get("cash",0)))
    header_level.text = "LVL %d" % int(alpha_profile.get("level",1))
    var stash: Array = alpha_profile.get("stash",[])
    header_stash.text = "STASH %d / 80" % stash.size()
    _refresh_context()

func _refresh_context() -> void:
    if alpha_profile.is_empty():
        return
    if operator_summary:
        operator_summary.text = "LEVEL %d\n%s XP\n%d EXTRACTS  •  %d KILLS" % [
            int(alpha_profile.get("level",1)),_format_int(int(alpha_profile.get("xp",0))),
            int(alpha_profile.get("extractions",0)),int(alpha_profile.get("kills",0))]
    if detail_summary:
        var loadout: Dictionary = alpha_profile.get("loadout",{})
        var primary := str(ItemDB.get_item(str(loadout.get("primary",""))).get("name","EMPTY"))
        var armor := str(ItemDB.get_item(str(loadout.get("armor",""))).get("name","EMPTY"))
        var active := str(alpha_profile.get("active_contract","black_tide"))
        var contract: Dictionary = CONTRACTS.get(active,CONTRACTS["black_tide"])
        detail_summary.text = "PRIMARY\n%s\n\nARMOR\n%s\n\nACTIVE CONTRACT\n%s\n\nINSURANCE TOKENS\n%d" % [
            primary,armor,str(contract.get("name","BLACK TIDE")),int(alpha_profile.get("insurance_tokens",0))]

func _build_stash_tab() -> void:
    alpha_content.add_child(_section("STASH INVENTORY"))
    var stash: Array = alpha_profile.get("stash",[])
    alpha_content.add_child(_small("Total stored value: %s" % _money(ItemDB.stash_value(stash))))
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
        v.add_child(_small("%s  •  %.1f KG  •  %s" % [str(d.get("type","ITEM")),float(d.get("weight",0.0)),_money(int(d.get("value",0)))]))
        var sell_value := int(float(d.get("value",0))*0.72)
        var sell := _button("SELL  %s" % _money(sell_value))
        sell.disabled = id == "quest_drive"
        sell.pressed.connect(func(): sell_requested.emit(id))
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
    for id_value in ["m4","g17","m870","carrier","plate","ifak","salewa"]:
        var id: String = str(id_value)
        var d := ItemDB.get_item(id)
        var price := int(float(d.get("value",0))*1.25)
        var p := _panel(Color("0b1920"),ItemDB.rarity_color(str(d.get("rarity","common"))),8)
        p.custom_minimum_size = Vector2(270,112)
        var v := VBoxContainer.new()
        p.add_child(v)
        v.add_child(_label(str(d.get("name",id)),12,TEXT))
        v.add_child(_small("%s  •  %.1f KG" % [str(d.get("type","ITEM")),float(d.get("weight",0.0))]))
        var buy := _button("BUY  %s" % _money(price))
        buy.disabled = int(alpha_profile.get("cash",0)) < price
        buy.pressed.connect(func(): buy_requested.emit(id))
        v.add_child(buy)
        grid.add_child(p)

func _build_contracts_tab() -> void:
    alpha_content.add_child(_section("CONTRACT BOARD"))
    var level := int(alpha_profile.get("level",1))
    var completed: Array = alpha_profile.get("completed_contracts",[])
    var active := str(alpha_profile.get("active_contract","black_tide"))
    for id_value in CONTRACTS.keys():
        var id: String = str(id_value)
        var c: Dictionary = CONTRACTS[id]
        var unlocked := level >= int(c.get("unlock",1))
        var done := completed.has(id)
        var body := "%s\nReward %s  •  %s XP" % [str(c.get("desc","")),_money(int(c.get("reward",0))),_format_int(int(c.get("xp",0)))]
        var p := _card(str(c.get("name",id)),body,GREEN if unlocked else MUTED)
        var v := p.get_child(0) as VBoxContainer
        var button_text := "ACTIVE" if active == id else ("COMPLETED" if done else ("ACCEPT" if unlocked else "LOCKED — LVL %d" % int(c.get("unlock",1))))
        var b := _button(button_text)
        b.disabled = not unlocked or active == id
        b.pressed.connect(func(): contract_requested.emit(id))
        v.add_child(b)
        alpha_content.add_child(p)

func _build_hideout_tab() -> void:
    alpha_content.add_child(_section("OPERATIONS CELL"))
    var level := int(alpha_profile.get("hideout_level",1))
    var cost := 6000*level
    alpha_content.add_child(_card("HIDEOUT LEVEL %d" % level,"Current bonuses:\n• +%d%% contract cash\n• +%d%% raid XP\n• +%d IFAK field use(s)" % [(level-1)*5,(level-1)*5,maxi(0,level-1)],GREEN))
    var upgrade := _button("UPGRADE OPERATIONS CELL  %s" % _money(cost),true)
    upgrade.disabled = int(alpha_profile.get("cash",0)) < cost or level >= 5
    upgrade.pressed.connect(func(): hideout_upgrade_requested.emit())
    alpha_content.add_child(upgrade)

func set_profile(profile_: Dictionary) -> void:
    super.set_profile(profile_)
    _refresh_context()

func smoke_workspace_ok() -> bool:
    return alpha_root != null and alpha_content != null and operator_summary != null and detail_summary != null
