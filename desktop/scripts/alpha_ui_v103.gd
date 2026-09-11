class_name BlacksiteAlphaUIV103
extends BlacksiteAlphaUI

var operator_summary: Label
var operation_summary: Label
var detail_summary: Label
var active_tab_label: Label

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

    # Command header: identity left, account state right.
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
    header.add_child(header_level); header.add_child(header_cash); header.add_child(header_stash)
    var quit := _button("EXIT")
    quit.custom_minimum_size = Vector2(82,38)
    quit.pressed.connect(func(): quit_requested.emit())
    header.add_child(quit)

    var workspace := HBoxContainer.new()
    workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
    workspace.add_theme_constant_override("separation",10)
    shell.add_child(workspace)

    # Left operator/navigation rail.
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
    var spacer := Control.new(); spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL; left_v.add_child(spacer)
    operation_summary = _small("HARBOR DISTRICT 07\nSTATUS // CONTESTED",Color("88a4ac"))
    left_v.add_child(operation_summary)

    # Central workspace remains compatible with all functional Alpha tab builders.
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

    # Right context rail reduces tab hopping and keeps raid state visible.
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
    super._refresh_header()
    _refresh_context()

func _refresh_context() -> void:
    if alpha_profile.is_empty(): return
    if operator_summary:
        operator_summary.text = "LEVEL %d\n%,d XP\n%d EXTRACTS  •  %d KILLS" % [
            int(alpha_profile.get("level",1)),int(alpha_profile.get("xp",0)),
            int(alpha_profile.get("extractions",0)),int(alpha_profile.get("kills",0))]
    if detail_summary:
        var loadout: Dictionary = alpha_profile.get("loadout",{})
        var primary := str(ItemDB.get_item(str(loadout.get("primary",""))).get("name","EMPTY"))
        var armor := str(ItemDB.get_item(str(loadout.get("armor",""))).get("name","EMPTY"))
        var active := str(alpha_profile.get("active_contract","black_tide"))
        var contract: Dictionary = CONTRACTS.get(active,CONTRACTS["black_tide"])
        detail_summary.text = "PRIMARY\n%s\n\nARMOR\n%s\n\nACTIVE CONTRACT\n%s\n\nINSURANCE TOKENS\n%d" % [
            primary,armor,str(contract.get("name","BLACK TIDE")),int(alpha_profile.get("insurance_tokens",0))]

func set_profile(profile_: Dictionary) -> void:
    super.set_profile(profile_)
    _refresh_context()

func smoke_workspace_ok() -> bool:
    return alpha_root != null and alpha_content != null and operator_summary != null and detail_summary != null
