class_name Weapon
extends RefCounted

var id: String
var display: String
var fire_rate: float
var mag_size: int
var reserve_size: int
var spread: float
var pellets: int
var damage: float
var recoil: float
var automatic: bool

var mag: int
var reserve: int

func _init(cfg: Dictionary) -> void:
	id = cfg.id
	display = cfg.display
	fire_rate = cfg.fire_rate
	mag_size = cfg.mag_size
	reserve_size = cfg.reserve_size
	spread = cfg.spread
	pellets = cfg.pellets
	damage = cfg.damage
	recoil = cfg.recoil
	automatic = cfg.automatic
	mag = mag_size
	reserve = reserve_size
