extends Node
## Persistent run state: unlocked abilities, respawn point, currency.
##
## Ability flags gate movement states so progression gating comes for free.
## Only the flags are wired up in M1; save/load arrives with the slice world (M7).

var has_dash := false
var has_wall_jump := false
var has_double_jump := false
