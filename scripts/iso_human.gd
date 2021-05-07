extends "res://scripts/entity.gd"

onready var anim_marker_scene = load("res://gui/anim_marker.tscn")

onready var part_blood_low = load("res://particles/part_shot_hit_low.tscn")
onready var part_blood_medium = load("res://particles/part_shot_hit_medium.tscn")
onready var part_blood_critical = load("res://particles/part_shot_hit_critical.tscn")

onready var game = get_tree().get_nodes_in_group("game")[0]
onready var gui = get_tree().get_nodes_in_group("gui")[0]

onready var bg_button = get_node("info/bg_button")
onready var spr_char = get_node("info/main/character")
onready var main_pivot = get_node("info/main/main_pivot")
onready var body = get_node("info/body")

onready var progressbars = get_node("progressbars")
onready var health_progressbar = get_node("progressbars/progressbar_health")
onready var energy_progressbar = get_node("progressbars/progressbar_energy")

onready var addit_mood_icon = get_node("addit_gui/mood_icon/icon")
onready var addit_shelter_meter = get_node("addit_gui/shelter_meter/icon")
onready var addit_selected_marker = get_node("addit_gui/selected_unit_marker")

onready var dev_debug_text = get_node("addit_gui/dev_debug/d_text")

enum AI_MOOD {BAD, NORMAL, GOOD, SCARED, PANIC, BRAVE, AGRESSIVE}
enum AI_BEHAVIOR {
	# союзная территория
	TER_ALLIES_OUTSIDE_PATROL, # патруль здания
	TER_ALLIES_ROOM_PATROL, 	# патруль комнаты
	TER_ALLIES_RELAXATION,
	
	TER_ENEMIES_, # FIX

	# юнит атакован
	ATTACKED_ATTACK_BACK,
}

# настройки аи
var OLD_ai_params = {
	cur_mood = AI_MOOD.NORMAL, # настроение юнита

	# список врагов 
	enemies_list = [],

	autowork_tile = null,
	auto_relax_tile = null,
	auto_main_ctx_but = null,
	auto_current_but_code = null,

	is_on_allied_territory = false,
	is_on_enemy_territory = false,

	# поведение юнита в разных ситуациях
	behavior_allied_territory = null, 						# союзная территория
	behavior_enemy_territory = null,						# вражеская территория
	behavior_attacked = AI_BEHAVIOR.ATTACKED_ATTACK_BACK, 	# юнит атакован 
}

var addit = {}

var actions_history_manager = null

var info = null

var is_selected = false

var mbz = 1 # move buffer zone
var move_pos_offset = Vector2(0,45)
var move_pos = null

var move_speed = 60 # base : 30
var fight_mode_move_speed_mul = 1.33

var astar_move_path = [] 				# этот путь автоматически очищает пройденные тайлы
var visual_move_path = null 		# объект визуального отображения пути

var astar_prev_move_tile = null
var astar_cur_move_tile = null

var astar_start_tile = null
var astar_finish_tile = null

var action_code = null
# в некоторых случаях нет возможности войти в тайл для использования furniture
# для этого используется переменная another_action_tile
var another_action_tile = null 

var attack_target_unit = null
var weapon_timer = null #!!! GEN IT AUTO (??)

# спихивание юнита в разные стороны (нужно например если два юнита находятся на одном тайле)
var push_offset = Vector2(0, 0)

# basic values
var base

var time = 0

var current_tile = null

var equipment
var inventory

var is_unit_init_and_ready = false
var is_unit_controlled_by_ai = false

var sight_range = Vector2(12, 10)

var cur_dir = SYS.DIR.RIGHT

var ai_timer

var cur_fs_action 

var r
var draw_en

class ActionsHistory:
	var human
	var manager

	var history = []

	func _init(_human, _manager):
		human = _human
		manager = _manager

	func init_manager():
		manager.clear_history()

		for n in history:
			manager.add_history_note(n, true)

	func add_note_by_action_code(_a_code, _addit_info = null):
		var a_code = _a_code
		var addit_info = _addit_info # enemy node, furniture info..

		var a_color = SYS.Colors.white

		var gen_line = ""
		if a_code == "attack":
			var t_type_name

			if addit_info.type == HUMANS.HUMAN_TYPE.POLICE:
				t_type_name = "полицейского"
			else:
				t_type_name = "персонажа"

			a_color = SYS.Colors.red
			gen_line += "Атакует " + t_type_name + " по имени '" + addit_info.name + "'\n"
			
		elif a_code == "make_drugs_lvl1_chem_herbs":
			a_color = SYS.Colors.yellow
			gen_line += "Создаёт наркотики 'Химические Травы'\n"

		if gen_line.length() > 0:
			var gen_note = {text = gen_line, color = a_color}

			history.append(gen_note)
			manager.add_history_note(gen_note)

var actions_history = null

var corpse_loot_items # тут будет массив с некоторыми предметами юнита если он умрет

func _ready():
	bg_button.is_ignore_context = true

	base = { rotate = spr_char.get_rot()}

	# вся начальная настройка в init_info()

	set_process(true)

func init_info(_info):
	info = _info

	info.Inv.inventory = PLAYER.Storage.new(null, self)
	info.Inv.inventory.set_max_capacity(10)

	r = info.cur_room.r
	draw_en = r.get_node("draw_engine")

	equipment = info.Inv
	inventory = info.Inv.inventory

	body.init_basis(self)

	# EQUIP INIT CLOTH
	for item in info.init_cloth:
		equip_cloth(item.info)
	# EQUIP INIT WEAPONS
	body.equip_l_hand_weapon.hide()
	body.equip_r_hand_weapon.hide()

	var is_weapons_equiped = false
	for item in info.init_weapons:
		# лишнее оружие запихиваем в инвентарь
		if is_weapons_equiped:
			if info.Inv.l_hand != item and info.Inv.r_hand != item:
				PLAYER.add_item_obj_to_storage(item, info.Inv.inventory)
		else:
			if info.Inv.l_hand == null:
				equip_item_in_hand(item.info, true, false)
				if item.info.is_two_handed:
					is_weapons_equiped = true
			elif info.Inv.r_hand == null:
				if !item.info.is_two_handed:
					equip_item_in_hand(item.info, false, true)
					is_weapons_equiped = true
						
		# EQUIP ITEMS
		for item in info.init_items:
			PLAYER.add_item_obj_to_storage(item, info.Inv.inventory)

	init_progressbars()

	actions_history_manager = gui.main_menu.get_human_actions_history_manager()

	actions_history = ActionsHistory.new(self, actions_history_manager)

	#equip_item_in_hand(HUMANS.Weapon.new(HUMANS.WEAPON_TYPE.F_PISTOL_MAKAROF), true, true)
	
	is_unit_init_and_ready = true

var mouse_global_pos
func _process(delta):
	time += delta

	update_gui()
	#update_cur_action_code()

	# CHECK IS UNIT DEAD
	if is_dead():
		if body.head_bleeding.part != null and weakref(body.head_bleeding.part).get_ref():
			body.head_bleeding.part.set_autodestroy_and_emit_timer(0.7)
		if body.body_bleeding.part != null and weakref(body.body_bleeding.part).get_ref():
			body.body_bleeding.part.set_autodestroy_and_emit_timer(0.7)
		
		# get loot items
		if corpse_loot_items == null:
			corpse_loot_items = []

			for inv_k in info.Inv:
				if inv_k != "inventory": # инвентарь нужно разбирать отдельно
					var cur_item_info = info.Inv[inv_k]
					if cur_item_info != null and SYS.get_random_percent_0_to_100() < info.chance_to_loot_item:
						var cur_item = PLAYER.get_new_item(
							cur_item_info.storage_type, null, 1, cur_item_info)

						corpse_loot_items.append(cur_item)

			for item in info.Inv.inventory.all:
				if SYS.get_random_percent_0_to_100() < info.chance_to_loot_item:
					corpse_loot_items.append(item)

			if is_player_human():
				corpse_loot_items = []

		if visual_move_path != null:
			GUI.visual_gen_paths.remove_path(visual_move_path)

		return

	# INPUT BUT
	if r.game.check_current_room_id_equal(r.room_id):
		show()
		if is_selected:
			body.input_over.show()
		else:
			body.input_over.hide()
	else:
		hide()

	setup_body_flip()

	# ЕСЛИ ЮНИТУ НУЖНО ПЕРЕМЕСТИТЬСЯ, ПЕРЕМЕЩАЕМ ЕГО ПО ASTAR ПУТИ
	if is_unit_need_moving():
		# ИЩЕМ СЛЕДУЮЩИЙ ТАЙЛ ПУТИ
		if astar_cur_move_tile == null:
			astar_cur_move_tile = astar_move_path[0]

			move_pos = get_corrected_tile_pos(astar_cur_move_tile)
			
			astar_move_path.erase(astar_cur_move_tile)
		
		# если такой найден продолжаем путь
		if astar_cur_move_tile != null:
			body.set_anim_action(body.ACTIONS.ASTAR_MOVE)

			var c_pos = get_global_pos()

			#draw_en.paint_line(
			#	main_pivot.get_global_pos(),
			#	move_pos, Color(0,220,0,1)
			#)

			var dx = 0
			var dy = 0

			# FIX: ЗАПРЕТИТЬ ПОВОРОТ ЕСЛИ Y ТАЙЛА (map_pos) И Y ЮНИТА СОВПАДАЕТ

			var cur_move_speed = move_speed
			if game.fight_system.is_active:
				cur_move_speed *= fight_mode_move_speed_mul

			if c_pos.x > move_pos.x + mbz:
				dx = -cur_move_speed
			elif c_pos.x < move_pos.x - mbz:
				dx = cur_move_speed

			if c_pos.y > move_pos.y + mbz:
				dy = -cur_move_speed
			elif c_pos.y < move_pos.y - mbz:
				dy = cur_move_speed

			c_pos.x += dx * delta
			c_pos.y += dy * delta

			set_global_pos(c_pos)

			if int(SYS.get_dist_between_points(move_pos, c_pos)) < 5: # 3
				move_pos = null

				set_visual_move_path(astar_move_path)

				# если на тайле уже есть юниты добавляем push_offset (сдвигаем их)
				var cur_t_units = r.get_units_with_current_tile(astar_cur_move_tile)
				if cur_t_units.size() > 0:
					for i in range(cur_t_units.size()):
						var cur_unit = cur_t_units[i]
						var cur_unit_body_push_offset = Vector2(4 * (i + 1), 3 * (i + 1))
						cur_unit.push_offset = cur_unit_body_push_offset

				# SETTING CURRENT UNIT TILE
				if astar_cur_move_tile.is_floor:
					set_current_tile(astar_cur_move_tile)
					#info.setup_def_cover_strength_by_tile(astar_cur_move_tile)

				if current_tile.is_floor:
					set_z(current_tile.get_contain_unit_z())
					#current_tile.hide_around_tiles(SYS.ONTILE_OBJ_TYPE.UNIT)
				#else:
				#	set_z(current_tile.get_z() + 16)

				# IF UNIT REACH LAST TILE
				if astar_move_path.size() == 0:
					if action_code != null:
						apply_action_code(action_code)

					#if visual_move_path != null:
					#	GUI.visual_gen_paths.remove_path(visual_move_path)

				astar_cur_move_tile = null
	else:
		if action_code == null:
			body.set_anim_action(body.ACTIONS.STANDING)

	# UNIT STAY
	#if move_pos == null:
	#	if action_code == null:
	#		body.set_anim_action(body.ACTIONS.STANDING)
			
	# UNIT MOVE
	#else:	
	#r.check_is_unit_inner_room(self, current_tile)

func update_gui():
	if is_unit_init_and_ready:
		update_progressbars()

		#get_node("dev_cur_action").set_text(body.ACTIONS.keys()[body.action])

		var name_label_text = ""
		var name_label_color

		# SETUP UNIT TOP INFO (HP SP and so on)
		if is_player_human():
			name_label_text = "*"
			name_label_color = SYS.Colors.green

			health_progressbar.set_bar_color(SYS.Colors.red)

			addit_mood_icon.show()
			addit_shelter_meter.show()

			if game.fight_system.is_active and game.fight_system.cur_time_mode == game.fight_system.TIME_MODES.PAUSED:
				if game.fight_system.get_unit_param_spare_ap_count(info) > 0:
					get_node("addit_gui/fight_mode_unit_has_ap_marker").show()
				else:
					get_node("addit_gui/fight_mode_unit_has_ap_marker").hide()
			else:
				get_node("addit_gui/fight_mode_unit_has_ap_marker").hide()

		else:
			name_label_text = "?"
			name_label_color = SYS.Colors.plum
			#addit_gui_name.show()

			addit_mood_icon.hide()
			addit_shelter_meter.hide()

			health_progressbar.set_bar_color(SYS.Colors.black)
			energy_progressbar.set_bar_color(SYS.Colors.black)

			if is_selected:
				addit_selected_marker.get_node("text").add_color_override('font_color', Color(SYS.Colors.red))
			else:
				addit_selected_marker.hide()

		# GUI MENUS
		if is_player_human() or PLAYER.CHEAT_CODES.ENEMY_UNITS_SELECT_ENABLED:
			if is_selected:
				gui.main_menu.setup_human_control(info)
				addit_selected_marker.show()
				addit_selected_marker.get_node("text").add_color_override('font_color',
					Color(SYS.Colors.green))

				var def_cover_str = info.get_def_cover_str()

				# set cover defence info gui part
				var def_desc_left = ENV.get_def_cover_str_name(
					def_cover_str.left)
				var def_desc_right = ENV.get_def_cover_str_name(
					def_cover_str.right)
				var def_desc_up = ENV.get_def_cover_str_name(
					def_cover_str.up)
				var def_desc_down = ENV.get_def_cover_str_name(
					def_cover_str.down)

				var def_cover_desc = "Слева: " + def_desc_left + "\n" + \
					"Справа: " + def_desc_right + "\n" + \
					"Сверху: " + def_desc_up + "\n" + "Снизу: " + def_desc_down + "\n"

				gui.main_menu.controls.human_control.get_node("addit_block/cover_info").set_text(
					def_cover_desc)

				if game.fight_system.is_active:
					gui.main_menu.setup_human_control(info)

					var ap_count = game.fight_system.get_unit_param_spare_ap_count(info)
					var text = ""

					for i in range(ap_count):
						if i == ap_count - 1:
							text += "E"

					gui.main_menu.fight_mode.ap_block.get_node("points_count").set_text(
						str(ap_count) + " AP")
					gui.main_menu.fight_mode.ap_block.get_node("points").set_text(text)

					# заполняем соответствующий sb действиями AP
					var ap_sb_items = []

					var unit_fs_param = game.fight_system.get_unit_info_param_by_info(info)

					if unit_fs_param != null:
						# для каждого использованного AP создаём свой scroll_item
						for p in unit_fs_param.fs_actions:
							if p.ap_cost > 0:
								for i in range(p.ap_cost):
									ap_sb_items.append(p)
	
						# неиспользованные AP заменяем пустышками
						for i in range(info.a_points_init_count - ap_sb_items.size()):
							ap_sb_items.append(null)

					gui.main_menu.fight_mode.ap_block_sb.change_items_array(ap_sb_items)

			else:
				addit_selected_marker.hide()

		# DEV DEBUG UNIT INFO
		var loc_dev_debug_text = ""
		if game.fight_system.is_active:
			
			loc_dev_debug_text += "a actions: " + str(
				game.fight_system.get_unit_param_all_active_actions(info, true)) + "\n"

			if cur_fs_action == null:
				loc_dev_debug_text += "null fs action \n"
			else:
				loc_dev_debug_text += str(cur_fs_action.get_str_name()) + "\n"

			dev_debug_text.set_text(loc_dev_debug_text)


		loc_dev_debug_text += "body act: " + str(SYS.get_dict_key_by_value(body.ACTIONS, body.action)) + "\n"
		loc_dev_debug_text += "body addit act: " + str(SYS.get_dict_key_by_value(body.ACTIONS, body.addit_action)) + "\n"

		dev_debug_text.set_text(loc_dev_debug_text)


		#addit_gui_name.set_text(name_label_text)
		#addit_gui_name.add_color_override('font_color', name_label_color)
		#addit_gui_name.hide()

		#get_node("dev_cur_action").set_text(
		#	body.current_animation + "\n" + body.current_animation_legs)

		#print(body.ACTIONS.keys())

var prev_a_code = null
func apply_action_code(_a_code):
	var a_code = _a_code

	#if a_code != prev_a_code:
		
	set_action_code(a_code)

	var body_action = null

	var b = null # selected business

	if a_code == "open_tile_storage_view":
		if another_action_tile != null:
			another_action_tile.snap_tile_storage_view(self)
		else:
			current_tile.snap_tile_storage_view(self)

	elif a_code == "prepare_rob":
		b = BUSINESS.all.add(ENV.SKILLS.robbery)
	elif a_code == "make_drugs_lvl1_chem_herbs":
		b = BUSINESS.all.add(ENV.SKILLS.make_drugs, PLAYER.DRUG_TYPE.CHEM_HERBS)
		
		# AUE CODE
		var connected_storage_t = astar_finish_tile.Connected.storage_tile
		
		if connected_storage_t == null:
			print("STORAGE DONT SELECTED?")
			return

		var storage_t_connected_local_storage = connected_storage_t.Connected.local_storage
		
		b.set_connected_storage(storage_t_connected_local_storage)

		actions_history.add_note_by_action_code(a_code)
	elif a_code == "fur_add_natur_herbs_plant":
		b = BUSINESS.all.add(ENV.SKILLS.plant_drugs, PLAYER.DRUG_TYPE.NATURAL_HERBS,
			{attach_node = another_action_tile})

	elif a_code == "send_plant_prod_to_storage":
		b = BUSINESS.all.add(ENV.SKILLS.get_plant_prod, PLAYER.DRUG_TYPE.NATURAL_HERBS,
			{attach_node = another_action_tile})

	elif a_code == "learn_data":
		b = BUSINESS.all.add(ENV.SKILLS.learn_data, null, {
			data_pack = get_current_tile().Connected.data_pack})

	elif a_code == "relax_booze":
		b = BUSINESS.all.add(ENV.SKILLS.relax)
		body_action = body.ACTIONS.DRINK_BOOZE

	elif a_code == "enter_car_driver":
		var cur_car = another_action_tile.get_contains_car()
		cur_car.put_unit_inside(self, cur_car.SIT_TYPE.DRIVER)

	elif a_code == "enter_car_passenger":
		var cur_car = another_action_tile.get_contains_car()
		cur_car.put_unit_inside(self, cur_car.SIT_TYPE.PASSENGER)

	if b != null:
		start_prepare_business(get_global_pos(), b)

		if body_action == null:
			body_action = body.ACTIONS.PREPARE_BUSINESS
	else:
		if body_action == null:
			body_action = body.ACTIONS.STANDING

	body.set_anim_action(body_action)

	prev_a_code = a_code

	if another_action_tile != null:
		another_action_tile = null

	#action_code = null

func select():
	if !is_dead():
		# IF THIS PLAYER UNIT
		if info.is_player_human() or PLAYER.CHEAT_CODES.ENEMY_UNITS_SELECT_ENABLED:
			r.deselect_all_units()

			is_selected = true

			gui.main_menu.change_current_control(gui.main_menu.controls.human_control, true)

			actions_history.init_manager()

		# IF NOT :^)
		else:
			if r.get_selected_unit() != null:
				# если сейчас идёт сражение и это не юнит игрока
				if r.game.fight_system.is_active:
					pass
				else:
					GUI.ctx_menu.snap_to_node(self, GUI.CtxType.stranger, null,
						get_unit_exemplary_center_pos())

func attack_node(_t):
	var target_node = _t
	
	if target_node.info.type == HUMANS.HUMAN_TYPE.IDDQD_MAN:
		game.fight_system.launch_fs_action_without_fight(
			game.fight_system.get_fs_unit_action(
				info, game.UNIT_ACTION_TAG.ATTACK_UNIT, 0,
				{aggresor_unit = self, target_unit = target_node})
		)
	else:
		if game.fight_system.is_active:
			var selected_unit = r.get_selected_unit()
			var ap_count = 1

			# добавляем юниту игрока действие атаки
			var is_action_added = r.game.fight_system.add_fs_unit_action(
				info, game.UNIT_ACTION_TAG.ATTACK_UNIT, ap_count,
				{aggresor_unit = selected_unit, target_unit = _t})
			
		else:
			game.fight_system.start_fight(info.cur_room.get_all_inner_units())
			return

func attacked_by_weapon(_agressor_unit, _weapon_info):
	var a_unit = _agressor_unit
	var w_info = _weapon_info
	var w_accuracy = game.get_weapon_accuracy_from_tile_to_tile(w_info, a_unit.get_current_tile(), get_current_tile(), a_unit)

	# ЧИТ НА БЕССМЕРТИЕ НАЁМНИКОВ ИГРОКА
	if is_player_human() and PLAYER.CHEAT_CODES.PL_UNITS_IDDQD:
		w_accuracy = -1

	# если есть несколько выстрелов за один
	for i in range(w_info.bullets_for_one_shot_count):
		randomize()
		var hit_chance = randi() % 10 + 1 # текущий шанс попадания

		# скорее всего попадание
		if w_accuracy >= hit_chance:
			# ПРОВЕРЯЕМ КРИТ
			var critical_miss_chance = SYS.get_random_percent_0_to_100()
			var critical_miss_limit = 93
			var critical_hit_chance = SYS.get_random_percent_0_to_100()
			var critical_hit_limit = 84

			var crit_mul = 1

			if critical_miss_chance > critical_miss_limit and critical_hit_chance > critical_hit_limit:
				body.spawn_falling_text("МЕГАКРИТ!")
				crit_mul = 3.5
			else:
				if critical_miss_chance > critical_miss_limit:
					a_unit.body.spawn_falling_text("КРИТ ПРОМАХ!")
					crit_mul = 0
					randomize()
					a_unit.deal_damage(randi() % 15)

				elif critical_hit_chance > critical_hit_limit:
					body.spawn_falling_text("КРИТ!")
					crit_mul = 2

			randomize()
			var body_part_chance = randi() % 100 + 1

			# чем больше у юнита хп тем сильнее смягчается урон по конечностям
			randomize()
			var hp_buffer_mul = info.health / 30 # в сколько раз смягчается урон
			
			# ЧУДО КРИТЫ
			randomize()
			var miracle_chance = randi() % 100 + 1
			var miracle_active = false
			var mega_miracle_active = false

			if miracle_chance > 70:
				miracle_active = true
				body.spawn_falling_text("Чудом избежал кровотечения")
			elif crit_mul > 1 and miracle_chance > 90:
				mega_miracle_active = true
				body.spawn_falling_text("Увернулся от крита!")

			if mega_miracle_active:
				crit_mul = 0.5

			var limb_damage = w_info.damage * crit_mul

			if limb_damage <= 0:
				print("WTF! IMPOSSIBLE LIMB DAMAGE less than 0 or 0")

			else:
				if hp_buffer_mul > 0:
					limb_damage = int(limb_damage / hp_buffer_mul)
			
				# head
				if body_part_chance <= 15:
					info.Limbs.head.hp -= limb_damage
					if !miracle_active:
						info.add_limb_bleeding_level(info.Limbs.head)
					
					splash_blood(body.get_node("head/blood_points").get_children(),
						limb_damage, info.Limbs.head.hp, crit_mul)

					setup_wounds_display(info.Limbs.head)
					body.spawn_falling_text( "-" + str(limb_damage) + " голова ")
					body.blink_body_part_by_str_key("head")

				# body
				elif body_part_chance > 15 and body_part_chance <= 50:
					info.Limbs.body.hp -= limb_damage
					if !miracle_active:
						info.add_limb_bleeding_level(info.Limbs.body)

					splash_blood(body.get_node("body/blood_points").get_children(),
						limb_damage, info.Limbs.body.hp, crit_mul)

					setup_wounds_display(info.Limbs.body)
					body.spawn_falling_text( "-" + str(limb_damage) + " тело ")
					body.blink_body_part_by_str_key("body")

				# arms
				elif body_part_chance > 50 and body_part_chance <= 75:
					info.Limbs.arms.hp -= limb_damage
					if !miracle_active:
						info.add_limb_bleeding_level(info.Limbs.arms)

					###################
					splash_blood(body.get_node("body/blood_points").get_children(),
						limb_damage, info.Limbs.arms.hp, crit_mul)

					setup_wounds_display(info.Limbs.arms)
					body.spawn_falling_text( "-" + str(limb_damage) + " руки ")
					body.blink_body_part_by_str_key("arms")
				# legs
				else:
					info.Limbs.legs.hp -= limb_damage
					if !miracle_active:
						info.add_limb_bleeding_level(info.Limbs.legs)

					###################
					splash_blood(body.get_node("body/blood_points").get_children(),
						limb_damage, info.Limbs.legs.hp, crit_mul)
					
					setup_wounds_display(info.Limbs.legs)
					body.spawn_falling_text( "-" + str(limb_damage) + " ноги ")
					body.blink_body_part_by_str_key("legs")

			if w_info.cur_spr.cur_global_pos_2d != null:
				var body_pos = body.get_global_pos()
				game.launch_visual_shot_between_positions(w_info.cur_spr.cur_global_pos_2d, 
					Vector2(SYS.get_random_int(body_pos.x - 10, body_pos.x + 10),
						SYS.get_random_int(body_pos.y - 20, body_pos.y + 20)), self)

			deal_damage(w_info.damage * crit_mul)
		# MISS
		else:
			if w_info == null or w_info.is_melee():
				pass
			else:
				
				#var around_tiles = r.get_tile_not_blocked_nearest_tiles(get_current_tile().get_tms(), false, true)
				var around_tiles = r.get_tiles_around_tile(get_current_tile(), true, false, true)

				var selected_tile = SYS.get_random_arr_item(around_tiles)

				var hole_global_pos = selected_tile.spawn_bullet_hole()

				if w_info.cur_spr.cur_global_pos_2d == null:
					print("сука твою мать")
				else:
					#var visual_shot = game.visual_shot_scn.instance()
					#visual_shot.set_global_pos(a_unit.get_global_pos())
					#get_parent().add_child(visual_shot)
					#visual_shot.set_z(get_z() + 10)

					#visual_shot.launch_between_points(a_unit_w_info.cur_spr.cur_global_pos_2d, hole_global_pos)

					game.launch_visual_shot_between_positions(w_info.cur_spr.cur_global_pos_2d, hole_global_pos, self)

		a_unit.attack_target_unit = self

	#print("A_UNIT ACCURACY : " + str(w_accuracy))

func deal_damage(_count):
	if info.type != HUMANS.HUMAN_TYPE.IDDQD_MAN:
		info.health -= _count
	
	update_progressbars()
	
	#var around_tiles = r.get_tile_not_blocked_nearest_tiles(get_current_tile().get_tms(), true, true)
	var around_tiles = r.get_tiles_around_tile(get_current_tile(), true, false, true)

	if is_dead():
		around_tiles = r.get_tile_not_blocked_nearest_tiles(get_current_tile().get_tms(), true, false)

	var selected_tile = SYS.get_random_arr_item(around_tiles)

	if is_dead():
		get_current_tile().spawn_blood(true, true)
	else:
		if selected_tile != null:
			# СПАУН КРОВИ
			for limb in info.Limbs.values():	
				if limb.bleeding_level != null:
					if limb.bleeding_level == HUMANS.BLEEDING_LEVEL.LOW:
						selected_tile.spawn_blood()
					else:
						if selected_tile.is_wall():
							selected_tile.spawn_blood()
						else:
							get_current_tile().spawn_blood(true)
					break

	body.spawn_falling_text("-" + str(_count))

	if is_dead():
		kill_unit()

func add_energy(_count):
	info.energy += _count
	if info.energy > info.max_energy:
		info.energy = info.max_energy

	update_progressbars()
	body.spawn_falling_text("Отдых\n" + str(_count))

func reduce_energy(_count):
	info.energy -= _count
	if info.energy < 1:
		info.energy = 1
	
	update_progressbars()
	body.spawn_falling_text("Усталость\n" + str(_count))

func setup_body_flip():
	if attack_target_unit != null and attack_target_unit.is_dead():
		attack_target_unit = null

	# если юнит атакует другого юнита, он всегда должен быть повернут в его сторону
	if attack_target_unit != null:
		if attack_target_unit.get_global_pos().x < get_global_pos().x:
			body.flip_left()
		else:
			body.flip_right()
	else:
		if move_pos != null:
			if get_global_pos().x > move_pos.x:
				body.flip_left()
			elif get_global_pos().x < move_pos.x:
				body.flip_right()

func check_attack_timer():
	if weapon_timer == null:
		return false
	else:
		if weapon_timer.is_finish():
			return true
		else:
			return false

func cancel_move_by_path():
	move_pos = null
	astar_cur_move_tile = null
	astar_move_path = []

func kill_unit():
	body.spawn_falling_text("мёртв")

# можно передавать null, тогда оружие или предмет пропадёт
func equip_item_in_hand(_item, _in_left_hand = false, _in_right_hand = false):
	# FIX: check is item is weapon
	var item = _item

	var equip_both_hands = false

	if !_in_left_hand and !_in_right_hand:
		print("WTF? WHICH HAND?")
		return
	elif _in_left_hand and _in_right_hand: # equip weapon in both hands
		equip_both_hands = true

	if _in_left_hand or equip_both_hands:
		info.set_Inv_l_hand_item(item)
		if item == null:
			body.equip_l_hand_weapon.hide()
		else:
			setup_weapon(item, SYS.DIR.LEFT)
			body.equip_l_hand_weapon.show()
		
	if _in_right_hand or equip_both_hands:
		info.set_Inv_r_hand_item(item)
		if item == null:
			body.equip_r_hand_weapon.hide()
		else:
			setup_weapon(item, SYS.DIR.RIGHT)
			body.equip_r_hand_weapon.show()

# _is_autodetect_place - автоматически определит куда нужно положить предмет
func equip_cloth(_item):
	var item = _item

	var is_on_head = false
	var is_on_body = false

	if item == null or item.is_head_cloth():
		is_on_head = true
	else:
		is_on_body = true

	if is_on_head:
		equipment.cloth_head = item

		if item == null:
			body.set_clothing_region(null, true)
		else:
			body.set_clothing_region(item.spr_frame_count, true)

	elif is_on_body:
		equipment.cloth_body = item

		if item == null:
			body.set_clothing_region(null)
		else:
			body.set_clothing_region(item.spr_frame_count)

			if item.body_custom_z != null:
				body.clothing.body.n.set_z(item.body_custom_z)

	if equipment.cloth_head == null:
		body.clothing_head.n.hide()
	else:
		body.clothing_head.n.show()

func setup_weapon(_w_info, _dir_hand = SYS.DIR.LEFT):
	var w_info = _w_info

	var dir_hand = _dir_hand
	var cur_hand = null

	var w_spr = null

	var spr_init_rect = body.init_weapon_spr_rect
	
	if _dir_hand == SYS.DIR.LEFT:
		w_spr = body.equip_l_hand_weapon
		w_spr.set_info(w_info)

	elif _dir_hand == SYS.DIR.RIGHT:
		w_spr = body.equip_r_hand_weapon
		w_spr.set_info(w_info)

	# для каждого оружия создавать свой таймер
	var weapon_timer_name = "player_human_weapon_timer_id" + str(info.id)
	var weapon_timer_v = w_info.basic_anim_length / w_info.rate_multiplier

	weapon_timer = TIME.create_timer(weapon_timer_name , weapon_timer_v)

	# меняем скорость юнита в зависимости от класса оружия
	fight_mode_move_speed_mul = w_info.unit_fight_mode_move_speed_mul

	w_spr.set_region_rect(Rect2(Vector2(
		spr_init_rect.pos.x * w_info.spr_frame_count.x,
		spr_init_rect.pos.y * w_info.spr_frame_count.y),
		spr_init_rect.size
	))

func start_prepare_business(_prog_bar_pos , _current_business):
	var pb_pos = _prog_bar_pos
	var cur_business = _current_business

	# create progressbar
	var progressbar_scene = load("res://gui/rooms/progressbars/progressbar_prepare.tscn")
	var progressbar = progressbar_scene.instance()

	progressbar.set_scale(progressbar.get_scale() * 0.6)
	#progressbar.set_global_pos(Vector2(pb_pos.x + 18, pb_pos.y - 15))
	var unit_pos = get_global_pos()
	unit_pos.x -= 30
	unit_pos.y -= 42
	progressbar.set_global_pos(unit_pos)

	progressbar.set_z(get_z() + 1000)

	get_parent().add_child(progressbar)

	cur_business.set_human(self)

	body.set_anim_action(body.ACTIONS.PREPARE_BUSINESS)

	cur_business.set_progressbar(progressbar)
	
# PARTICLES
func splash_blood(_positions, _limb_damage, _limb_hp, _crit_mul):
	var selected_pos = SYS.get_random_arr_item(_positions)

	var p_instance
	if _crit_mul > 1:
		p_instance = part_blood_critical.instance()
	elif _limb_damage > _limb_hp:
		p_instance = part_blood_medium.instance()
	else:
		p_instance = part_blood_low.instance()

	selected_pos.get_parent().add_child(p_instance)
	p_instance.set_global_pos(selected_pos.get_global_pos())
	p_instance.set_z(get_z() + 7)

	randomize()
	p_instance.set_autodestroy_and_emit_timer(rand_range(0.7, 1.1))

func setup_wounds_display(_limb):
	var limb = _limb

	var tex1
	var tex2
	var cur_tex
	var init_rect2 = Rect2(0,0,0,0)

	if limb.str_type == "head":
		tex1 = body.get_node("head/wounds_head")
		tex2 = body.get_node("head/wounds_head1")
		init_rect2 = Rect2(35,32,35,32)

	elif limb.str_type == "body":
		tex1 = body.get_node("body/wounds_body")
		tex2 = body.get_node("body/wounds_body1")
		init_rect2 = Rect2(45,45,45,45)
	else:
		return

	if !tex1.is_visible():
		cur_tex = tex1
	elif !tex2.is_visible():
		cur_tex = tex2
	else:
		return 

	var x_offset_mul = 0
	var y_offset_mul = 0
	if limb.hp <= limb.max_hp * 0.25: # тяжелые травмы
		randomize()
		x_offset_mul = randi() % 4 + 6
	elif limb.hp > limb.max_hp * 0.25 and limb.hp <= limb.max_hp * 0.50: # травмы средней тяжести
		randomize()
		x_offset_mul = randi() % 4 + 3
	elif limb.hp > limb.max_hp * 0.50 and limb.hp <= limb.max_hp * 0.75: # легкие травмы
		randomize()
		x_offset_mul = randi() % 4
	else:
		return

	init_rect2.pos.x *= x_offset_mul
	init_rect2.pos.y *= y_offset_mul

	cur_tex.set_region_rect(init_rect2)
	cur_tex.show()

func teleport_to_tile(_t):
	set_global_pos(get_corrected_tile_pos(_t))
	set_current_tile(_t)

func create_anim_marker_and_send_to_tile(_to_node):
	var to_n = _to_node

	var anim_marker = anim_marker_scene.instance()
	anim_marker.set_global_pos(get_global_pos())
	get_parent().add_child(anim_marker)

	anim_marker.move_to_pos(get_corrected_tile_pos(to_n), true)

	return anim_marker

func move_to_tile_with_action_code(_t, _a_code):
	r.move_unit_to_tile(self, _t)
	set_action_code(_a_code)

# используется что бы использовать furniture пути к которой заблокированы со всех сторон
# в этом случае если существует проходимый тайл рядом action code запустится с него
func move_to_random_nearby_tile_around_tile_with_action_code(_t, _a_code):
	var around_tiles = r.get_tiles_around_tile(_t, false, false, false, true)
	var not_correct_tiles = []

	# если в массиве есть непроходимые тайлы убираем их из выборки
	for t in around_tiles:
		if t.is_all_ways_blocked():
			not_correct_tiles.append(t)

	#print("AROUND TILES MAP POSITIONS:")
	for n_c_t in not_correct_tiles:
		#print("> around tile pos:")
		#print(n_c_t.map_pos)
		#print(" is fur blocked all ways")
		#print(n_c_t.is_furniture_blocked_all_ways())
		around_tiles.erase(n_c_t)

	if around_tiles.size() > 0:
		r.move_unit_to_tile(self, SYS.get_random_arr_item(around_tiles))
		set_action_code(_a_code)
		another_action_tile = _t

func init_progressbars():
	health_progressbar.setup_progressbar(info.max_health)
	energy_progressbar.setup_progressbar(info.max_energy)

func update_progressbars():
	if is_dead():
		health_progressbar.hide()
		energy_progressbar.hide()
	else:
		health_progressbar.show()
		energy_progressbar.show()

		health_progressbar.update(info.health)
		energy_progressbar.update(info.energy)

func remove():
	#r.deselect_all_units()
	is_selected = false

	r.units.erase(self)
	info.cur_room.humans_nodes.erase(self)
	#PLAYER.hired_humans_nodes.erase(self)

	queue_free()

func set_current_tile(_t):
	# setup PREV current tile
	#if current_tile != null:
	#	current_tile.show_around_tiles(SYS.ONTILE_OBJ_TYPE.UNIT)

	push_offset = Vector2(0, 0)

	# setup NEW current tile
	current_tile = _t
	current_tile.hide_around_tiles(SYS.ONTILE_OBJ_TYPE.UNIT)

	info.setup_def_cover_strength_by_tile(current_tile)

func set_current_dir(_d):
	cur_dir = _d

func set_astar_move_path(_path):
	astar_move_path = _path

	set_action_code(null)

# НАЗНАЧИТЬ ВИЗУАЛЬНОЕ ОТОБРАЖЕНИЕ ПУТИ МЕЖДУ ТАЙЛАМИ ДЛЯ ЮНИТА
func set_visual_move_path(_path, _include_cur_tile = true):
	if visual_move_path != null:
		GUI.visual_gen_paths.remove_path(visual_move_path)
	
	var new_path = _path + []

	visual_move_path = new_path
	GUI.visual_gen_paths.draw_path(visual_move_path)

func set_action_code(_action_code):
	action_code = _action_code

func get_unit_exemplary_center_pos():
	var exem_pos = get_global_pos()
	exem_pos.x -= 40
	exem_pos.y -= 60

	return exem_pos

func get_corrected_tile_pos(_t):
	return r.get_corrected_tile_pos(_t)

func get_current_tile():
	return current_tile

# получает направление в котором находится тайл относительно юнита
func get_dir_to_tile_relative_by_self(_t):
	var t = get_current_tile()
	var o_t = _t

	var t_tms = t.get_tms()
	var o_t_tms = o_t.get_tms()

	var sel_dir_h
	var sel_dir_v

	if t_tms.map_pos.x > o_t_tms.map_pos.x:
		sel_dir_h = SYS.DIR.LEFT
		#if is_player_human():
		#	print("LEFT")
	elif t_tms.map_pos.x < o_t_tms.map_pos.x:
		sel_dir_h = SYS.DIR.RIGHT
		#if is_player_human():
		#	print("RIGHT")
	else:
		sel_dir_h = null

	if t_tms.map_pos.y > o_t_tms.map_pos.y:
		sel_dir_v = SYS.DIR.UP
		#if is_player_human():
		#	print("UP")
	elif t_tms.map_pos.y < o_t_tms.map_pos.y:
		sel_dir_v = SYS.DIR.DOWN
		#if is_player_human():
		#	print("DOWN")
	else:
		sel_dir_v = null

	return {h = sel_dir_h, v = sel_dir_v}

# функция проверяет является ли заданный тайл финишным в пути astar
func is_t_equal_astar_finish_t(_t):
	if astar_move_path.size() == 0:
		return false
	else:
		if astar_move_path[astar_move_path.size() - 1] == _t:
			return true
		else:
			return false

# функция нужна для определения правильного тайла начала движение
# в генерации маршрута astar
func get_astar_corrected_current_tile():
	if astar_move_path.size() > 0:
		if astar_move_path.size() == 1:
			return astar_move_path[0]
		else:
			return astar_move_path[1]
		
		#return astar_cur_move_tile
	else:
		return current_tile

func get_current_weapon_info():
	return info.get_current_weapon_info()
	 
# нужно что бы не вводить доп проверок оружия в обоих руках
func get_current_now_weapon_info():
	var w_info = get_current_weapon_info()
	var now_w_info
	if info.is_holding_dual_weapons():
		now_w_info = w_info.get_current_weapon_by_repeat_counter()
	else:
		now_w_info = w_info
	return now_w_info

# убирает все задачи у юнита
func clear_activity():
	astar_move_path = []
	move_pos = null

	body.set_anim_action(body.ACTIONS.STANDING)

func is_player_human():
	return info.is_player_human()

func is_dead():
	return info.is_dead()

func is_unit_standing():
	if astar_move_path.size() == 0:
		return true
	else:
		return false

func is_unit_need_moving():
	if astar_move_path.size() > 0 or move_pos != null:
		return true
	else:
		return false