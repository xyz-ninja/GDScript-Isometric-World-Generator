extends Node2D

onready var parent_tile = get_parent()

onready var iso_left_part = get_node("left")
onready var iso_back_part = get_node("back")
onready var iso_front_part = get_node("front")
onready var iso_right_part = get_node("right")

onready var iso_custom_front_part = get_node("custom_front")
onready var iso_custom_back_part = get_node("custom_back")

onready var addit_gui_info = get_node("addit_gui_info")

var is_empty = true

var y_offset_mul = 0

var closed_dirs = {
	left = false,
	right = false,
	back = false,
	front = false
}

var storage_node

var info

var init_pos

func _ready():
	init_pos = get_pos()

	#set_process(true)

func _process(delta):
	if info != null and is_visible():
		if info.need_connected_storage_tile:
			if parent_tile.Connected.storage_tile == null:
				addit_gui_info.get_node("alert_no_storage").show()
			else:
				addit_gui_info.get_node("alert_no_storage").hide()
		else:
			addit_gui_info.get_node("alert_no_storage").hide()

		if storage_node != null:
			var s_info = storage_node.get_node("s_info")
			var plant_gui_info = storage_node.get_node("plant_gui_info")

			# ЕСЛИ ЭТО СКЛАД И НЕ ПРОИЗВОДСТВО
			# show and setup inner storage sprite
			if info.is_storage and !info.is_plant:
				var storage = parent_tile.Connected.local_storage
				var storage_of_tile = parent_tile.Connected.storage_of_tile

				#if storage.cur_capacity == 0:
			
				if storage_of_tile == null:
					storage_node.hide()

				# ЕСЛИ ЭТОТ FUR ЯВЛЯЕТСЯ ХРАНИЛЕЩЕМ ДРУГОГО ТАЙЛА
				# НАСТРАИВАЕМ ТЕКСТУРУ СКЛАДА
				else:
					plant_gui_info.hide()
					s_info.show()

					var icon_rect_x_mul = 0
					var icon_rect_y_mul = 3

					var s_info_header = "Склад"
					var s_info_text = ""
					
					if storage.has_empty_place():
						s_info_text += str(storage.cur_capacity) + " / " + str(storage.max_capacity)
					else:
						s_info_text += str(storage.cur_capacity) + " / " + str(storage.max_capacity) + \
							"\nПОЛОН"

					s_info.get_node("info/header").set_text(s_info_header)
					s_info.get_node("info/text_block/text").set_text(s_info_text)
					s_info.get_node("attached_info").hide()

					var rect_x_mul = 0
					var rect_y_mul = 0

					# НАСТРАЕВАЕМ ИКОНКУ И СМЕЩЕНИЕ ТЕКСТУРЫ
					if storage.bind_item_type == null:
						icon_rect_x_mul = 0
					elif storage.bind_item_type == PLAYER.ITEM_TYPE.DRUGS:
						icon_rect_x_mul = 1

					storage_node.show()
					storage_node.get_node("texture").show()
					s_info.get_node("info").show()

					if storage.cur_capacity >= 1 and storage.cur_capacity < storage.max_capacity * 0.4:
						
						rect_x_mul = 0	

					elif storage.cur_capacity >= storage.max_capacity * 0.4 and \
						storage.cur_capacity < storage.max_capacity * 0.8:

						rect_x_mul = 1

					elif storage.cur_capacity >= storage.max_capacity * 0.8:

						rect_x_mul = 2

					else:
						s_info.get_node("icon").show()
						s_info.get_node("info").hide()
						s_info.get_node("attached_info").show()
						storage_node.get_node("texture").hide()

					storage_node.get_node("texture").set_region_rect(Rect2(
						80 * rect_x_mul, 80 * rect_y_mul, 80, 80))

					s_info.get_node("icon/tex").set_region_rect(Rect2(
						25 * icon_rect_x_mul, 25 * icon_rect_y_mul, 25, 25))

			# ЕСЛИ ЭТО ПРОИЗВОДСТВО
			elif info.is_plant and parent_tile.Connected.plant != null:
				var con_plant_info = parent_tile.Connected.plant
				
				s_info.hide()
				plant_gui_info.show()

				var rect_x_mul = 0
				var rect_y_mul = con_plant_info.texture_y_offset_mul

				if con_plant_info.is_finish():
					plant_gui_info.get_node("ready").show()
					plant_gui_info.get_node("progress").hide()
					plant_gui_info.get_node("ready/items_count").set_text(str(
						str(con_plant_info.get_cur_items_count())+"/"+(str(con_plant_info.items_count))
					))
				elif con_plant_info.is_ready_to_update:
					plant_gui_info.get_node("ready").hide()
					plant_gui_info.get_node("progress").show()
					# setup progressbar
					plant_gui_info.get_node("progress/progressbar_shaded").setup_progressbar(
						con_plant_info.max_progress_points)
					plant_gui_info.get_node("progress/progressbar_shaded").update(
						con_plant_info.cur_progress_points)
				else:
					plant_gui_info.get_node("ready").hide()
					plant_gui_info.get_node("progress").hide()


				if con_plant_info.cur_items_count == 0:
					storage_node.hide()
				else:
					rect_x_mul = con_plant_info.cur_prod_step

					storage_node.get_node("texture").set_region_rect(Rect2(
						80 * rect_x_mul, 80 * rect_y_mul, 80, 80))

					storage_node.show()
			else:
				storage_node.hide()

func setup_furniture(_furniture_info):
	info = _furniture_info

	var info_closed_dirs = info.closed_dirs
	
	iso_left_part.hide()
	iso_right_part.hide()
	iso_back_part.hide()
	iso_front_part.hide()

	iso_custom_front_part.hide()
	iso_custom_back_part.hide()

	parent_tile = get_parent()
	var parent_z = parent_tile.get_z()

	# ПОВТОРНАЯ НАСТРОЙКА МОЖЕТ НЕ РАБОТАТЬ
	# НУЖНО ЗАПОМИНАТЬ СТАНДАРТНЫЕ REGION RECT ЧАСТЕЙ

	var parent_z_data = parent_tile.r.get_z_data_by_map_pos_y(parent_tile.map_pos.y)

	if info.custom_front_region != null:
		closed_dirs.front = true
		iso_custom_front_part.show()
		setup_part_offset(iso_custom_front_part, null, info.custom_front_region)
		
		#iso_custom_front_part.set_z(parent_z + 15)
		iso_custom_front_part.set_z(parent_z_data.params.fur_f)

	elif info.custom_back_region != null:
		closed_dirs.back = true
		iso_custom_back_part.show()
		setup_part_offset(iso_custom_back_part, null, info.custom_back_region)
		#iso_custom_back_part.set_z(parent_z + 1)
		iso_custom_back_part.set_z(parent_z_data.params.fur_b)
	else:
		if info_closed_dirs.has(SYS.ISOM_WALL_DIR.LEFT):
			closed_dirs.left = true
			iso_left_part.show()
			setup_part_offset(iso_left_part, Vector2(0, info.y_offset_mul))
			#iso_left_part.set_z(parent_z + 1)
			iso_left_part.set_z(parent_z_data.params.fur_l)

		if info_closed_dirs.has(SYS.ISOM_WALL_DIR.RIGHT):
			closed_dirs.right = true
			iso_right_part.show()
			setup_part_offset(iso_right_part, Vector2(0, info.y_offset_mul))
			#iso_right_part.set_z(parent_z + 15)
			iso_right_part.set_z(parent_z_data.params.fur_r)

		if info_closed_dirs.has(SYS.ISOM_WALL_DIR.BACK):
			closed_dirs.back = true
			iso_back_part.show()
			setup_part_offset(iso_back_part, Vector2(0, info.y_offset_mul))
			#iso_back_part.set_z(parent_z + 1)
			iso_back_part.set_z(parent_z_data.params.fur_b)

		if info_closed_dirs.has(SYS.ISOM_WALL_DIR.FRONT):
			closed_dirs.front = true
			iso_front_part.show()
			setup_part_offset(iso_front_part, Vector2(0, info.y_offset_mul))
			#iso_front_part.set_z(parent_z + 15)
			iso_front_part.set_z(parent_z_data.params.fur_f)
	
	# блокируем пути в тайл
	parent_tile.tile_map_symbol.remove_ways_in_dirs(closed_dirs)

	# ЕСЛИ ЭТО СКЛАД ТО ПОДКЛЮЧАЕМ ЕГО К ТАЙЛУ
	if info.is_storage:
		storage_node = get_node("storage")
		parent_tile.connect_local_storage(10) # ВМЕСТИМОСТЬ ДОЛЖНА ЗАВИСЕТЬ ОТ ТИПА FUR
		storage_node.set_z(parent_z_data.params.fur_f - 1)

	# ЕСЛИ FUR "ПРИЛИПАЕТ" К ДРУГОМУ ОБЪЕКТУ
	if info.is_sticks_to_other_obj:
		# ПРОВЕРЯЕМ ЕСТЬ ЛИ ВОКРУГ ТАЙЛА ЭТОТ ОБЪЕКТ
		var around_tiles = parent_tile.r.get_tiles_around_tile(parent_tile, false, false, false, true)
		var stick_tile = null

		for a_t in around_tiles:
			if a_t.is_has_furniture:
				var a_t_fur = a_t.get_furniture()
				
				# проверяем является ли fur объектом к которому этот fur должен прилипать
				for obj_type in info.addit.sticks_objs_types:
					if a_t_fur.info.obj == obj_type:
						stick_tile = a_t
						break
			if stick_tile != null:
				break

		# если такой тайл есть, передвигаем fur ближе к нему
		if stick_tile != null:
			var parent_t_pos = parent_tile.get_global_pos()
			var stick_t_pos = stick_tile.get_global_pos()

			var slide_range = 12

			var dx = 0
			var dy = 0

			if stick_t_pos.x < parent_t_pos.x:
				dx -= slide_range
			elif stick_t_pos.x > parent_t_pos.x:
				dx += slide_range
			elif stick_t_pos.y < parent_t_pos.y:
				dx -= 2
				dy -= slide_range
			elif stick_t_pos.y > parent_t_pos.y:
				dx -= 7
				dy += slide_range

			set_pos(Vector2(init_pos.x + dx, init_pos.y + dy))

	# НАСТРАИВАЕМ Z
	addit_gui_info.set_z(parent_z_data.params.fur_f + 1)

	is_empty = false

	set_process(true)

func setup_part_offset(_part, _offset, _custom_front_region = null):
	var part = _part
	
	var reg_rect = part.get_region_rect()

	var offset = _offset
	var custom_f_reg = _custom_front_region

	if custom_f_reg == null:
		reg_rect.pos.y *= offset.y
	else:
		reg_rect.pos.x *= custom_f_reg.x
		reg_rect.pos.y *= custom_f_reg.y

	part.set_region_rect(reg_rect)

func snap_ctx():
	GUI.ctx_menu.snap_to_node(parent_tile, GUI.CtxType.player_fur, info.obj)