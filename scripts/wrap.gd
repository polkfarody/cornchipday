extends Node2D

# The Wrap finale (characters.txt Bestiary by Level, Level 7): deliberately
# not a boss.gd instance -- Wrap has no health and isn't defeated by combat.
#
# Delivery ritual (Phase 4 rework, confirmed 2026-07-20): ingredients are no
# longer auto-collected by walking over them (see ingredient.gd's
# carry_to_wrap flag) -- the player carries one at a time and must jump onto
# Wrap to drop it in, exactly like the final win jump, just repeated per
# ingredient. Wrap starts drifting side to side within the arena as soon as
# the first delivery lands, forcing the remaining drop-off jumps to be timed
# rather than free -- explicitly safe per the confirmed decision (no attack,
# no life cost, purely a moving target) and stops the instant the 6th lands.
# The final "jump onto him to win" gesture only becomes live once all 6 are
# in and he's reached his lit-up pose.

@export var required_deliveries: int = 6
@export var patrol_half_width: float = 150.0
@export var move_speed: float = 55.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var touch_area: Area2D = $TouchArea

var deliveries_received := 0
var is_lit_up := false
var is_complete := false
var base_x: float
var patrol_direction := 1

func _ready() -> void:
	touch_area.body_entered.connect(_on_touch_area_body_entered)
	base_x = position.x
	sprite.play("idle")

func _process(delta: float) -> void:
	if deliveries_received <= 0 or is_lit_up:
		return
	position.x += patrol_direction * move_speed * delta
	var offset := position.x - base_x
	if offset > patrol_half_width:
		patrol_direction = -1
	elif offset < -patrol_half_width:
		patrol_direction = 1

func _light_up() -> void:
	is_lit_up = true
	position.x = base_x
	sprite.play("celebrate")

func _on_touch_area_body_entered(body: Node) -> void:
	if is_complete or not body.is_in_group("player"):
		return
	var is_jump_onto: bool = body.velocity.y > 0.0 and body.global_position.y < global_position.y - 10.0
	if not is_jump_onto:
		return
	if is_lit_up:
		is_complete = true
		if body.has_method("win_celebration"):
			body.win_celebration()
		return
	if not is_lit_up and body.has_method("take_carried_item"):
		var item: Node = body.take_carried_item()
		if item == null or not item.is_in_group("wrap_delivery"):
			return
		item.deliver()
		deliveries_received += 1
		_bounce()
		if deliveries_received >= required_deliveries:
			_light_up()

# Purely cosmetic delivery-received feedback -- no new art needed.
func _bounce() -> void:
	sprite.scale = Vector2(0.28, 0.28) * Vector2(1.15, 0.85)
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.28, 0.28), 0.15)
