"""Turns raw REA / assetutil / loctable output into readable Markdown evidence tables."""
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

out = Path(sys.argv[1])
LOCALE = "en_GB"  # loctables in this build contain no plain "en" key


def load(name):
    return json.loads((out / name).read_text())


# 1. Main menu: titles, shortcuts and action selectors
ib = load("decode-interface-builder.json")["normalized_result"]
nodes = [n for n in ib["graph"]["nodes"] if "MainMenu.nib" in n["id"]]
by_id = {n["attributes"]["interface_builder_object_id"]: n for n in nodes if n["attributes"].get("interface_builder_object_id")}
actions = {}
for n in nodes:
    if n["kind"] == "action":
        actions.setdefault(n["attributes"]["source_id"], []).append(n["attributes"]["selector"])
titles = load("MainMenu.loctable.json")[LOCALE]


def ref_text(ref):
    node = by_id.get((ref or {}).get("objectID"))
    if not node:
        return ""
    v = node["attributes"].get("nibValues", {})
    return v.get("NSKey") or v.get("NS.string") or ""


def mods(mask):
    return "".join(s for bit, s in ((17, "⇧"), (18, "⌃"), (19, "⌥"), (20, "⌘")) if mask & (1 << bit))


ARROWS = {"": "←", "": "→"}
rows = []
for oid, n in sorted(by_id.items(), key=lambda t: int(t[0]) if t[0].isdigit() else 0):
    if n["attributes"].get("class_name") != "NSMenuItem":
        continue
    v = n["attributes"]["nibValues"]
    key = v.get("NSKeyEquiv", "")
    sel = ", ".join(f"`{s}`" for s in actions.get(oid, []))
    if not key and not sel:
        continue
    key_text = mods(v.get("NSKeyEquivModMask", 0)) + ARROWS.get(key, key.upper() if key.isalpha() and key.isupper() else key) if key else ""
    title_key = ref_text(v.get("NSTitle"))
    rows.append(f"| {titles.get(title_key, title_key)} | {key_text} | {sel} |")
(out / "mainmenu-resolved.md").write_text(
    "Source: `Base.lproj/MainMenu.nib` decoded by `rea decode-interface-builder`; "
    f"titles resolved from `MainMenu.loctable` ({LOCALE}). Upper-case letter = Shift implied.\n\n"
    "| Menu item | Shortcut | Action selector |\n|---|---|---|\n" + "\n".join(rows) + "\n"
)

# 2. Named colours from the asset catalog
colors = ["| Name | Appearance | Components | Colorspace |", "|---|---|---|---|"]
for a in load("assetutil-Assets.json")[1:]:
    if a.get("AssetType") == "Color" and not a["Name"].startswith("AppIcon"):
        comps = [round(c, 3) for c in a["Color components"]]
        colors.append(f"| {a['Name']} | {a.get('Appearance') or 'Any (light)'} | {comps} | {a.get('Colorspace')} |")
(out / "named-colors.md").write_text(
    "Source: `xcrun assetutil --info Assets.car` (REA `inspect-asset-catalog` rejected the .car format).\n\n"
    + "\n".join(colors) + "\n"
)

# 3. Scripting dictionary data model
sdef = ET.parse(out / "iCal.sdef")
lines = ["Source: `Contents/Resources/iCal.sdef` (public AppleScript dictionary).", ""]
for c in sdef.iter("class"):
    if c.get("name") in ("calendar", "event"):
        lines.append(f"### {c.get('name')}\n\n| Property | Type | Access | Description |\n|---|---|---|---|")
        for p in c.iter("property"):
            lines.append(f"| {p.get('name')} | {p.get('type')} | {p.get('access', 'rw')} | {p.get('description')} |")
        lines.append("")
for e in sdef.iter("enumeration"):
    lines.append(f"- enum `{e.get('name')}`: {', '.join(x.get('name') for x in e.iter('enumerator'))}")
(out / "data-model.md").write_text("\n".join(lines) + "\n")

# 4. Selected UI strings relevant to the reconstructed features
loc = load("Localizable.loctable.json")[LOCALE]
wanted = ["New Event", "Untitled", "all-day", "All-Day", "Today", "Day", "Week", "Month", "Year", "Search",
          "Search Results", "No Events", "Delete Event", "Edit Event", "Title contains “%@”",
          "Location contains “%@”", "Notes contain “%@”", "Event contains “%@”", "Invitees contain “%@”",
          "Day Calendar Area", "Week Calendar Area", "Month Calendar Area", "Year Calendar Area",
          "Show Calendar List", "Hide Calendar List", "next month", "previous month", "next week",
          "previous week", "More events hidden", "Multiple Events Selected", "%@, Week %@", "Today, %@"]
strings = ["| Key | en_GB value |", "|---|---|"] + [f"| `{k}` | {loc[k]} |" for k in wanted if k in loc]
missing = [k for k in wanted if k not in loc]
(out / "ui-strings.md").write_text(
    "Source: `Localizable.loctable` (en_GB).\n\n" + "\n".join(strings)
    + (f"\n\nNot present as keys: {missing}\n" if missing else "\n")
)
print("wrote mainmenu-resolved.md, named-colors.md, data-model.md, ui-strings.md")
