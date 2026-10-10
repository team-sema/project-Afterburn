extends SceneTree

## 플레이어 피격 연출: 견딜만한 피격(ABSORBED)·위험한 피격(SHIELD_BROKEN)·치명(LETHAL)
## 등급 신호와 함선 플래시·임팩트·전장 가장자리 경고·피격점 맥동·조종석 패널 흔들림·
## 실드 게이지 섬광을 확인한다. 규칙: docs/design/player.md「피격 연출」.

var failures := PackedStringArray()
var severities: Array[int] = []


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func hit(ship: Node2D, hurt: HurtComponent, offset: Vector2) -> void:
	var hitbox := HitboxComponent.new()
	hitbox.damage = 1
	ship.get_parent().add_child(hitbox)
	hitbox.global_position = ship.global_position + offset
	hurt.hurtbox_component.hurt.emit(hitbox)
	hitbox.queue_free()


func run() -> void:
	GameSettings.instance.save_enabled = false
	var world = load("res://world.tscn").instantiate()
	root.add_child(world)
	for i in 3:
		await process_frame
	var hud = world.get_node("Layout/CockpitHud")
	var gameplay: Node = world.gameplay
	var ship: Node2D = gameplay.get_node("Ship")
	var shield: ShieldComponent = ship.get_node("ShieldComponent")
	var hurt: HurtComponent = ship.get_node("HurtComponent")
	var feedback: PlayerHitFeedback = ship.get_node("PlayerHitFeedback")
	var flash: FlashComponent = ship.get_node("HitFlashComponent")
	var core: PlayerHitPointCore = ship.get_node("PlayerHitPoint/Visual/Core")
	var base_fill: Color = core.fill_color
	var gauge = world.get_node("Layout/LeftPanel/Margin/VBox/ShipStatusHud/ShieldArc")
	hurt.player_hit.connect(func(severity: int, _p: Vector2, _d: Vector2): severities.append(severity))
	hud.set_process(false)
	hud.set_deployment_time(2.6)
	gauge.set_process(false)
	gauge._process(0.0)

	check(gameplay.get_node_or_null("PlayfieldDamageWarning") == null, "no edge warning before any hit")
	check(not feedback.is_pulsing(), "hit point is steady with shield up")

	# 견딜만한 피격: 시작 실드 2 → 1. 탄은 오른쪽에서 온다.
	check(shield.get_current_shield() == 2 and shield.get_max_shield() == 2, "run starts with shield 2")
	hit(ship, hurt, Vector2(20, 0))
	check(severities == [HurtComponent.HitSeverity.ABSORBED], "shield 2 → 1 grades ABSORBED")
	check(feedback.get_last_severity() == HurtComponent.HitSeverity.ABSORBED, "feedback saw ABSORBED")
	check(is_equal_approx(flash.flash_duration, feedback.FLASH_ABSORBED) and not flash._original_materials.is_empty(), "absorbed hit flashes the ship for 0.12s")
	var vfx: ImpactVfx = gameplay.get_node_or_null("ImpactVfx")
	check(vfx != null and vfx.get_active_spark_count() == 6 and vfx.get_active_ring_count() == 1 and vfx.get_active_flare_count() == 1, "absorbed hit sprays 6 sparks, one flare and one 14px ring")
	check(vfx != null and vfx._rings[0].radius == feedback.RING_ABSORBED, "absorbed ring radius is 14px")
	var warning = gameplay.get_node_or_null("PlayfieldDamageWarning")
	check(warning == null or not warning.is_active(), "absorbed hit shows no edge warning")
	check(not feedback.is_pulsing(), "absorbed hit does not pulse the hit point")
	check(hud.is_shaking() and hud._shake_struck_side == 1 and is_equal_approx(hud._shake_scale, 1.0), "absorbed hit shakes panels at base amplitude, right side struck")
	hud._process(0.005)
	check(hud._shake_offset(3).length() > 0.0, "struck-side canopy moves at once")
	check(hud._shake_offset(0).is_zero_approx(), "far-side canopy waits its delay")
	check(hud._shake_offset(4).is_zero_approx(), "console waits 0.03s before rocking")
	check(hud.panels[3].position == hud._shake_offset(3), "panel position carries the shake")
	check(hud.instruments[7].node.position == hud.instruments[7].home + hud._shake_offset(4), "instrument follows its panel's shake")
	check(is_equal_approx(hud._power_dip_left, 0.0), "absorbed hit has no power dip")
	hud._process(1.0)
	check(not hud.is_shaking() and hud.panels[0].position.is_zero_approx() and hud.panels[5].position.is_zero_approx(), "shake ends and panels return home")
	gauge._process(0.0)
	check(gauge.is_flashing() and gauge.get_flash_color() == gauge.ABSORBED_FLASH and gauge._flash_from == 6 and gauge._flash_to == 12, "arc flashes the six darkened segments white")
	gauge._process(1.0)
	check(not gauge.is_flashing(), "arc flash ends")

	# 위험한 피격: 실드 1 → 0.
	hurt.end_invincibility()
	hit(ship, hurt, Vector2(-20, 0))
	check(severities.size() == 2 and severities[1] == HurtComponent.HitSeverity.SHIELD_BROKEN, "shield 1 → 0 grades SHIELD_BROKEN")
	check(is_equal_approx(flash.flash_duration, feedback.FLASH_BROKEN), "broken hit flashes the ship for 0.22s")
	check(vfx.get_active_ring_count() == 2 and vfx._rings[1].radius == feedback.RING_BROKEN, "broken hit adds a 24px ring")
	check(vfx.get_active_spark_count() == 6 + 10, "broken hit sprays 10 sparks (strength 1.6)")
	warning = gameplay.get_node_or_null("PlayfieldDamageWarning")
	check(warning != null and warning.is_active() and is_equal_approx(warning.get_alpha(), warning.FLASH_ALPHA), "broken hit lights the edge warning at 0.45")
	check(warning.z_index == -1, "edge warning draws under bullets and ship")
	warning.set_process(false)
	warning._process(warning.FLASH_DURATION)
	check(warning.get_alpha() <= warning.PULSE_MAX + 0.001 and warning.get_alpha() >= warning.PULSE_MIN - 0.001, "edge warning settles into the pulse band")
	check(feedback.is_pulsing(), "broken hit starts the hit point pulse")
	feedback.set_process(false)
	feedback._process(feedback.PULSE_PERIOD * 0.5)
	check(core.fill_color.g > base_fill.g * 1.5, "hit point fill brightens at the pulse peak")
	check(core.radius == 3.0 and core.outline_width == 1.0, "pulse leaves hit point size and outline alone")
	check(hud.is_shaking() and hud._shake_struck_side == -1 and is_equal_approx(hud._shake_scale, hud.SHAKE_BROKEN_SCALE), "broken hit shakes at 1.8x, left side struck")
	check(is_equal_approx(hud._power_dip_left, hud.POWER_DIP_DURATION), "broken hit dips lamp power")
	var material: ShaderMaterial = hud.panels[0].get_child(0).material
	check(is_equal_approx(material.get_shader_parameter("power"), hud.POWER_DIP), "lamp power reads 0.2 during the dip")
	hud._process(0.07)
	check(is_equal_approx(material.get_shader_parameter("power"), 1.0), "lamp power returns after 0.06s")
	hud._process(1.0)
	gauge._process(0.0)
	check(gauge.is_flashing() and gauge.get_flash_color() == gauge.BROKEN_FLASH and gauge._flash_from == 0 and gauge._flash_to == 12, "arc flashes all twelve segments red")
	gauge._process(1.0)

	# 일시정지: 경고 맥동과 맥동 처리가 멈춘다.
	warning.set_process(true)
	feedback.set_process(true)
	paused = true
	var alpha_before: float = warning.get_alpha()
	var fill_before: Color = core.fill_color
	for i in 3:
		await process_frame
	check(warning.get_alpha() == alpha_before and core.fill_color == fill_before, "pause freezes edge warning and hit point pulse")
	paused = false
	await process_frame
	await process_frame
	check(warning.get_alpha() != alpha_before or core.fill_color != fill_before, "resume advances the pulses")

	# 회복: 경고·맥동 해제.
	shield.restore_shield(1)
	check(not feedback.is_pulsing() and core.fill_color == base_fill, "recovery stops the pulse and restores the fill")
	check(not warning.is_active() and warning._fade_left > 0.0, "recovery fades the edge warning out")
	warning.set_process(false)
	warning._process(warning.FADE_OUT)
	check(is_equal_approx(warning.get_alpha(), 0.0), "edge warning fully fades")

	# 다시 파손 → 치명.
	hurt.end_invincibility()
	hit(ship, hurt, Vector2(0, -20))
	check(severities.size() == 3 and severities[2] == HurtComponent.HitSeverity.SHIELD_BROKEN, "second break grades SHIELD_BROKEN again")
	check(hud._shake_struck_side == 0, "vertical hit rocks both sides at once")
	hud._process(1.0)
	warning._process(warning.FLASH_DURATION)
	hurt.end_invincibility()
	var health_before: int = ship.get_node("StatsComponent").health
	hit(ship, hurt, Vector2(20, 0))
	check(severities.size() == 4 and severities[3] == HurtComponent.HitSeverity.LETHAL, "hit with empty shield grades LETHAL")
	check(ship.get_node("StatsComponent").health == health_before - 1, "lethal hit damages the hull")
	check(not hud.is_shaking(), "lethal hit does not shake the cockpit")
	check(warning._flash_left == 0.0, "lethal hit does not restart the edge flash")

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS player hit feedback: severities, ship flash/impact, edge warning, hit point pulse, panel shake, arc flash, pause, recovery")
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)
