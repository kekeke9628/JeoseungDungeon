class_name ActorStats
extends Resource
## Base combat stats shared by players and monsters.

@export var max_hp: int = 20
@export var attack_min: int = 1
@export var attack_max: int = 4
@export var defense: int = 0
## Percentage-point bonus to hit chance.
@export var accuracy: int = 80
## Percentage-point penalty to attacker's hit chance.
@export var evasion: int = 5
