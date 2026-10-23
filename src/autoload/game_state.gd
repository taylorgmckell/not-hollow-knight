extends Node
## Persistent run state: unlocked abilities, respawn point, currency.
##
## Ability flags gate movement states so progression gating comes for free.
## Only the flags are wired up so far; save/load arrives with the slice world (M7).

var has_dash := false
var has_wall_jump := false
var has_double_jump := false


func set_all_abilities(enabled: bool) -> void:
	has_dash = enabled
	has_wall_jump = enabled
	has_double_jump = enabled
