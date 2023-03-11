extends CharacterBody2D

var acceleration: int = 250
var max_speed: int = 500
var rotation_speed: int = 150
var inertia = 50
var direction: Vector2
var player_character = null
var last_damage = 0
var _jumping = false
var _accelerating = false

@onready var flame_exhaust: Node2D = $Ship_Exhaust


func _ready() -> void:
	velocity = Vector2.ZERO
	flame_exhaust.hide()


func _physics_process(delta: float) -> void:
	direction = Vector2(cos(self.rotation + PI/2), sin(self.rotation + PI/2))
	if Input.is_action_pressed("move_forward"):
		_start_accelerating()
	
	if Input.is_action_just_released("move_forward"):
		_stop_accelerating()
	
	if Input.is_action_pressed("flip_maneuver") && velocity.length() > 0:
		_do_flip(delta)
	elif Input.is_action_pressed("rotate_left"):
		rotation_degrees -= rotation_speed * delta
	elif Input.is_action_pressed("rotate_right"):
		rotation_degrees += rotation_speed * delta
	
	if Input.is_action_pressed("jump"):
		var warning = _jump_warning()
		if warning == '':
			if velocity.length() > 0:
				var flip_complete = _do_flip(delta)
				if flip_complete:
					print("velocity", velocity.length())
					if velocity.length() > acceleration * delta:
						_start_accelerating()
					else:
						_stop_accelerating()
						velocity = Vector2.ZERO
			else:
				_do_jump()
		elif Input.is_action_just_pressed("jump"):
			print(warning)
	elif Input.is_action_just_released("jump"):
		if !Input.is_action_pressed("move_forward"):
			_stop_accelerating()
				
	if _accelerating:
		velocity = velocity.move_toward(direction * max_speed, acceleration * delta)
	
	if _apply_collision_knockback_damage():
		velocity = velocity * -1
	
	if GameState.player.hull_health <= 0: 
		queue_free()

	GameState.player.position = self.position
	
	set_velocity(velocity)
	direction = Vector2(0, 0)
	set_floor_stop_on_slope_enabled(false)
	set_max_slides(4)
	set_floor_max_angle(PI/4)
	# TODOConverter40 infinite_inertia were removed in Godot 4.0 - previous value `false`
	move_and_slide()
	velocity = velocity
	
func _do_flip(delta):
	var total_degrees_to_rotate = rad_to_deg(direction.angle_to(velocity.rotated(PI)))
	var frame_degrees_to_rotate = rotation_speed * delta
	if frame_degrees_to_rotate >= abs(total_degrees_to_rotate):
		rotation = velocity.rotated(PI).angle() - PI / 2
		return true
	else:
		var rotation_direction = total_degrees_to_rotate / abs(total_degrees_to_rotate)
		rotation_degrees += rotation_direction * frame_degrees_to_rotate
		return false
		
func _do_jump():
	GameState.player.system_id = GameState.player.nav_route.pop_front()

func _start_accelerating():
	if !_accelerating:
		_accelerating = true
		flame_exhaust.show()
		flame_exhaust.play()
	
func _stop_accelerating():
	if _accelerating:
		_accelerating = false
		flame_exhaust.stop()
		flame_exhaust.frame = 0
		flame_exhaust.hide()
		flame_exhaust.animation = "acceleration"


func _on_AnimatedSprite_animation_finished() -> void:
	flame_exhaust.animation = "max-speed"


func _apply_collision_knockback_damage()-> bool:
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		
		if collider is RigidBody2D:
			collider.apply_central_impulse(-collision.get_normal() * inertia)
		
			if i > 0 and collision.get_collider_id() == get_slide_collision(i -1).get_collider_id():  
				continue
		
			if Time.get_ticks_msec() - last_damage > 250:
				GameState.player.hull_health = GameState.player.hull_health - collider.damage
				last_damage = Time.get_ticks_msec()
				
			return true
		
	return false
	
func _get_closest_planet():
	var planets = get_tree().get_nodes_in_group("Planets")
	var closest_planet = planets[0]
	
	for planet in planets:
		var planetsize = planet.get_node("Selection").get_node_size()
		var closestplanetsize = closest_planet.get_node("Selection").get_node_size()
		if planet.global_position.distance_to(global_position) - planetsize < closest_planet.global_position.distance_to(global_position) - closestplanetsize:
			closest_planet = planet
	
	return closest_planet

func handle_landing_request():
	var closest_planet = _get_closest_planet()
	var speed_check = velocity.length()

	if GameState.player.selection != null:
		GameState.player.selection.get_node("Selection").visible = false
	
	GameState.player.selection = closest_planet
	GameState.player.selection.get_node("Selection").visible = true
	
	if speed_check > 50:
		print ("Moving too fast, slow down")
	else:
		var planetsize = closest_planet.get_node("Selection").get_node_size()
		var distance_check = closest_planet.global_position.distance_to(global_position) - planetsize
		print ("distance to planet ", distance_check)
		if distance_check > 150:
			print ("You have to get closer if you're trying to land")
		else:
			print ("Landing sequence initiated")
			GameState.player.planet_id = closest_planet.planet_data.id
			GameState.scene = Constants.SceneId.PlanetSurface

func _jump_warning() -> String:
	if GameState.player.nav_route.size() == 0:
		var x = InputMap.action_get_events("toggle_system_map")
		return 'Press "'+OS.get_keycode_string(x[0].keycode)+'" to open the map to set where you would like to jump'
	var closest_planet = _get_closest_planet()
	if global_position.distance_to(closest_planet.global_position) < 700:
		return "You are too close to the system center. Move away from planets before jumping."
	return ''

func _unhandled_key_input(event):
	if event.is_action_pressed("select_planet"):
		handle_landing_request()
#	if event.is_action_pressed("jump"):
#		handle_jump_request()


	
