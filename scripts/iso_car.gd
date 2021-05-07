extends Node2D

enum SIT_TYPE {DRIVER, PASSENGER}

onready var texture = get_node("main/img")

var r

var info 

var tile_size = 80
var map_pos = null

var tile_map_symbol

# CAR PLACES ON 2 TILES AT THE SAME TIME
var main_current_tile = null
var second_current_tile = null

func _ready():
	r = get_parent().get_parent()

func put_unit_inside(_u, _sit_type = SIT_TYPE.PASSENGER):
	if info != null:
		var u = _u
		var sit_type = _sit_type

		if sit_type == SIT_TYPE.DRIVER:
			info.add_unit_info(u.info, true)
		else:
			info.add_unit_info(u.info, false)

		u.info.set_cur_car(info, self)
		
		#u.info.cur_car_node = self

		u.remove()
	else:
		print("info = null")

# УДАЛЯЕТ ВСЕХ ЮНИТОВ ИЗ МАШИНЫ И ДОБАВЛЯЕТ ИХ В КОМНАТУ
func remove_all_units():
	var loc_units_inside = info.units_inside + []
	
	# водитель высаживается в определенном тайле и удаляется из массива юнитов
	
	if info.unit_driver != null:
		var u_driver = info.unit_driver
		loc_units_inside.erase(u_driver)
		# проверяем что тайл сверху существует и не заблокирован
		var driver_t = r.get_tile_nearest_tile_in_dir(main_current_tile, SYS.DIR.UP)
		if driver_t != null and driver_t.get_contains_car() == null and !driver_t.is_has_furniture:
			remove_unit_by_info(u_driver, driver_t)
		else:
			print("driver tile blocked or equal null")
	
	# остальные юниты высаживаются на определенные тайлы по заданной очереди
	# когда очередь заканчивается тайл выбирается случайно
	for i in range(loc_units_inside.size()):
		var cur_unit_info = loc_units_inside[i]
		var cur_target_t
		if i == 0:
			cur_target_t = r.get_tile_nearest_tile_in_dir(main_current_tile, SYS.DIR.DOWN)
		elif i == 1:
			cur_target_t = r.get_tile_nearest_tile_in_dir(second_current_tile, SYS.DIR.UP)
		elif i == 2 or i == 3:
			cur_target_t = r.get_tile_nearest_tile_in_dir(second_current_tile, SYS.DIR.DOWN)
		
		# если подходящий тайл не найден или заблокирован, высаживаем юнитов справа от машины
		if cur_target_t == null or cur_target_t.get_contains_car() != null or \
			cur_target_t.is_has_furniture or cur_target_t.is_all_ways_blocked():
			
			cur_target_t = r.get_tile_nearest_tile_in_dir(main_current_tile, SYS.DIR.RIGHT)
		
		remove_unit_by_info(cur_unit_info, cur_target_t)

	info.unit_driver = null
	info.units_inside = []

# УДАЛЯЕТ ЮНИТА ИЗ МАШИНЫ И ДОБАВЛЯЕТ ЕГО В КОМНАТУ
func remove_unit_by_info(_u_info, _target_tile = null):
	var u_info = _u_info
	var target_tile = _target_tile # тайл на который переместится юнит после высадки

	info.remove_unit_info(u_info)

	u_info.cur_car_node = null

	if target_tile == null:
		target_tile = main_current_tile # FIX THAT, CARS NOW SOLID
		
	r.room.add_human(u_info, target_tile.get_tms().map_pos)

func remove():
	r.cars.erase(self)

	main_current_tile.remove_contains_car()
	second_current_tile.remove_contains_car()

	queue_free()

func set_info(_i):
	info = _i

	texture.set_region_rect(Rect2(160 * info.img_offset.x, 80 * info.img_offset.y, 160, 80))

func set_current_tile(_t):	
	main_current_tile = _t
	main_current_tile.set_contains_car(self)

	var mct_left_tile_tms = main_current_tile.tile_map_symbol.NearestTiles.left
	if mct_left_tile_tms != null:
		second_current_tile = r.get_tile_by_tms(mct_left_tile_tms)
		second_current_tile.set_contains_car(self)

	set_z(main_current_tile.get_z() + 15)

	set_global_pos(_t.get_global_pos())
