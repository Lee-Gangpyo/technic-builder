extends Node
## Ensures Noto Sans KR is the default UI font (menus, HUD, catalog).
## Applied early so hangul never falls back to tofu on Web/iOS.

const FONT_PATH := "res://assets/fonts/NotoSansKR-Variable.ttf"
const THEME_PATH := "res://assets/ui/default_theme.tres"

func _enter_tree() -> void:
	call_deferred("_apply")

func _apply() -> void:
	var theme: Theme = null
	if ResourceLoader.exists(THEME_PATH):
		theme = load(THEME_PATH) as Theme
	if theme == null:
		theme = Theme.new()
	var font: Font = null
	if ResourceLoader.exists(FONT_PATH):
		font = load(FONT_PATH) as Font
	if font != null:
		theme.default_font = font
		theme.default_font_size = 16
		for type_name in ["Button", "Label", "LineEdit", "TextEdit", "PopupMenu", "Tree", "ItemList", "TabBar", "OptionButton", "CheckBox", "CheckButton"]:
			theme.set_font("font", type_name, font)
			theme.set_font_size("font_size", type_name, 16 if type_name != "Label" else 15)
		ThemeDB.fallback_font = font
		ThemeDB.fallback_font_size = 16
	var root := get_tree().root
	if root != null and theme != null:
		root.theme = theme
