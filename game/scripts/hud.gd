extends CanvasLayer

signal calibrate_pressed
signal settings_toggled(open: bool)
signal shop_toggled(open: bool)
signal shop_buy_pressed(id: String)
signal next_stage_pressed
signal replay_pressed
signal play_pressed
signal menu_pressed

const MODE_LABELS := ["AUTO", "TILT", "TOUCH"]
const MODE_KEYS := ["auto", "tilt", "touch"]

var _score_label: Label
var _lives_label: Label
var _dots_label: Label
var _stage_label: Label
var _message: Label
var _panel: CenterContainer
var _panel_title: Label
var _panel_score: Label
var _retry_btn: Button
var _next_btn: Button
var _msg_tween: Tween
var _rescue_label: Label
var _power_label: Label
var _bank_chip: Label

var _settings_panel: CenterContainer
var _mode_opt: OptionButton
var _sens_value: Label

var _shop_panel: CenterContainer
var _shop_bank: Label
var _buy_buttons := {}

var _home_panel: CenterContainer
var _progress_panel: CenterContainer
var _progress_labels := {}
var _scores_panel: CenterContainer
var _scores_list: VBoxContainer
var _about_panel: CenterContainer
var _account_panel: CenterContainer
var _name_edit: LineEdit

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_build_settings_panel()
	_build_shop_panel()
	_build_home_panel()
	_build_progress_panel()
	_build_scores_panel()
	_build_about_panel()
	_build_account_panel()
	Game.score_changed.connect(_on_score_changed)
	Game.lives_changed.connect(func(l): _lives_label.text = "●".repeat(maxi(l, 0)))
	Game.bank_changed.connect(func(b): _update_bank_labels(b))
	call_deferred("_sync_from_game")

func _sync_from_game() -> void:
	_on_score_changed(Game.score)
	_lives_label.text = "●".repeat(maxi(Game.lives, 0))
	var s := Game.stage_data()
	set_stage(Game.stage, s.get("name", "?"))
	_update_bank_labels(Game.bank)

func _update_bank_labels(bank: int) -> void:
	_bank_chip.text = "★ BANK %d" % bank
	if _shop_bank != null:
		_shop_bank.text = "BANK: %d PTS" % bank
	for id in _buy_buttons:
		var btn: Button = _buy_buttons[id]
		btn.disabled = bank < int(Game.POWERS.get(id, {}).get("cost", 999999))

func set_power(pname: String, secs_left: float) -> void:
	if pname == "":
		_power_label.visible = false
		return
	_power_label.visible = true
	_power_label.text = "★ %s  %.0fs" % [pname, secs_left]

func set_stage(i: int, name_txt: String) -> void:
	_stage_label.text = "STAGE %d · %s" % [i + 1, name_txt]

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 40)
	add_child(margin)

	var top := HBoxContainer.new()
	top.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	margin.add_child(top)

	_score_label = _mk_label(40, Color.WHITE)
	_score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_score_label)

	_dots_label = _mk_label(26, Color(1, 0.9, 0.25))
	top.add_child(_dots_label)

	_lives_label = _mk_label(34, Color(1.0, 0.88, 0.1))
	_lives_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lives_label.custom_minimum_size.x = 130
	top.add_child(_lives_label)

	_stage_label = _mk_label(24, Color(1, 0.95, 0.4))
	_stage_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_stage_label.offset_top = 92
	_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_stage_label)

	var settings := HBoxContainer.new()
	settings.alignment = BoxContainer.ALIGNMENT_END
	margin.add_child(settings)
	var cal_btn := _mk_small_button("CAL")
	cal_btn.pressed.connect(func(): calibrate_pressed.emit())
	settings.add_child(cal_btn)
	var gear_btn := _mk_small_button("SETTINGS")
	gear_btn.pressed.connect(func(): open_settings(true))
	settings.add_child(gear_btn)
	var shop_btn := _mk_small_button("SHOP")
	shop_btn.pressed.connect(func(): open_shop(true))
	settings.add_child(shop_btn)

	_bank_chip = _mk_label(26, Color(1.0, 0.85, 0.3))
	_bank_chip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_bank_chip.offset_left = -260
	_bank_chip.offset_right = -24
	_bank_chip.offset_top = 88
	_bank_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_bank_chip)

	var menu_btn := _mk_small_button("☰ MENU")
	menu_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	menu_btn.offset_left = 24
	menu_btn.offset_top = 88
	menu_btn.modulate = Color(1, 1, 1, 0.9)
	menu_btn.add_theme_font_size_override("font_size", 24)
	menu_btn.pressed.connect(func(): menu_pressed.emit())
	add_child(menu_btn)

	_power_label = _mk_label(34, Color(1.0, 0.8, 0.15))
	_power_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_power_label.offset_top = 126
	_power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_power_label.visible = false
	add_child(_power_label)

	_rescue_label = _mk_label(30, Color(0.4, 1, 0.5))
	_rescue_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_rescue_label.offset_top = -120
	_rescue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rescue_label.modulate.a = 0.9
	_rescue_label.visible = false
	add_child(_rescue_label)

	_message = _mk_label(34, Color(1, 1, 1))
	_message.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_message.offset_top = 150
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.modulate.a = 0.0
	add_child(_message)

	_panel = CenterContainer.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	_panel.add_child(box)
	_panel_title = _mk_label(60, Color(1, 0.95, 0.4))
	_panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_panel_title)
	_panel_score = _mk_label(42, Color.WHITE)
	_panel_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_panel_score)
	_next_btn = _mk_big_button("NEXT STAGE")
	_next_btn.pressed.connect(func():
		_panel.visible = false
		next_stage_pressed.emit())
	box.add_child(_wrap_center(_next_btn))
	_retry_btn = _mk_big_button("RETRY")
	_retry_btn.pressed.connect(func():
		_panel.visible = false
		replay_pressed.emit())
	box.add_child(_wrap_center(_retry_btn))
	var home_btn := _mk_small_button("HOME")
	home_btn.add_theme_font_size_override("font_size", 30)
	home_btn.custom_minimum_size = Vector2(340, 64)
	home_btn.modulate = Color(1, 1, 1, 0.85)
	home_btn.pressed.connect(func():
		_panel.visible = false
		menu_pressed.emit())
	box.add_child(_wrap_center(home_btn))
	_panel.visible = false

func _build_settings_panel() -> void:
	_settings_panel = CenterContainer.new()
	_settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_settings_panel)

	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.14, 0.96)
	style.border_color = Color(0.25, 0.5, 1.0, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.content_margin_left = 34
	style.content_margin_right = 34
	style.content_margin_top = 26
	style.content_margin_bottom = 30
	card.add_theme_stylebox_override("panel", style)
	_settings_panel.add_child(card)

	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 520
	box.add_theme_constant_override("separation", 22)
	card.add_child(box)

	var title := _mk_label(56, Color(0.55, 0.8, 1.0))
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	box.add_child(_mk_setting_label("CONTROLS", 32))
	_mode_opt = OptionButton.new()
	for m in MODE_LABELS:
		_mode_opt.add_item(m)
	_mode_opt.selected = MODE_KEYS.find(Game.control_mode)
	_mode_opt.add_theme_font_size_override("font_size", 36)
	_mode_opt.item_selected.connect(func(i):
		Game.set_control_mode(MODE_KEYS[i])
		var names := {"auto": "AUTO: TILT IF SENSOR EXISTS, TOUCH ALWAYS WORKS", "tilt": "TILT ONLY — TOUCH DISABLED", "touch": "TOUCH ONLY — DRAG TO STEER"}
		flash_message(names[MODE_KEYS[i]], 2.0))
	box.add_child(_mode_opt)

	box.add_child(_mk_setting_label("TILT / DRAG SENSITIVITY", 32))
	var sens_row := HBoxContainer.new()
	sens_row.add_theme_constant_override("separation", 16)
	var slider := HSlider.new()
	slider.min_value = 1.0
	slider.max_value = 3.0
	slider.step = 0.1
	slider.value = Game.sensitivity
	slider.custom_minimum_size.x = 330
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(v): _sens_value.text = "%.1fx" % v)
	slider.drag_ended.connect(func(_changed): Game.set_sensitivity(slider.value))
	sens_row.add_child(slider)
	_sens_value = _mk_label(34, Color.WHITE)
	_sens_value.text = "%.1fx" % Game.sensitivity
	sens_row.add_child(_sens_value)
	box.add_child(sens_row)

	var mirror := CheckButton.new()
	mirror.text = "MIRROR LEFT-RIGHT"
	mirror.button_pressed = Game.mirror_lr
	mirror.add_theme_font_size_override("font_size", 34)
	mirror.toggled.connect(func(on):
		Game.mirror_lr = on
		Game.save_settings())
	box.add_child(mirror)

	var snd := CheckButton.new()
	snd.text = "SOUND EFFECTS"
	snd.button_pressed = Game.sound_on
	snd.add_theme_font_size_override("font_size", 34)
	snd.toggled.connect(func(on):
		Game.sound_on = on
		Game.save_settings())
	box.add_child(snd)

	var mus := CheckButton.new()
	mus.text = "BACKGROUND MUSIC"
	mus.button_pressed = Game.music_on
	mus.add_theme_font_size_override("font_size", 34)
	mus.toggled.connect(func(on):
		Game.music_on = on
		Game.save_settings()
		Sound.set_music_enabled(on))
	box.add_child(mus)

	var rot := CheckButton.new()
	rot.text = "ROTATE BOARD 180°"
	rot.button_pressed = Game.rotate180
	rot.add_theme_font_size_override("font_size", 34)
	rot.toggled.connect(func(on):
		Game.rotate180 = on
		Game.save_settings())
	box.add_child(rot)

	var rev := CheckButton.new()
	rev.text = "REVERSE TILT DIRECTION"
	rev.button_pressed = Game.reverse_tilt
	rev.add_theme_font_size_override("font_size", 34)
	rev.toggled.connect(func(on):
		Game.reverse_tilt = on
		Game.save_settings())
	box.add_child(rev)

	var cal2 := Button.new()
	cal2.text = "RECALIBRATE NEUTRAL POSE"
	cal2.flat = true
	cal2.add_theme_font_size_override("font_size", 30)
	cal2.pressed.connect(func():
		open_settings(false)
		calibrate_pressed.emit())
	box.add_child(cal2)

	var restart := Button.new()
	restart.text = "RESTART RUN — NO LIFE LOST"
	restart.flat = true
	restart.add_theme_font_size_override("font_size", 30)
	restart.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	restart.pressed.connect(func():
		open_settings(false)
		replay_pressed.emit())
	box.add_child(restart)

	var close := _mk_big_button("CLOSE")
	close.pressed.connect(func(): open_settings(false))
	box.add_child(_wrap_center(close))

	var footer := _mk_label(26, Color(0.55, 0.6, 0.72))
	footer.text = "v%s  build %s\nstage %d/%d  •  unlocked %d  •  bank %d" % [
		Game.VERSION, Game.BUILD, Game.stage + 1, StagesData.count(), Game.unlocked_stage, Game.bank]
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(footer)

	_settings_panel.visible = false

func open_settings(open: bool) -> void:
	if open:
		_close_sub_panels()
		_settings_panel.move_to_front()
		if _shop_panel != null:
			_shop_panel.visible = false
			shop_toggled.emit(false)
	_settings_panel.visible = open
	if open and _mode_opt != null:
		_mode_opt.selected = MODE_KEYS.find(Game.control_mode)
	settings_toggled.emit(open)

func _build_shop_panel() -> void:
	_shop_panel = CenterContainer.new()
	_shop_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_shop_panel)

	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.02, 0.96)
	style.border_color = Color(1.0, 0.8, 0.2, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 22
	style.content_margin_bottom = 24
	card.add_theme_stylebox_override("panel", style)
	_shop_panel.add_child(card)

	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 620
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)

	var title := _mk_label(54, Color(1.0, 0.85, 0.3))
	title.text = "★ SUPERPOWERS ★"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_shop_bank = _mk_label(34, Color.WHITE)
	_shop_bank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_shop_bank)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 560
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	for id in Game.POWERS:
		var p: Dictionary = Game.POWERS[id]
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 14)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		var nm := _mk_label(30, Color(1, 1, 1))
		nm.text = str(p.get("name", id))
		info.add_child(nm)
		var ds := _mk_label(24, Color(0.7, 0.72, 0.8))
		ds.text = "15s • %s" % str(p.get("desc", ""))
		info.add_child(ds)
		row.add_child(info)
		var buy := Button.new()
		buy.text = "%d PTS" % int(p.get("cost", 0))
		buy.custom_minimum_size = Vector2(190, 64)
		buy.add_theme_font_size_override("font_size", 28)
		buy.disabled = Game.bank < int(p.get("cost", 999999))
		buy.pressed.connect(func():
			open_shop(false)
			shop_buy_pressed.emit(id))
		_buy_buttons[id] = buy
		row.add_child(buy)
		list.add_child(row)

	var close := _mk_big_button("CLOSE")
	close.pressed.connect(func(): open_shop(false))
	box.add_child(_wrap_center(close))

	_shop_panel.visible = false

func open_shop(open: bool) -> void:
	if open:
		_close_sub_panels()
		_shop_panel.move_to_front()
		if _settings_panel != null:
			_settings_panel.visible = false
			settings_toggled.emit(false)
	_update_bank_labels(Game.bank)
	_shop_panel.visible = open
	shop_toggled.emit(open)

func _wrap_center(c: Control) -> CenterContainer:
	var w := CenterContainer.new()
	w.add_child(c)
	return w

func _mk_setting_label(txt: String, size: int = 30) -> Label:
	var l := _mk_label(size, Color(0.65, 0.75, 0.9))
	l.text = txt
	return l

func _mk_small_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.modulate = Color(1, 1, 1, 0.65)
	b.add_theme_font_size_override("font_size", 22)
	return b

func _mk_big_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 74)
	b.add_theme_font_size_override("font_size", 32)
	return b

func _mk_label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 8)
	return l

func set_dots_total(total: int) -> void:
	set_dots_left(total)

func set_dots_left(left: int) -> void:
	_dots_label.text = "• %d" % left

func flash_message(text: String, secs: float) -> void:
	_message.text = text
	if _msg_tween and _msg_tween.is_valid():
		_msg_tween.kill()
	_msg_tween = create_tween()
	_msg_tween.tween_property(_message, "modulate:a", 1.0, 0.15)
	_msg_tween.tween_interval(secs)
	_msg_tween.tween_property(_message, "modulate:a", 0.0, 0.5)

func set_rescue_progress(p: float) -> void:
	_rescue_label.visible = p > 0.01
	if p > 0.01:
		_rescue_label.text = "RESCUE %d%%" % int(clampf(p, 0.0, 1.0) * 100)

func show_win(score: int) -> void:
	_panel_title.text = "STAGE CLEAR!"
	_panel_title.add_theme_color_override("font_color", Color(0.3, 1, 0.45))
	_panel_score.text = "SCORE %d" % score
	_next_btn.visible = true
	_retry_btn.text = "REPLAY"
	_panel.visible = true

func show_game_over(score: int) -> void:
	_panel_title.text = "GAME OVER"
	_panel_title.add_theme_color_override("font_color", Color(1, 0.35, 0.35))
	_panel_score.text = "SCORE %d" % score
	_next_btn.visible = false
	_retry_btn.text = "TRY AGAIN"
	_panel.visible = true

func _on_score_changed(score: int) -> void:
	_score_label.text = str(score)

func _mk_card(title_txt: String, title_color: Color, bg: Color) -> Array:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = Color(0.5, 0.65, 1.0, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 26
	style.content_margin_bottom = 26
	card.add_theme_stylebox_override("panel", style)
	cc.add_child(card)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 600
	box.add_theme_constant_override("separation", 14)
	card.add_child(box)
	var t := _mk_label(50, title_color)
	t.text = title_txt
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	cc.visible = false
	return [cc, box]

func _build_home_panel() -> void:
	_home_panel = CenterContainer.new()
	_home_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_home_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.09, 0.94)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_home_panel.add_child(dim)

	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.13, 0.97)
	style.border_color = Color(1.0, 0.85, 0.3, 0.75)
	style.set_border_width_all(3)
	style.set_corner_radius_all(24)
	style.content_margin_left = 60
	style.content_margin_right = 60
	style.content_margin_top = 40
	style.content_margin_bottom = 36
	card.add_theme_stylebox_override("panel", style)
	_home_panel.add_child(card)

	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 560
	box.add_theme_constant_override("separation", 16)
	card.add_child(box)

	var title := _mk_label(96, Color(1.0, 0.85, 0.3))
	title.text = "PACYRINTH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub := _mk_label(28, Color(0.7, 0.85, 1.0))
	sub.text = "3D TILT-MAZE PAC-MAN"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	var play := _mk_big_button("▶  PLAY NEW GAME")
	play.custom_minimum_size = Vector2(460, 84)
	play.add_theme_font_size_override("font_size", 38)
	play.pressed.connect(func():
		_close_sub_panels()
		_home_panel.visible = false
		play_pressed.emit())
	box.add_child(_wrap_center(play))

	var settings := _mk_big_button("SETTINGS")
	settings.pressed.connect(func(): open_settings(true))
	box.add_child(_wrap_center(settings))

	var store := _mk_big_button("STORE")
	store.pressed.connect(func(): open_shop(true))
	box.add_child(_wrap_center(store))

	var progress := _mk_big_button("MY PROGRESS")
	progress.pressed.connect(func():
		_refresh_progress()
		_open_sub(_progress_panel))
	box.add_child(_wrap_center(progress))

	var scores := _mk_big_button("TOP SCORES")
	scores.pressed.connect(func():
		_refresh_scores()
		_open_sub(_scores_panel))
	box.add_child(_wrap_center(scores))

	var about := _mk_big_button("ABOUT THE GAME")
	about.pressed.connect(func(): _open_sub(_about_panel))
	box.add_child(_wrap_center(about))

	var account := _mk_big_button("ACCOUNT")
	account.pressed.connect(func(): _open_sub(_account_panel))
	box.add_child(_wrap_center(account))

	var footer := _mk_label(26, Color(0.5, 0.56, 0.7))
	footer.text = "v%s  build %s\nstage %d/%d  •  unlocked %d  •  bank %d  •  best %d" % [
		Game.VERSION, Game.BUILD, Game.stage + 1, StagesData.count(), Game.unlocked_stage, Game.bank, Game.best_score]
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(footer)

	_home_panel.visible = false

func show_home(show: bool) -> void:
	if show:
		_close_sub_panels()
		open_settings(false)
		open_shop(false)
		_home_panel.move_to_front()
	_home_panel.visible = show

func _build_progress_panel() -> void:
	var p := _mk_card("MY PROGRESS", Color(0.55, 1.0, 0.55), Color(0.04, 0.09, 0.05, 0.96))
	_progress_panel = p[0]
	var box: VBoxContainer = p[1]
	for key in ["CURRENT STAGE", "STAGES UNLOCKED", "BANK", "BEST SCORE"]:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var k := _mk_label(32, Color(0.75, 0.8, 0.9))
		k.text = key
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(k)
		var v := _mk_label(32, Color(1, 1, 1))
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(v)
		_progress_labels[key] = v
		box.add_child(row)
	box.add_child(_sub_close_btn(_progress_panel))

func _refresh_progress() -> void:
	_progress_labels["CURRENT STAGE"].text = "%d / %d" % [Game.stage + 1, StagesData.count()]
	_progress_labels["STAGES UNLOCKED"].text = "%d / %d" % [Game.unlocked_stage + 1, StagesData.count()]
	_progress_labels["BANK"].text = "%d pts" % Game.bank
	_progress_labels["BEST SCORE"].text = "%d" % Game.best_score

func _build_scores_panel() -> void:
	var p := _mk_card("TOP SCORES", Color(1.0, 0.8, 0.3), Color(0.08, 0.06, 0.02, 0.96))
	_scores_panel = p[0]
	var box: VBoxContainer = p[1]
	var note := _mk_label(24, Color(0.55, 0.6, 0.7))
	note.text = "worldwide leaderboard (local for now)"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)
	_scores_list = VBoxContainer.new()
	_scores_list.add_theme_constant_override("separation", 8)
	box.add_child(_scores_list)
	box.add_child(_sub_close_btn(_scores_panel))

func _refresh_scores() -> void:
	for c in _scores_list.get_children():
		c.queue_free()
	if Game.leaderboard.is_empty():
		var l := _mk_label(30, Color(0.7, 0.72, 0.8))
		l.text = "No games recorded yet — go roll!"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_scores_list.add_child(l)
	var i := 1
	for e in Game.leaderboard:
		if i > 8:
			break
		var row := HBoxContainer.new()
		var rank := _mk_label(32, Color(1.0, 0.85, 0.3))
		rank.text = "%d." % i
		row.add_child(rank)
		var nm := _mk_label(32, Color(1, 1, 1))
		nm.text = str(e.get("name", "Player"))
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		var st := _mk_label(28, Color(0.6, 0.7, 0.85))
		st.text = "st%d" % int(e.get("stage", 1))
		row.add_child(st)
		var sc := _mk_label(32, Color(0.8, 1, 0.7))
		sc.text = "%d" % int(e.get("score", 0))
		row.add_child(sc)
		_scores_list.add_child(row)
		i += 1

func _build_about_panel() -> void:
	var p := _mk_card("ABOUT", Color(0.6, 0.85, 1.0), Color(0.03, 0.06, 0.12, 0.96))
	_about_panel = p[0]
	var box: VBoxContainer = p[1]
	var txt := _mk_label(28, Color(0.85, 0.88, 0.95))
	txt.text = "PACYRINTH is a 3D tilt-maze Pac-Man.\n\n\
Roll real balls, dodge ghosts and eat every dot to clear each stage. Collect ★ stars for a random superpower, then spend the bank points you earn on 10 powers in the STORE.\n\n\
CONTROLS\n• Tilt your phone, or drag to steer the board (AUTO chooses for you).\n• RECALIBRATE resets the neutral pose in SETTINGS.\n• ROTATE BOARD 180° flips the playground.\n• RESTART RUN in SETTINGS restarts the stage clean — no life lost.\n\n\
Opening SETTINGS or the STORE pauses the game — ghosts wait.\n\n\
All audio is synthesized live, no assets required.\n\n\
v%s • build %s\nCloud accounts, worldwide scoring and in-app purchases are on the roadmap." % [Game.VERSION, Game.BUILD]
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.custom_minimum_size = Vector2(540, 0)
	box.add_child(txt)
	box.add_child(_sub_close_btn(_about_panel))

func _build_account_panel() -> void:
	var p := _mk_card("ACCOUNT", Color(0.8, 0.7, 1.0), Color(0.06, 0.04, 0.1, 0.96))
	_account_panel = p[0]
	var box: VBoxContainer = p[1]
	var intro := _mk_label(28, Color(0.85, 0.85, 0.95))
	intro.text = "Choose a name for the leaderboard.\nFull account login & cloud sync are planned."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(intro)
	_name_edit = LineEdit.new()
	_name_edit.text = Game.player_name
	_name_edit.placeholder_text = "PLAYER NAME"
	_name_edit.max_length = 16
	_name_edit.add_theme_font_size_override("font_size", 34)
	_name_edit.custom_minimum_size = Vector2(0, 66)
	box.add_child(_name_edit)
	var login := _mk_big_button("SAVE & LOGIN")
	login.pressed.connect(func():
		Game.set_player_name(_name_edit.text)
		_name_edit.text = Game.player_name
		flash_message("Signed in as %s (local)" % Game.player_name, 2.5))
	box.add_child(_wrap_center(login))
	var restore := _mk_big_button("RESTORE PURCHASES")
	restore.pressed.connect(func(): flash_message("No purchases to restore in this build", 2.5))
	box.add_child(_wrap_center(restore))
	box.add_child(_sub_close_btn(_account_panel))

func _sub_close_btn(panel: CenterContainer) -> CenterContainer:
	var b := _mk_big_button("CLOSE")
	b.pressed.connect(func(): _close_sub_panels())
	return _wrap_center(b)

func _open_sub(panel: CenterContainer) -> void:
	_close_sub_panels()
	panel.move_to_front()
	panel.visible = true

func _close_sub_panels() -> void:
	for p in [_progress_panel, _scores_panel, _about_panel, _account_panel]:
		if p != null:
			p.visible = false
