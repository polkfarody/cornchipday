extends Node2D

# The Wrap finale (characters.txt Bestiary by Level, Level 7): deliberately
# not a boss.gd instance -- Wrap has no health, doesn't patrol, and isn't
# defeated by combat. Tracks ingredient deliveries (any node in the
# "wrap_delivery" group, same pattern level_base.gd already uses for
# bean_token), lights up once all are in, then a jump-style landing on him
# (same fall-and-land check every boss already uses for a stomp) completes
# the game.

@export var required_deliveries: int = 6

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var touch_area: Area2D = $TouchArea

var deliveries_received := 0
var is_lit_up := false
var is_complete := false

func _ready() -> void:
	touch_area.body_entered.connect(_on_touch_area_body_entered)
	for delivery in get_tree().get_nodes_in_group("wrap_delivery"):
		delivery.collected.connect(_on_delivery_collected)
	sprite.play("idle")

func _on_delivery_collected() -> void:
	if is_lit_up:
		return
	deliveries_received += 1
	if deliveries_received >= required_deliveries:
		_light_up()

func _light_up() -> void:
	is_lit_up = true
	sprite.play("celebrate")

func _on_touch_area_body_entered(body: Node) -> void:
	if is_complete or not is_lit_up or not body.is_in_group("player"):
		return
	var is_jump_onto: bool = body.velocity.y > 0.0 and body.global_position.y < global_position.y - 10.0
	if not is_jump_onto:
		return
	is_complete = true
	if body.has_method("win_celebration"):
		body.win_celebration()
