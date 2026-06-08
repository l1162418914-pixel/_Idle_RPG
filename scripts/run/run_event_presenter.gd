class_name RunEventPresenter
extends RefCounted
## run_event → 行程提示文案（从 main.gd 迁出）


static func present(event_name: String, data: Dictionary, run_ui: Control, run: WorldRun = null) -> void:
	if run_ui == null:
		return
	match event_name:
		"test_auto_retreat":
			run_ui.show_run_hint(str(data.get("reason", "测试图自动返程")), Color.SKY_BLUE)
		"forced_withdraw":
			run_ui.show_run_hint("团队压力触顶，进入撤离事件…", Color.ORANGE_RED)
		"pressure_retreat_event":
			var quota: int = int(data.get("mia_quota", 0))
			var intact: int = int(data.get("intact_count", 0))
			run_ui.show_run_hint(
				"压力收场 · 撤离事件（完好 %d 人 · 预估遗留风险 %d）" % [intact, quota],
				Color(1.0, 0.65, 0.45)
			)
		"pressure_substitute":
			run_ui.show_run_hint(
				"%s 压力触顶退场 → %s 替补上阵（读条）" % [
					str(data.get("out_name", "")),
					str(data.get("in_name", "")),
				],
				Color.SKY_BLUE
			)
		"supply_point_passed":
			run_ui.show_run_hint(
				"已过补给点 %.0fm（未捞遗留计 1 趟）" % float(data.get("distance", 0)),
				Color(0.65, 0.85, 0.75)
			)
		"player_forced_return":
			var mercs_continue: bool = bool(data.get("mercs_continue", false))
			if run_ui.has_method("play_player_forced_return_overlay"):
				run_ui.play_player_forced_return_overlay(
					mercs_continue, str(data.get("player_name", ""))
				)
			var extra: String = "佣兵继续作战" if mercs_continue else "全队紧急撤离"
			run_ui.show_run_hint("指挥官独自回城 · %s" % extra, Color(0.75, 0.85, 1.0))
		"pressure_loot_lost":
			run_ui.show_run_hint(
				"压力收场震落外露：%s（剩余 %d 件）" % [
					str(data.get("item_name", "装备")),
					int(data.get("remaining", 0)),
				],
				Color.ORANGE_RED
			)
		"retreat_started":
			var dest: float = float(data.get("destination", 0))
			var origin: float = float(data.get("origin", 0))
			var label := "大营"
			if dest > 1.0:
				label = "撤离点 %.0fm" % dest
			var extra := "（行程继续，可接战）"
			if run == null:
				run = GameManager.current_run
			if run and run.squad and run.squad.has_any_member_near_death():
				extra = "（有队员濒死，返程移速减半，濒死者无法战斗）"
			run_ui.show_run_hint("从 %.0fm 返程 → %s%s" % [origin, label, extra], Color.SKY_BLUE)
		"extract_reached":
			run_ui.show_run_hint("已抵达撤离点，继续返回大营…", Color.SKY_BLUE)
		"guard_chase_started":
			run_ui.show_run_hint("撤离物线：返程刷怪加密、护盾消耗加快", Color.ORANGE)
		"boss_chase_started":
			run_ui.show_run_hint("首领开始追击！注意头顶距离", Color.ORANGE)
		"boss_chase_repelled":
			var gap: float = float(data.get("gap", 0))
			var rx: int = int(data.get("exp", 0))
			var rg: int = int(data.get("gold", 0))
			var msg := "首领被击退，距你 %.0fm，趁现在快跑！" % gap
			if data.get("counter", false):
				msg = "反击推远首领！当前距离 %.0fm" % gap
			if rx > 0 or rg > 0:
				msg += "（+%d 经验" % rx
				if rg > 0:
					msg += "、%d 金币" % rg
				msg += "）"
			var rl: Dictionary = data.get("repel_loot", {})
			if rl is Dictionary and str(rl.get("item_name", "")) != "":
				msg += " · 追击表掉落 [%s]" % str(rl.get("item_name", ""))
			run_ui.show_run_hint(msg, Color.SKY_BLUE)
		"chase_repel_loot":
			run_ui.show_run_hint(
				"追击击退额外掉落: [%s] → %s" % [str(data.get("quality", "")), str(data.get("item_name", ""))],
				Color(0.75, 0.95, 1.0)
			)
		"chase_boss_killed":
			run_ui.show_run_hint("追击首领被击杀！", Color.GREEN)
		"chase_stagger_repelled":
			run_ui.show_run_hint("僵持击退经验 +%d" % int(data.get("exp", 0)), Color.CYAN)
		"chase_deep_counter_repelled":
			run_ui.show_run_hint("深度反击额外经验 +%d" % int(data.get("exp", 0)), Color(0.55, 0.95, 1.0))
		"boss_chase_counter":
			var push: float = float(data.get("push_mult", 1.0))
			var rx: int = int(data.get("exp", 0))
			run_ui.show_run_hint(
				"反击成功！首领被推远（×%.2f）+%d 经验" % [push, rx],
				Color.CYAN
			)
		"boss_chase_penalty":
			run_ui.show_run_hint("接战失利！稳定度大跌，首领仍在靠近", Color.ORANGE_RED)
		"boss_chase_catch_execute":
			run_ui.show_run_hint(
				"追猎者追上濒死编队！距离 %.0fm" % float(data.get("gap", 0)),
				Color.ORANGE_RED
			)
		"retreat_shield_started":
			var eq_c: int = int(data.get("equip_shield", 0))
			var eq_m: int = int(data.get("equip_shield_max", 0))
			var mt_c: int = int(data.get("material_shield", 0))
			var mt_m: int = int(data.get("material_shield_max", 0))
			run_ui.show_run_hint(
				"返程护盾 装备 %d/%d · 物资 %d/%d" % [eq_c, eq_m, mt_c, mt_m],
				Color.CYAN
			)
		"march_event":
			var msg: String = str(data.get("log", "路旁事件。"))
			if data.has("gold"):
				msg += " (+%d金)" % int(data.get("gold", 0))
			var mat_names: Array = data.get("material_names", [])
			if not mat_names.is_empty():
				msg += " (%s)" % ", ".join(mat_names)
			var eq_name: String = str(data.get("equip_name", ""))
			if eq_name != "":
				msg += " [%s]" % eq_name
			var team_d: int = int(data.get("team_delta", 0))
			if team_d != 0:
				msg += " (稳定%+d)" % team_d
			var tint: Color = Color(0.88, 0.78, 0.55)
			if data.has("gold") or not mat_names.is_empty() or eq_name != "":
				tint = Color(0.85, 0.95, 0.75)
			elif team_d < 0:
				tint = Color(0.95, 0.72, 0.55)
			run_ui.show_run_hint("【事件】%s" % msg, tint)
		"march_search_hit":
			var msg: String = str(data.get("log", "搜索检定。"))
			var result: String = str(data.get("result", "empty"))
			if result == "gold":
				msg += " (+%d金)" % int(data.get("gold", 0))
			elif result == "material":
				var mat_name: String = str(data.get("material_name", ""))
				if mat_name != "":
					msg = "获得物资: %s" % mat_name
			elif result == "stability":
				var d: int = int(data.get("team_delta", 0))
				if d != 0:
					msg += " (稳定%+d)" % d
			var tint: Color = Color(0.72, 0.88, 0.95)
			if result in ["gold", "material"]:
				tint = Color(0.85, 0.95, 0.75)
			elif result == "stability" and int(data.get("team_delta", 0)) < 0:
				tint = Color(0.95, 0.72, 0.55)
			run_ui.show_run_hint("【搜索】%s" % msg, tint)
		"material_dropped":
			run_ui.show_run_hint("获得物资: %s" % str(data.get("name", "")), Color(0.75, 0.9, 1.0))
		"loot_discarded":
			run_ui.show_run_hint(
				"溢出丢弃: %s" % str(data.get("item_name", "战利品")),
				Color(0.9, 0.65, 0.55)
			)
		"auto_retreat":
			var cv: int = int(data.get("carry_value", 0))
			var th: int = int(data.get("threshold", 0))
			var ar: String = str(data.get("reason", ""))
			var hint: String = str(data.get("item_hint", ""))
			var msg := "携带价值 %d 达标，自动返程" % cv
			match ar:
				"loot_high_value":
					msg = "搜刮策略 · 高价值%s，自动返程" % (
						"「%s」" % hint if hint != "" else "战利品"
					)
				"loot_bags_full":
					msg = "搜刮策略 · 箱/外露已满"
					if hint != "":
						msg += "（%s）" % hint
					msg += "，自动返程"
				"auto_rule":
					msg = "均衡策略 · 背包将满，自动返程（携带 %d）" % cv
				_:
					if th > 0:
						msg = "均衡策略 · 携带 %d≥%d，自动返程" % [cv, th]
			run_ui.show_run_hint(msg, Color.SKY_BLUE)
		"extract_guard_triggered":
			run_ui.show_run_hint(
				"拾取 %s：触发宝库守卫战！" % str(data.get("item_name", "")),
				Color.ORANGE
			)
		"extract_item_secured":
			run_ui.show_run_hint(
				"拾取 %s：未引动守卫，已占格" % str(data.get("item_name", "")),
				Color(0.8, 0.95, 1.0)
			)
		"awakening_started":
			var v_id: String = str(data.get("variant", "damage_burst"))
			var v_label: String = {
				"damage_burst": "爆发",
				"team_shield": "盾援",
				"taunt": "铁壁",
				"heal_snap": "回光",
			}.get(v_id, v_id)
			run_ui.show_run_hint(
				"%s 绝境觉醒·%s！" % [str(data.get("name", "")), v_label],
				Color(1.0, 0.85, 0.35)
			)
		"retreat_shield_broken":
			run_ui.show_run_hint("护盾破碎！返程受击可能遗失战利品", Color.ORANGE_RED)
		"loot_lost_on_retreat":
			var lost_name: String = str(data.get("item_name", "装备"))
			var remain: int = int(data.get("remaining", 0))
			run_ui.show_run_hint(
				"返程受击！遗失 %s（剩余战利品 %d 件）" % [lost_name, remain],
				Color.ORANGE_RED
			)
		"withdraw_confirm":
			var st: int = int(data.get("stability", 0))
			run_ui.show_run_hint("稳定度 %d，建议撤离" % st, Color.ORANGE)
