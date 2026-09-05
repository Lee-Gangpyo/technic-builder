extends Node
## Ensures Noto Sans KR is the default UI font (menus, HUD, catalog).
## Applied early so hangul never falls back to tofu on Web/iOS.
## Also sets readable sizes and high-contrast Button colors for mobile.

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
		theme.default_font_size = 18
		for type_name in ["Button", "Label", "LineEdit", "TextEdit", "PopupMenu", "Tree", "ItemList", "TabBar", "OptionButton", "CheckBox", "CheckButton"]:
			theme.set_font("font", type_name, font)
			# Buttons need larger type for fat-finger mobile HUD
			var sz := 18
			if type_name == "Button":
				sz = 18
			elif type_name == "Label":
				sz = 16
			theme.set_font_size("font_size", type_name, sz)
		ThemeDB.fallback_font = font
		ThemeDB.fallback_font_size = 18
	_apply_button_contrast(theme)
	var root := get_tree().root
	if root != null and theme != null:
		root.theme = theme

func _apply_button_contrast(theme: Theme) -> void:
	## Dark fill + light text so tools/catalog stay readable on bright 3D scenes.
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.14, 0.18, 0.92)
	normal.set_corner_radius_all(10)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = Color(1, 1, 1, 0.22)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.20, 0.24, 0.32, 0.95)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.08, 0.45, 0.75, 0.95)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.15, 0.15, 0.17, 0.55)
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_stylebox("focus", "Button", hover)
	theme.set_color("font_color", "Button", Color(0.96, 0.97, 1.0, 1.0))
	theme.set_color("font_hover_color", "Button", Color(1, 1, 1, 1))
	theme.set_color("font_pressed_color", "Button", Color(1, 1, 1, 1))
	theme.set_color("font_disabled_color", "Button", Color(0.7, 0.7, 0.72, 0.7))
	theme.set_color("font_outline_color", "Button", Color(0, 0, 0, 0.55))
	theme.set_constant("outline_size", "Button", 2)
	theme.set_color("font_color", "Label", Color(0.95, 0.96, 0.98, 1.0))
	theme.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.65))
	theme.set_constant("outline_size", "Label", 3)

## canvas_items stretch maps a fixed viewport (e.g. 1280) onto a narrow phone
## window (~390). Control sizes must be scaled up so on-screen CSS px stay ≥44.
func stretch_scale() -> float:
	var win := Vector2(DisplayServer.window_get_size())
	var vp := Vector2.ZERO
	var tree := get_tree()
	if tree and tree.root:
		vp = tree.root.get_visible_rect().size
	if win.x < 2.0 or vp.x < 2.0:
		return 1.0
	return maxf(vp.x / win.x, 1.0)

func screen_px(css_px: float) -> float:
	return css_px * stretch_scale()

func window_size() -> Vector2:
	var win := Vector2(DisplayServer.window_get_size())
	if win.x >= 2.0 and win.y >= 2.0:
		return win
	var tree := get_tree()
	if tree and tree.root:
		return tree.root.get_visible_rect().size
	return Vector2(1280, 720)

func is_compact() -> bool:
	var s := window_size()
	if s.x < 920.0 or s.x < s.y * 0.95:
		return true
	var touch := DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	if (touch or OS.has_feature("web")) and mini(s.x, s.y) < 1000.0:
		return true
	return false

func want_large_touch() -> bool:
	return is_compact() or DisplayServer.is_touchscreen_available() or OS.has_feature("web") or OS.has_feature("mobile")

