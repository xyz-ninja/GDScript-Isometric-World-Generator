extends Panel

onready var vp = get_node("vp")
onready var mg = get_node("vp/mg") 	# generator node

onready var cam = get_node("vp/mg/cam")
onready var r = get_node("vp/mg/renderer")

onready var game = get_tree().get_nodes_in_group("game")[0]
onready var gui = get_tree().get_nodes_in_group("gui")[0]

var human_scene = load("res://rpg/rpg_human.tscn")

var id

var info
var zone

var is_empty = false
var is_active = false

var humans = []
var humans_nodes = []

var room_name = null
var zone_name = null

var g	

func start_setup(_building_type, _building_sub_skill, _zone):
	info = ENV.Buildings.get_type_info(_building_type, _building_sub_skill)

	zone = _zone
	
	info.selected_zone = zone

	room_name = info.name 
	zone_name = get_zone_name()

	id = ENV.get_last_building_id()
	print("NEW ISO ROOM id: " + str(id))

	var iso_room_info =	PLAYER.add_iso_room_info(info, id)
	
	if info.is_mission:
		iso_room_info.set_is_mission(true)
	else:
		iso_room_info.set_is_owned_by_player(true)

	mg.start_setup(id)

	g = mg.g

	var gen_type
	var gen_sub_type = null
	var rooms_count

	if info.is_mission:
		if info.subskill == ENV.SUB_SKILLS.m_fight_training:
			gen_type = g.TYPES.TRAINING_FIGHT_MISSION
			rooms_count = 0
	else:
		if info.type == ENV.BUILD_TYPE.garage:
			gen_type = g.TYPES.P_HOLDING_GARAGE
			rooms_count = 1

			EV.add_event(EV.EV_TYPE.B_PLACE_STANDARD_ITEMS, self, 
				{fur = ENV.get_furniture_by_obj(ENV.FUR_OBJ.prepare_rob)})

		elif info.type == ENV.BUILD_TYPE.disguise:
			if info.subskill == ENV.SUB_SKILLS.hiring_sportsman:
				gen_type = g.TYPES.P_HOLDING_GYM
				gen_sub_type = g.SUBTYPES.SMALL_DISGUISE

				rooms_count = 2
				
			elif info.subskill == ENV.SUB_SKILLS.hiring_chemist:
				gen_type = g.TYPES.P_HOLDING_SMALL_CLINIC
				gen_sub_type = g.SUBTYPES.SMALL_DISGUISE

				rooms_count = 2
				
			elif info.subskill == ENV.SUB_SKILLS.hiring_bandit:
				gen_type = g.TYPES.P_HOLDING_BAR
				gen_sub_type = g.SUBTYPES.SMALL_DISGUISE

				rooms_count = 2
		else:
			gen_type = g.TYPES.RANDOM
			rooms_count = 2

	r.set_room(self)
	mg.generate_map(rooms_count, gen_type, gen_sub_type)

	add_car(ENV.Cars.create_car_model(ENV.CAR_MODEL.POLICE_LOW))
	add_car(ENV.Cars.create_car_model(ENV.CAR_MODEL.LASTOCHKA_96))

	#if id == 0:
	#	for i in range(2):
	#		PLAYER.hire_human(add_human(HUMANS.generate_random_human(2, HUMANS.HUMAN_TYPE.PLAYER_UNIT, HUMANS.HUMAN_ADDIT_TYPE.SPORTSMAN)).info)

	#print("dist: " + str(TRANSPORT.calc_dist_between_zones(ENV.Zones.forest, ENV.Zones.elite_area)))

func add_human(_info, _custom_map_pos = null):
	#print("UNIT APPEARS iso_room/add_human()")

	var unit_info = _info

	var human_node

	unit_info.set_cur_room_and_zone(self, zone)

	if _custom_map_pos == null: # спауним юнитов в случайном тайле в первом ряду слева
		var spawn_tiles_tms_list = g.find_all_tms_with_symbol(g.BLOCKS.UNIT_SPAWN)

		# ищем подходящий не заблокированный тайл
		var correct_tile
		while spawn_tiles_tms_list.size() > 0:
			var random_tile_tms = SYS.get_random_arr_item(spawn_tiles_tms_list)
			var tile_for_check = r.get_tile_by_tms(random_tile_tms)
			# если тайл не подходит удаляем его из массива и ищем другой
			if tile_for_check == null or tile_for_check.is_all_ways_blocked() or tile_for_check.get_contains_car() != null or tile_for_check.is_has_furniture:
				spawn_tiles_tms_list.erase(random_tile_tms)
				print("tile_for_check blocked!")
			else:
				correct_tile = tile_for_check
				break

		if correct_tile == null:
			print("ALL TILES INCORRECT!!! (Здесь нужно выводить предупреждение для игрока)")
		else:
			human_node = r.spawn_unit(unit_info, correct_tile.tile_map_symbol.map_pos)
	else:
		human_node = r.spawn_unit(unit_info, _custom_map_pos)

	#human.init_info(unit_info)

	#print("add_human() h id: " + str(human_node.info.id))
	#print("self room name " + self.room_name)
	#print("unit info " + unit_info.cur_room.room_name)

	#if !player_humans.has(human):
	#	player_humans.append(human)
	
	if !humans.has(human_node.info):
		humans.append(human_node.info)

	if !humans_nodes.has(human_node):
		humans_nodes.append(human_node)

	return human_node

func add_car(_info = null):
	r.spawn_obj(null, r.scn_car, r.ISO_OBJ_TYPE.CAR, _info)

func setup_gui():
	gui.get_node("main_menu/ceil_info/room_zone/room_label").set_text(room_name + " (ваш)")

	gui.get_node("main_menu/ceil_info/room_zone/zone_label").set_text(zone_name)

func is_active():
	if game.get_active_room() == self:
		return true
	else:
		print("r. room = " + room_name)
		print("active room =" + game.get_active_room().room_name)
		return false

func get_viewport_mouse_pos():
	return vp.get_mouse_pos()

func get_zone_name():
	return ENV.get_zone_name_by_type(zone)

func get_all_inner_units():
	return humans

func get_player_humans():
	var p_humans = []
	
	for h_info in humans:
		if h_info.is_player_human():
			p_humans.append(h_info)

	return p_humans