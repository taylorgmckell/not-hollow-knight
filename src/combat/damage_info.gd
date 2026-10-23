class_name DamageInfo
extends RefCounted
## One hit, passed from a hitbox to whatever it hits (see Hurtbox).

var amount := 1
## World position the hit came from (the attacker).
var source_position := Vector2.ZERO
## Unit direction the hit pushes the target.
var direction := Vector2.ZERO
## Knockback speed applied to targets that move.
var knockback := 0.0
## &"side", &"up" or &"down" for nail swings.
var attack_direction: StringName = &""


static func make(amount_: int, from: Vector2, push: Vector2, knockback_: float, kind: StringName) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = amount_
	info.source_position = from
	info.direction = push.normalized()
	info.knockback = knockback_
	info.attack_direction = kind
	return info
