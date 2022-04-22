extends PanelContainer

const AdvancedExpression = preload("res://advanced_expression.gd")

onready var input := $HSplitContainer/VSplitContainer/InputContainer/Input as TextEdit
onready var input_name := $HSplitContainer/VSplitContainer/VSplitContainer/VBoxContainer/VBoxContainer/HBoxContainer/InputName as LineEdit
onready var var_list := $HSplitContainer/Variables/ScrollContainer/VarList as VBoxContainer
onready var status := $HSplitContainer/VSplitContainer/VSplitContainer/Status as TextEdit

var state := {}

# Store as a string because AdvancedExpression automatically converts this back to the appropriate type
var last_result := ""

###############################################################################
# Builtin functions                                                           #
###############################################################################

func _ready() -> void:
	OS.center_window()
	
	$HSplitContainer/VSplitContainer/InputContainer/SendIt.connect("pressed", self, "_on_send_it")
	
	$HSplitContainer/VSplitContainer/VSplitContainer/VBoxContainer/VBoxContainer/ControlBar/ClearInput.connect(
		"pressed",
		self,
		"_on_clear_input"
	)
	
	$HSplitContainer/VSplitContainer/VSplitContainer/VBoxContainer/VBoxContainer/ControlBar/ResetState.connect(
		"pressed",
		self,
		"_on_reset_state"
	)
	
	$HSplitContainer/VSplitContainer/VSplitContainer/VBoxContainer/VBoxContainer/HBoxContainer/StoreInput.connect(
		"pressed",
		self,
		"_on_store_input"
	)
	
	input_name.connect("text_entered", self, "_on_input_name_enter_pressed")
	
	for c in $HSplitContainer/VSplitContainer/VSplitContainer/VBoxContainer/ActionPad.get_children():
		c.connect("pressed", self, "_on_action_pad_pressed", [c.text])
	
	input.connect("gui_input", self, "_on_input_gui_input")

###############################################################################
# Connections                                                                 #
###############################################################################

func _on_send_it() -> void:
	_execute()

func _on_clear_input() -> void:
	input.text = ""

func _on_reset_state() -> void:
	_clear_variables()

func _on_store_input() -> void:
	_on_input_name_enter_pressed(input_name.text)

func _on_input_name_enter_pressed(text: String) -> void:
	if text.length() < 1:
		status.text = "Storing input requires a variable name"
		return
	
	if input.text.length() < 1:
		status.text = "Storing input requires something to be in the input field"
		return
	
	_store_variable(text, input.text)
	
	status.text = "Stored %s as %s" % [input.text, text]
	input_name.text = ""

func _on_action_pad_pressed(text: String) -> void:
	if text == "=":
		_execute()
		return
	
	input.text += text

func _on_input_gui_input(ie: InputEvent) -> void:
	if ie is InputEventKey:
		if ie.control and ie.scancode == KEY_ENTER and ie.pressed:
			input.text = input.text.rstrip("\n")
			_execute()
			

###############################################################################
# Private functions                                                           #
###############################################################################

func _execute() -> void:
	"""
	Try executing whatever is in the input field.
	
	The execution is tried in this order:
		1. Expression - Godot's built-in Expression class
		2. AdvancedExpression - A helper class for builing GDScripts on-the-fly
	
	After execution, the result is stored back into the input field and the
	status bar is updated.
	"""
	var initial_input := input.text
	if _use_expression() == OK:
		status.text = "%s: Success" % initial_input
		return
	
	var ae := AdvancedExpression.new()
	
	for key in state.keys():
		ae.add_variable(key, state[key])
	
	if input.text.split("\n").size() == 1:
		ae.add("return %s" % input.text)
	else:
		ae.add(input.text)
	
	if ae.compile() == OK:
		var result = ae.execute()
		
		if result == null:
			input.text = ""
			last_result = ""
			status.text = "%s: null return value" % initial_input
		else:
			match typeof(result):
				TYPE_VECTOR2:
					input.text = "Vector2%s" % str(result)
				TYPE_VECTOR3:
					input.text = "Vector3%s" % str(result)
				_:
					input.text = str(result)
			last_result = input.text
			status.text = "%s: Success" % initial_input
	else:
		status.text = "%s: Failed" % initial_input

func _use_expression() -> int:
	var e := Expression.new()
		
	var parse_input := PoolStringArray()
	var execute_input := []
	if last_result.is_valid_float():
		parse_input.append("result")
		execute_input.append(last_result.to_float())
	
	if e.parse(input.text, parse_input) != OK:
		return ERR_PARSE_ERROR
	
	var result = e.execute(execute_input)
	
	if e.has_execute_failed():
		return ERR_BUG
	else:
		input.text = str(result)
		last_result = input.text
		return OK

func _store_variable(key: String, value: String) -> void:
	"""
	All variables are stored as strings and then reparsed/converted during execution
	
	Every variable is also tracked visually by adding the key/value pair to a list
	"""
	state[key] = value
	
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	for i in [key, ":", value]:
		hbox.add_child(_create_stretched_label(i))
	
	var_list.add_child(hbox)

func _create_stretched_label(text: String) -> Label:
	var label := Label.new()
	
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = text
	
	return label

func _clear_variables() -> void:
	state.clear()
	
	for c in var_list.get_children():
		c.queue_free()

###############################################################################
# Public functions                                                            #
###############################################################################
