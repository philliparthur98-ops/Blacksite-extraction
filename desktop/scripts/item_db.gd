class_name ItemDB
extends RefCounted

const ITEMS := {
    "m4": {"name":"VXR-556 SOPMOD","type":"PRIMARY","kind":"weapon","rarity":"rare","value":2450,"weight":3.4,"caliber":"5.56×45","mag":30,"reserve":120,"damage":34.0,"rpm":690.0,"automatic":true,"asset":"res://assets/weapons/VXR_Carbine.glb"},
    "g17": {"name":"P9 Duty","type":"SIDEARM","kind":"weapon","rarity":"common","value":680,"weight":0.7,"caliber":"9×19","mag":17,"reserve":68,"damage":25.0,"rpm":360.0,"automatic":false,"asset":"res://assets/weapons/P9_Duty.glb"},
    "m870": {"name":"SG-12 Breacher","type":"PRIMARY","kind":"weapon","rarity":"uncommon","value":1320,"weight":3.1,"caliber":"12 GA","mag":6,"reserve":30,"damage":18.0,"rpm":72.0,"automatic":false,"pellets":8,"asset":"res://assets/weapons/SG12_Breacher.glb"},
    "plate": {"name":"Aegis Ceramic Plate","type":"ARMOR","kind":"armor","rarity":"uncommon","value":1780,"weight":4.2,"condition":78},
    "carrier": {"name":"Aegis Plate Carrier","type":"RIG","kind":"armor","rarity":"uncommon","value":2290,"weight":5.8,"condition":84},
    "ifak": {"name":"IFAK Trauma Kit","type":"MEDICAL","kind":"med","rarity":"uncommon","value":420,"weight":0.45,"uses":4},
    "salewa": {"name":"Field Med Bag","type":"MEDICAL","kind":"med","rarity":"rare","value":790,"weight":0.8,"uses":8},
    "gpu": {"name":"Industrial GPU","type":"VALUABLE","kind":"valuable","rarity":"legendary","value":3250,"weight":1.7},
    "ssd": {"name":"Encrypted SSD","type":"INTEL","kind":"intel","rarity":"rare","value":1240,"weight":0.12},
    "radio": {"name":"Military Radio","type":"ELECTRONICS","kind":"valuable","rarity":"rare","value":1680,"weight":1.3},
    "gold": {"name":"Gold Chain","type":"VALUABLE","kind":"valuable","rarity":"epic","value":2240,"weight":0.2},
    "intel": {"name":"Contractor Intel","type":"INTEL","kind":"intel","rarity":"epic","value":2860,"weight":0.18},
    "tools": {"name":"Precision Tool Set","type":"BARTER","kind":"barter","rarity":"common","value":620,"weight":2.2},
    "battery": {"name":"Encrypted Radio Battery","type":"ELECTRONICS","kind":"barter","rarity":"uncommon","value":940,"weight":0.9},
    "badge": {"name":"Dock Security Badge","type":"INTEL","kind":"intel","rarity":"uncommon","value":760,"weight":0.05},
    "quest_drive": {"name":"Black Tide Drive","type":"CONTRACT","kind":"quest","rarity":"legendary","value":0,"weight":0.2}
}

const STARTER_STASH := ["m4","g17","m870","carrier","plate","ifak","salewa","ssd","radio","tools"]
const LOOT_TABLE := ["gpu","ssd","radio","gold","intel","tools","battery","badge","plate","salewa","ifak"]

static func get_item(id: String) -> Dictionary:
    return ITEMS.get(id, {})

static func rarity_color(rarity: String) -> Color:
    match rarity:
        "uncommon": return Color("76d170")
        "rare": return Color("52bfea")
        "epic": return Color("b780ff")
        "legendary": return Color("f2b754")
        _: return Color("8ca3ad")

static func stash_value(stash: Array) -> int:
    var total := 0
    for id in stash:
        total += int(get_item(str(id)).get("value", 0))
    return total

static func item_weight(id: String) -> float:
    return float(get_item(id).get("weight", 0.0))
