extends Node

signal score_changed(score: int)
signal lives_changed(lives: int)
signal bank_changed(bank: int)
signal power_changed(id: String, secs_left: float)
signal player_hit
signal game_over
signal level_won

enum State { PLAYING, WON, LOST }
const VERSION := "0.13.0"

const BUILD := "2026.09.22.1"

const START_LIVES := 3
const INVULN_MS := 2200
const POWER_SECS := 15.0
const LEADER_MAX := 8
const SETTINGS_PATH := "user://settings.cfg"

const CORE_POWERS := ["invis", "rocket", "giant"]

const POWERS := {
	"invis": {"name": "INVISIBILITY", "cost": 50, "desc": "Phase through walls"},
	"magnet": {"name": "MAGNET", "cost": 75, "desc": "Dots fly to you"},
	"shield": {"name": "SHIELD", "cost": 80, "desc": "Ghosts can't touch you"},
	"slow": {"name": "SLOW GHOSTS", "cost": 90, "desc": "Ghosts crawl at 35%"},
	"rocket": {"name": "ROCKET", "cost": 100, "desc": "5x speed burst"},
	"fever": {"name": "DOT FEVER", "cost": 110, "desc": "Double dot points"},
	"freeze": {"name": "GHOST FREEZE", "cost": 120, "desc": "Ghosts stop dead"},
	"giant": {"name": "GIANT", "cost": 150, "desc": "Crush ghosts +200 each"},
	"repel": {"name": "GHOST REPEL", "cost": 140, "desc": "Ghosts flee from you"},
	"life": {"name": "EXTRA LIFE", "cost": 200, "desc": "+1 life instantly"},
}

var state: int = State.PLAYING
var score: int = 0
var lives: int = START_LIVES
var bank: int = 0
var mirror_lr := false
var control_mode := "auto"
var sensitivity := 2.0
var stage := 0
var unlocked_stage := 0
var sound_on := true
var music_on := true
var rotate180 := true
var reverse_tilt := false
var paused := false
var player_name := "Player"
var best_score := 0
var leaderboard: Array = []
var _invuln_until_ms := 0
var _power_id := ""
var _power_until_ms := 0
var _test_banner: AdView
var _ad_initialization_listener := OnInitializationCompleteListener.new()
var _ad_listener := AdListener.new()

func _ready() -> void:
	load_settings()
	if OS.get_name() == "Android":
		_initialize_test_ads()

func _initialize_test_ads() -> void:
	_ad_initialization_listener.on_initialization_complete = _on_ads_initialized
	_ad_listener.on_ad_loaded = func() -> void: print("AdMob test banner loaded")
	_ad_listener.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		print("AdMob test banner failed: %s" % error.message)
	MobileAds.initialize(_ad_initialization_listener)

func _on_ads_initialized(_status: InitializationStatus) -> void:
	if _test_banner != null:
		return
	_test_banner = AdView.new(
		"ca-app-pub-3940256099942544/9214589749",
		AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH),
		AdPosition.BOTTOM
	)
	_test_banner.ad_listener = _ad_listener
	_test_banner.load_ad(AdRequest.new())

func _process(_delta: float) -> void:
	if paused:
		return
	if _power_id != "" and Time.get_ticks_msec() >= _power_until_ms:
		_power_id = ""
		power_changed.emit("", 0.0)

func stage_data() -> Dictionary:
	return StagesData.get_stage(stage)

func advance_stage() -> void:
	stage = (stage + 1) % StagesData.count()
	unlocked_stage = maxi(unlocked_stage, stage)
	save_settings()

func toggle_mirror() -> bool:
	mirror_lr = not mirror_lr
	save_settings()
	return mirror_lr

func set_control_mode(mode: String) -> void:
	control_mode = mode
	save_settings()

func set_sensitivity(v: float) -> void:
	sensitivity = clampf(v, 1.0, 3.0)
	save_settings()

func set_paused(p: bool) -> void:
	paused = p

func set_player_name(n: String) -> void:
	player_name = n.strip_edges()
	if player_name == "":
		player_name = "Player"
	save_settings()

func submit_score() -> void:
	if score <= 0:
		return
	leaderboard.append({"name": player_name, "score": score, "stage": stage + 1})
	leaderboard.sort_custom(func(a: Variant, b: Variant) -> bool: return int(a["score"]) > int(b["score"]))
	if leaderboard.size() > LEADER_MAX:
		leaderboard.resize(LEADER_MAX)
	best_score = maxi(best_score, score)
	save_settings()

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "mirror_lr", mirror_lr)
	cfg.set_value("controls", "control_mode", control_mode)
	cfg.set_value("controls", "sensitivity", sensitivity)
	cfg.set_value("controls", "sound_on", sound_on)
	cfg.set_value("controls", "music_on", music_on)
	cfg.set_value("controls", "rotate180", rotate180)
	cfg.set_value("controls", "reverse_tilt", reverse_tilt)
	cfg.set_value("progress", "stage", stage)
	cfg.set_value("progress", "unlocked_stage", unlocked_stage)
	cfg.set_value("progress", "bank", bank)
	cfg.set_value("progress", "player_name", player_name)
	cfg.set_value("progress", "best_score", best_score)
	cfg.set_value("progress", "leaderboard", leaderboard)
	cfg.save(SETTINGS_PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		mirror_lr = bool(cfg.get_value("controls", "mirror_lr", false))
		control_mode = str(cfg.get_value("controls", "control_mode", "auto"))
		if not control_mode in ["auto", "tilt", "touch"]:
			control_mode = "auto"
		sensitivity = clampf(float(cfg.get_value("controls", "sensitivity", 2.0)), 1.0, 3.0)
		sound_on = bool(cfg.get_value("controls", "sound_on", true))
		music_on = bool(cfg.get_value("controls", "music_on", true))
		rotate180 = bool(cfg.get_value("controls", "rotate180", true))
		reverse_tilt = bool(cfg.get_value("controls", "reverse_tilt", false))
		stage = int(cfg.get_value("progress", "stage", 0)) % StagesData.count()
		unlocked_stage = int(cfg.get_value("progress", "unlocked_stage", 0))
		bank = int(cfg.get_value("progress", "bank", 0))
		player_name = str(cfg.get_value("progress", "player_name", "Player"))
		player_name = player_name.strip_edges()
		if player_name == "":
			player_name = "Player"
		best_score = int(cfg.get_value("progress", "best_score", 0))
		leaderboard = cfg.get_value("progress", "leaderboard", [])
		if leaderboard is Array and not leaderboard.is_empty():
			var filtered: Array = []
			for e in leaderboard:
				if e is Dictionary and int(e.get("score", 0)) > 0:
					filtered.append(e)
			leaderboard = filtered
			leaderboard.sort_custom(func(a: Variant, b: Variant) -> bool: return int(a["score"]) > int(b["score"]))
			if leaderboard.size() > LEADER_MAX:
				leaderboard.resize(LEADER_MAX)

func reset() -> void:
	state = State.PLAYING
	score = 0
	lives = START_LIVES
	_invuln_until_ms = 0
	if _power_id != "":
		_power_id = ""
		power_changed.emit("", 0.0)

func add_score(amount: int) -> void:
	if state != State.PLAYING:
		return
	score += amount
	bank += amount
	bank_changed.emit(bank)
	score_changed.emit(score)

func try_purchase(id: String) -> bool:
	var p: Dictionary = POWERS.get(id, {})
	if p.is_empty():
		return false
	var cost := int(p.get("cost", 999999))
	if bank < cost:
		return false
	bank -= cost
	bank_changed.emit(bank)
	start_power(id)
	save_settings()
	return true

func start_power(id: String) -> void:
	if id == "life":
		lives += 1
		lives_changed.emit(lives)
		power_changed.emit("life", 0.0)
		return
	_power_id = id
	_power_until_ms = Time.get_ticks_msec() + int(POWER_SECS * 1000.0)
	power_changed.emit(id, POWER_SECS)

func current_power() -> String:
	return _power_id

func is_power_active(id: String) -> bool:
	return _power_id == id and Time.get_ticks_msec() < _power_until_ms

func power_left_secs() -> float:
	if _power_id == "":
		return 0.0
	return maxf(float(_power_until_ms - Time.get_ticks_msec()) / 1000.0, 0.0)

func random_core_power() -> String:
	return CORE_POWERS[randi() % CORE_POWERS.size()]

func is_invulnerable() -> bool:
	return Time.get_ticks_msec() < _invuln_until_ms

func grant_invulnerability() -> void:
	_invuln_until_ms = Time.get_ticks_msec() + INVULN_MS

func player_caught() -> void:
	if state != State.PLAYING or is_invulnerable():
		return
	lives -= 1
	grant_invulnerability()
	lives_changed.emit(lives)
	player_hit.emit()
	if lives <= 0:
		state = State.LOST
		save_settings()
		game_over.emit()

func level_complete() -> void:
	if state != State.PLAYING:
		return
	add_score(100)
	state = State.WON
	save_settings()
	level_won.emit()

func add_time_bonus(seconds_left: int) -> void:
	add_score(seconds_left * 5)
