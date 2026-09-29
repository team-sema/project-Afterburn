class_name EnemyBulletHub
extends Node

## Per-world signal source for EnemyBullets. Get it with EnemyBullets.get_hub(world).

## Emitted just before a cancelled bullet is freed. `bullet` is still valid
## during the emit; `reason` names the effect that removed it.
signal bullet_cancelled(position: Vector2, reason: StringName, bullet: Node2D)
