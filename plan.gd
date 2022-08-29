extends Node

# SPDX-FileCopyrightText: 2021 University of Maryland
# SPDX-License-Identifier: BSD-3-Clause-Clear

# GT Project, version 1.1
# Author: Dana Nau <nau@umd.edu>, July 7, 2021
# Author: K. S. Ernest (iFire) Lee <ernest.lee@chibifire.com>, August 28, 2022

const domain_const = preload("res://domain.gd")
const blackboard_const = preload("res://blackboard.gd")

#"""
#GTPyhop is an automated planning system that can plan for both tasks and
#goals. It requires Python 3. 
#
#Accompanying this file are a README.md file giving an overview of GTPyhop,
#and several examples of how to use GTPyhop. To run them, try importing any
#of the modules in the Examples directory.
#"""

# For use in debugging:
# from IPython import embed
# from IPython.terminal.debugger import set_trace

################################################################################
# How much information to print while the program is running

var verbose = 1
#"""
#verbose is a global value whose initial value is 1. Its value determines how
#much debugging information GTPyhop will print:
# - verbose = 0: print nothing
# - verbose = 1: print the initial parameters and the answer
# - verbose = 2: also print a message on each recursive call
# - verbose = 3: also print some info about intermediate computations
#"""

################################################################################
# States and goals

# Sequence number to use when making copies of states.
var _next_state_number = 0


# Sequence number to use when making copies of multigoals.
var _next_multigoal_number = 0


class Multigoal:
	extends Resource
#	"""
#	g = Multigoal(goal_name, **kwargs) creates an object that represents
#	a conjunctive goal, i.e., the goal of reaching a state that contains
#	all of the state-variable bindings in g.
#	  - goal_name is the name to use for the new multigoal.
#	  - The keyword args are name and desired values of state variables.
#
#	Example: here are three equivalent ways to specify a goal named 'goal1'
#	in which boxes b and c are located in room2 and room3:
#		First:
#		   g = Multigoal('goal1')
#		   g.loc = {}   # create a dictionary for things like loc['b']
#		   g.loc['b'] = 'room2'
#		   g.loc['c'] = 'room3'
#		Second:
#		   g = Multigoal('goal1', loc={})
#		   g.loc['b'] = 'room2'
#		   g.loc['c'] = 'room3'
#		Third:
#		   g = Multigoal('goal1',loc={'b':'room2', 'c':'room3'})
#	"""

	func _init(multigoal_name):
#		"""
#		multigoal_name is the name to use for the multigoal. The keyword
#		args are the names and desired values of state variables.
#		"""
		set_name(multigoal_name)

	func get_string():
		return "<Multigoal %s>" % get_name()


	func display(heading=null):
#		"""
#		Print the multigoal's state-variables and their values.
#		 - heading (optional) is a heading to print beforehand.
#		"""
		print(heading)

	func state_vars():
#		"""Return a list of all state-variable names in the multigoal"""
		var variable_list : Array = []
		var properties : Array = get_property_list()
		for v in properties:
			for p in v.keys():
				if v != get_name():
					variable_list.push_back(v.get(p))
		return variable_list



################################################################################
# Auxiliary functions for state and multigoal objects.


func get_type(object):
#	"""Return object's type name"""
	return get_type(object).name


var current_domain = null
#"""
#The Domain object that find_plan, run_lazy_lookahead, etc., will use.
#"""

# Sequence number to use when making copies of domains.
var _next_domain_number = 0

# A list of all domains that have been created
@export var _domains : Array[Resource] = []


################################################################################
# Functions to print information about a domain


func print_domain(domain=null):
#	"""
#	Print domain's actions, commands, and methods. The optional 'domain'
#	argument defaults to the current domain
#	"""
	if domain == null:
		domain = current_domain
	print("Domain name: %s" % name)
	print_actions(domain)
	print_commands(domain)
	print_methods(domain)


func print_actions(domain=null):
#	"""Print the names of all the actions"""
	if domain == null:
		domain = current_domain
	if domain._action_dict:
		print("-- Actions:", ", ".join(domain._action_dict))
	else:
		print("-- There are no actions --")


func print_commands(domain=null):
#	"""Print the names of all the commands"""
	if domain == null:
		domain = current_domain
	if domain._command_dict:
		print("-- Commands:", ", ".join(domain._command_dict))
	else:
		print("-- There are no commands --")


func _print_task_methods(domain):
#	"""Print a table of the task_methods for each task"""
	if domain._task_method_dict:
		print("")
		print("Task name:         Relevant task methods:")
		print("---------------    ----------------------")
		for task in domain._task_method_dict:
			var string_array : Array = Array()
			for f in domain._task_method_dict[task]:
				string_array.append(f.name)
			print(
				"{task:<19}"
				+ ", ".join(string_array)
			)
		print("")
	else:
		print("-- There are no task methods --")


func _print_unigoal_methods(domain):
#	"""Print a table of the unigoal_methods for each state_variable_name"""
	if domain._unigoal_method_dict:
		print("Blackboard var name:    Relevant unigoal methods:")
		print("---------------    -------------------------")
		for v in domain._unigoal_method_dict:
			var string_array : PackedStringArray = PackedStringArray()
			for f in domain._unigoal_method_dict[v]:
				f.push_back(f.name)
			print(
				"{var:<19}"
				+ ", ".join(string_array)
			)
		print("")
	else:
		print("-- There are no unigoal methods --")


func _print_multigoal_methods(domain):
#	"""Print the names of all the multigoal_methods"""
	if domain._multigoal_method_list:
		var string_array : PackedStringArray = PackedStringArray()
		for f in domain._multigoal_method_list:
			f.push_back(f.name)
		print(
			"-- Multigoal methods:",
			", ".join(string_array),
		)
	else:
		print("-- There are no multigoal methods --")


func print_methods(domain=null):
#	"""Print tables showing what all the methods are"""
	if domain == null:
		domain = current_domain
	_print_task_methods(domain)
	_print_unigoal_methods(domain)
	_print_multigoal_methods(domain)


################################################################################
# Functions to declare actions, commands, tasks, unigoals, multigoals


func declare_actions(actions):
#	"""
#	declare_actions adds each member of 'actions' to the current domain's list
#	of actions. For example, this says that pickup and putdown are actions:
#		declare_actions(pickup,putdown)
#
#	declare_actions can be called multiple times to add more actions.
#
#	You can see the current domain's list of actions by executing
#		current_domain.display()
#	"""
#	if current_domain == None:
#		raise Exception(f"cannot declare actions until a domain has been created.")
	for action in actions:
		current_domain._command_dict.insert({action.name: action})
	return current_domain._action_dict


func declare_commands(commands):
#	"""
#	declare_commands adds each member of 'commands' to the current domain's
#	list of commands.  Each member of 'commands' should be a function whose
#	name has the form c_foo, where foo is the name of an action. For example,
#	this says that c_pickup and c_putdown are commands:
#		declare_commands(c_pickup,c_putdown)
#
#	declare_commands can be called several times to add more commands.
#
#	You can see the current domain's list of commands by executing
#		current_domain.display()
#
#	"""
#	if current_domain == None:
#		raise Exception(f"cannot declare commands until a domain has been created.")
	var command_array : PackedStringArray = PackedStringArray()
	for cmd in commands:
		command_array.push_back(cmd.name)
		current_domain._command_dict.insert({cmd.name: cmd})
	return current_domain._command_dict


func declare_task_methods(task_name, methods):
#	"""
#	'task_name' should be a character string, and 'methods' should be a list
#	of functions. declare_task_methods adds each member of 'methods' to the
#	current domain's list of methods to use for tasks of the form
#		(task_name, arg1, ..., argn).
#
#	Example:
#		declare_task_methods('travel', travel_by_car, travel_by_foot)
#	says that travel_by_car and travel_by_foot are methods and that GTPyhop
#	should try using them for any task whose task name is 'travel', e.g.,
#		('travel', 'alice', 'store')
#		('travel', 'alice', 'umd', 'ucla')
#		('travel', 'alice', 'umd', 'ucla', 'slowly')
#		('travel', 'bob', 'home', 'park', 'looking', 'at', 'birds')
#
#	This is like Pyhop's declare_methods function, except that it can be
#	called several times to declare more methods for the same task.
#	"""
	if current_domain == null:
		print("cannot declare methods until a domain has been created.")
		get_tree().quit()
	if task_name in current_domain._task_method_dict:
		var old_methods = current_domain._task_method_dict[task_name]
		# even though current_domain._task_method_dict[task_name] is a list,
		# we don't want to add any methods that are already in it
		var method_arrays : Array = []
		for m in methods:
			if m not in old_methods:
				method_arrays.push_back(m)
		current_domain._task_method_dict[task_name].extend(method_arrays)
	else:
		current_domain._task_method_dict.update({task_name: methods})
	return current_domain._task_method_dict


func declare_unigoal_methods(state_var_name, methods):
#	"""
#	'state_var_name' should be a character string, and 'methods' should be a
#	list of functions. declare_unigoal_method adds each member of 'methods'
#	to the current domain's list of relevant methods for goals of the form
#		(state_var_name, arg, value)
#	where 'arg' and 'value' are the state variable's argument and the desired
#	value. For example,
#		declare_unigoal_method('loc',travel_by_car)
#	says that travel_by_car is relevant for goals such as these:
#		('loc', 'alice', 'ucla')
#		('loc', 'bob', 'home')
#
#	The above kind of goal, i.e., a desired value for a single state
#	variable, is called a "unigoal". To achieve a unigoal, GTPyhop will go
#	through the unigoal's list of relevant methods one by one, trying each
#	method until it finds one that is successful.
#
#	To see each unigoal's list of relevant methods, use
#		current_domain.display()
#	"""
	if current_domain == null:
		print("cannot declare methods until a domain has been created.")
		get_tree().quit()
	if state_var_name not in current_domain._unigoal_method_dict:
		current_domain._unigoal_method_dict.update({state_var_name: methods})
	else:
		var old_methods = current_domain._unigoal_method_dict[state_var_name]
		var method_array : Array = []
		for m in methods:
			if m not in old_methods:
				method_array.push_back(m)
		current_domain._unigoal_method_dict[state_var_name].extend(method_array)
	return current_domain._unigoal_method_dict


func declare_multigoal_methods(methods):
#	"""
#	declare_multigoal_methods adds each method in 'methods' to the current
#	domain's list of multigoal methods. For example, this says that
#	stack_all_blocks and unstack_all_blocks are multigoal methods:
#		declare_multigoal_methods(stack_all_blocks, unstack_all_blocks)
#
#	When GTPyhop tries to achieve a multigoal, it will go through the list
#	of multigoal methods one by one, trying each method until it finds one
#	that is successful. You can see the list by executing
#		current_domain.display()
#
#	declare_multigoal_methods can be called multiple times to add more
#	multigoal methods to the list.
#
#	For more information, see the docstring for the Multigoal class.
#	"""
	if current_domain == null:
		print("cannot declare methods until a domain has been created.")
		get_tree().quit()
	var method_array : Array = []
	for m in methods:
		if m not in current_domain._multigoal_method_list:
			method_array.push_back(m)
	current_domain._multigoal_method_list.extend(method_array)
	return current_domain._multigoal_method_list


################################################################################
# A built-in multigoal method and its helper function.


func m_split_multigoal(state, multigoal):
#	"""
#	m_split_multigoal is the only multigoal method that GTPyhop provides,
#	and GTPyhop won't use it unless the user declares it explicitly using
#		declare_multigoal_methods(m_split_multigoal)
#
#	The method's purpose is to try to achieve a multigoal by achieving each
#	of the multigoal's individual goals sequentially. Parameters:
#		- 'state' is the current state
#		- 'multigoal' is the multigoal to achieve
#
#	If multigoal is true in the current state, m_split_multigoal returns
#	[]. Otherwise, it returns a goal list
#		[g_1, ..., g_n, multigoal],
#
#	where g_1, ..., g_n are all of the goals in multigoal that aren't true
#	in the current state. This tells the planner to achieve g_1, ..., g_n
#	sequentially, then try to achieve multigoal again. Usually this means
#	m_split_multigal will be used repeatedly, until it succeeds in producing
#	a state in which all of the goals in multigoal are simultaneously true.
#
#	The main problem with m_split_multigoal is that it isn't smart about
#	choosing the order in which to achieve g_1, ..., g_n. Some orderings may
#	work much better than others. Thus, rather than using the method as it's
#	defined below, one might want to modify it to choose a good order, e.g.,
#	by using domain-specific information or a heuristic function.
#	"""
	var goal_dict = domain_const._goals_not_achieved(state, multigoal)
	var goal_list = []
	for state_var_name in goal_dict:
		for arg in goal_dict[state_var_name]:
			var val = goal_dict[state_var_name][arg]
			goal_list.append([state_var_name, arg, val])
	if goal_list:
		# achieve goals, then check whether they're all simultaneously true
		return goal_list + [multigoal]
	return goal_list



################################################################################
# Functions to verify whether unigoal_methods achieve the goals they are
# supposed to achieve.


var verify_goals = true
#"""
#If verify_goals is True, then whenever the planner uses a method m to refine
#a unigoal or multigoal, it will insert a "verification" task into the
#current partial plan. If verify_goals is False, the planner won't insert any
#verification tasks into the plan.
#
#The purpose of the verification task is to raise an exception if the
#refinement produced by m doesn't achieve the goal or multigoal that it is
#supposed to achieve. The verification task won't insert anything into the
#final plan; it just will verify whether m did what it was supposed to do.
#"""


################################################################################
# Applying actions, commands, and methods


func _apply_action_and_continue(state, task1, todo_list, plan, depth):
#	"""
#	_apply_action_and_continue is called only when task1's name matches an
#	action name. It applies the action by retrieving the action's function
#	definition and calling it on the arguments, then calls seek_plan
#	recursively on todo_list.
#	"""
	if verbose >= 3:
		print("depth %s action %s: " % [depth, task1])
	var action = current_domain._action_dict[task1[0]]
	var typed_action : Callable = action
	var newstate = typed_action.call(state.duplicate(true), task1.slice(1))
	if newstate:
		if verbose >= 3:
			print("applied")
			newstate.display()
		return seek_plan(newstate, todo_list, plan + [task1], depth + 1)
	if verbose >= 3:
		print("not applicable")
	return false


func _refine_task_and_continue(state, task1, todo_list, plan, depth):
	return false
# TODO
##	"""
##	If task1 is in the task-method dictionary, then iterate through the list
##	of relevant methods to find one that's applicable, apply it to get
##	additional todo_list items, and call seek_plan recursively on
##			[the additional items] + todo_list.
##
##	If the call to seek_plan fails, go on to the next method in the list.
##	"""
	var relevant = current_domain._task_method_dict[task1[0]]
	if verbose >= 3:
		print("depth {depth} task {task1} methods {[m.__name__ for m in relevant]}")
	for method in relevant:
		var typed_method : Callable = method
		if verbose >= 3:
			print("depth {depth} trying {method.__name__}: ")
		var subtasks = typed_method.call(state, task1.slice(1))
		# Can't just say "if subtasks:", because that's wrong if subtasks == []
		if subtasks != false and subtasks != null:
			if verbose >= 3:
				print("applicable")
				print("depth {depth} subtasks: {subtasks}")
			var result = seek_plan(state, subtasks + todo_list, plan, depth + 1)
			if result != false and result != null:
				return result
		else:
			if verbose >= 3:
				print("not applicable")
	if verbose >= 3:
		print("depth {depth} could not accomplish task {task1}")
	return false

func _refine_unigoal_and_continue(state, goal1, todo_list, plan, depth):
##	"""
##	If goal1 is in the unigoal-method dictionary, then iterate through the
##	list of relevant methods to find one that's applicable, apply it to get
##	additional todo_list items, and call seek_plan recursively on
##		  [the additional items] + [verify_g] + todo_list,
##
##	where [verify_g] verifies whether the method actually achieved goal1.
##	If the call to seek_plan fails, go on to the next method in the list.
##	"""
	if verbose >= 3:
		print("depth {depth} goal {goal1}: ")
	var state_var_name = goal1[0]
	var arg = goal1[1]
	var val = goal1[2]
	if state.get(state_var_name).get(arg) == val:
		if verbose >= 3:
			print("already achieved")
		return seek_plan(state, todo_list, plan, depth + 1)
	var relevant = current_domain._unigoal_method_dict[state_var_name]
	if verbose >= 3:
		print("methods {[m.__name__ for m in relevant]}")
	for method in relevant:
		var method_typed : Callable = method
		if verbose >= 3:
			print("depth {depth} trying method {method.__name__}: ")
		var subgoals = method_typed.call(state, arg, val)
		# Can't just say "if subgoals:", because that's wrong if subgoals == []
		if subgoals != false and subgoals != null:
			var verification = []
			if verbose >= 3:
				print("applicable")
				print("depth {depth} subgoals: {subgoals}")
			if verify_goals:
				verification = [
					["_verify_g", method.name, state_var_name, arg, val, depth]
				]
			else:
				verification = []
			todo_list = subgoals + verification + todo_list
			var result = seek_plan(state, todo_list, plan, depth + 1)
			if result != false and result != null:
				return result
		else:
			if verbose >= 3:
				print("not applicable")
	if verbose >= 3:
		print("depth {depth} could not achieve goal {goal1}")
	return false

func _refine_multigoal_and_continue(state, goal1, todo_list, plan, depth):
	return false
# TODO
##	"""
##	If goal1 is a multigoal, then iterate through the list of multigoal
##	methods to find one that's applicable, apply it to get additional
##	todo_list items, and call seek_plan recursively on
##		  [the additional items] + [verify_mg] + todo_list,
##
##	where [verify_mg] verifies whether the method actually achieved goal1.
##	If the call to seek_plan fails, go on to the next method in the list.
##	"""
	if verbose >= 3:
		print("depth {depth} multigoal {goal1}: ")
	var relevant = current_domain._multigoal_method_list
	if verbose >= 3:
		print("methods {[m.__name__ for m in relevant]}")
	for method in relevant:
		var method_typed : Callable = method
		if verbose >= 3:
			print("depth {depth} trying method {method.__name__}: ")
		var subgoals = method_typed.call(state, goal1)
		# Can't just say "if subgoals:", because that's wrong if subgoals == []
		if subgoals != false and subgoals != null:
			var verification = []
			if verbose >= 3:
				print("applicable")
				print("depth {depth} subgoals: {subgoals}")
			if verify_goals:
				verification = [["_verify_mg", method.name, goal1, depth]]
			else:
				verification = []
			todo_list = subgoals + verification + todo_list
			var result = seek_plan(state, todo_list, plan, depth + 1)
			if result != false and result != null:
				return result
		else:
			if verbose >= 3:
				print("not applicable")
	if verbose >= 3:
		print("depth {depth} could not achieve multigoal {goal1}")
	return false


############################################################
# The planning algorithm


func find_plan(state, todo_list):
#	"""
#	find_plan tries to find a plan that accomplishes the items in todo_list,
#	starting from the given state, using whatever methods and actions you
#	declared previously. If successful, it returns the plan. Otherwise it
#	returns False. Arguments:
#	 - 'state' is a state;
#	 - 'todo_list' is a list of goals, tasks, and actions.
#	"""
	if verbose >= 1:
		var todo_string_array : PackedStringArray = PackedStringArray()
		for x in todo_list:
			todo_string_array.push_back(x)
		var todo_string = "[" + ", ".join(todo_string_array) + "]"
		print("FP> find_plan, verbose={verbose}:")
		print("    state = %s\n    todo_list = %s" % [state.get_name(), todo_string])
	var result = seek_plan(state, todo_list, [], 0)
	if verbose >= 1:
		print("FP> result =", result, "\n")
	return result


func seek_plan(state, todo_list, plan, depth):
#	"""
#	Workhorse for find_plan. Arguments:
#	 - state is the current state
#	 - todo_list is the current list of goals, tasks, and actions
#	 - plan is the current partial plan
#	 - depth is the recursion depth, for use in debugging
#	"""
	if verbose >= 2:
		var todo_array : PackedStringArray = []
		for x in todo_list:
			todo_array.push_back(_item_to_string(x))
		var todo_string = "[" + ", ".join(todo_array) + "]"
		print("depth {depth} todo_list " + todo_string)
	if todo_list == []:
		if verbose >= 3:
			print("depth {depth} no more tasks or goals, return plan")
		return plan
	var item1 = todo_list[0]
	var ttype = get_type(item1)
	if ttype == ["Multigoal"]:
		return _refine_multigoal_and_continue(state, item1, todo_list.slice(1), plan, depth)
	elif ttype in ["list", "tuple"]:
		if item1[0] in current_domain._action_dict:
			return _apply_action_and_continue(state, item1, todo_list.slice(1), plan, depth)
		elif item1[0] in current_domain._task_method_dict:
			return _refine_task_and_continue(state, item1, todo_list.slice(1), plan, depth)
		elif item1[0] in current_domain._unigoal_method_dict:
			return _refine_unigoal_and_continue(
				state, item1, todo_list.slice(1), plan, depth
			)
	print("depth {depth}: {item1} isn't an action, task, unigoal, or multigoal\n")
	get_tree().quit(1)
	return false


func _item_to_string(item):
#	"""Return a string representation of a task or goal."""
	var ttype = get_type(item)
	if ttype == "list":
		var list_array : PackedStringArray = []
		for x in item:
			list_array.push_back(x)
		return list_array
	else:  # a multigoal
		return item


################################################################################
# An actor


func run_lazy_lookahead(state, todo_list, max_tries=10):
#	"""
#	An adaptation of the run_lazy_lookahead algorithm from Ghallab et al.
#	(2016), Automated Planning and Acting. It works roughly like this:
#		loop:
#			plan = find_plan(state, todo_list)
#			if plan = [] then return state    // the new current state
#			for each action in plan:
#				try to execute the corresponding command
#				if the command fails, continue the outer loop
#	Arguments:
#	  - 'state' is a state;
#	  - 'todo_list' is a list of tasks, goals, and multigoals;
#	  - max_tries is a bound on how many times to execute the outer loop.
#
#	Note: whenever run_lazy_lookahead encounters an action for which there is
#	no corresponding command definition, it uses the action definition instead.
#	"""

	if verbose >= 1:
		print("RLL> run_lazy_lookahead, verbose = {verbose}, max_tries = {max_tries}")
		print("RLL> initial state: {state.__name__}")
		print("RLL> To do:", todo_list)

	for tries in range(1, max_tries + 1):
		if verbose >= 1:
			var ordinals = {1: "st", 2: "nd", 3: "rd"}
			if ordinals.get(tries):
				print("RLL> {tries}{ordinals.get(tries)} call to find_plan:\n")
			else:
				print("RLL> {tries}th call to find_plan:\n")
		var plan = find_plan(state, todo_list)
		if plan == false or plan == null:
			if verbose >= 1:
				print("run_lazy_lookahead: find_plan has failed")
				get_tree().quit(1)
			return state
		if plan == []:
			if verbose >= 1:
				print(
					"RLL> Empty plan => success\n" +  "after {tries} calls to find_plan."
				)
			if verbose >= 2:
				state.display("> final state")
			return state
		for action in plan:
			var command_name = "c_" + action[0]
			var command_func : Callable = current_domain._command_dict.get(command_name)
			if command_func == null:
				if verbose >= 1:
					print(
						"RLL> {command_name} not defined, using {action[0]} instead\n"
					)
				command_func = current_domain._action_dict.get(action[0])

			if verbose >= 1:
				print("RLL> Command: %s" % [[command_name] + action.slice(1)])
			var new_state = _apply_command_and_continue(state, command_func, action.slice(1))
			if new_state == false:
				if verbose >= 1:
					print(
						"RLL> WARNING: command {command_name} failed; will call find_plan."
					)
					break
			else:
				if verbose >= 2:
					new_state.display()
				state = new_state
		# if state != False then we're here because the plan ended
		if verbose >= 1 and state:
			print("RLL> Plan ended; will call find_plan again.")

	if verbose >= 1:
		print("RLL> Too many tries, giving up.")
	if verbose >= 2:
		state.display("RLL> final state")
	return state


func _apply_command_and_continue(state, command : Callable, args):
	return false
#	"""
#	_apply_command_and_continue applies 'command' by retrieving its
#	function definition and calling it on the arguments.
#	"""
	if verbose >= 3:
		print("_apply_command_and_continue {command.__name__}, args = {args}")
	var next_state = command.call(state.duplicate(true), args)
	if next_state:
		if verbose >= 3:
			print("applied")
			next_state.display()
		return next_state
	else:
		if verbose >= 3:
			print("not applicable")
		return false

