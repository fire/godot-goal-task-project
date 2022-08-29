extends Resource

# SPDX-FileCopyrightText: 2021 University of Maryland
# SPDX-License-Identifier: BSD-3-Clause-Clear

# GT Project, version 1.1
# Author: Dana Nau <nau@umd.edu>, July 7, 2021
# Author: K. S. Ernest (iFire) Lee <ernest.lee@chibifire.com>, August 28, 2022

#	"""
#	s = Blackboard(state_name, **kwargs) creates an object that contains the
#	state-variable bindings for a state-of-the-world.
#	  - state_name is the name to use for the new state.
#	  - The keyword args are the names and initial values of state variables.
#		A state-variable's initial value is usually {}, but it can also
#		be a dictionary of arguments and their initial values.
#
#	Example: here are three equivalent ways to specify a state named 'foo'
#	in which boxes b and c are located in room2 and room3:
#		First:
#		   s = Blackboard('foo')
#		   s.loc = {}   # create a dictionary for things like loc['b']
#		   s.loc['b'] = 'room2'
#		   s.loc['c'] = 'room3'
#		Second:
#		   s = Blackboard('foo',loc={})
#		   s.loc['b'] = 'room2'
#		   s.loc['c'] = 'room3'
#		Third:
#		   s = Blackboard('foo',loc={'b':'room2', 'c':'room3'})
#	"""

func _init(state_name):
#		"""
#		state_name is the name to use for the state. The keyword
#		args are the names and initial values of state variables.
#		"""
	set_name(state_name)

func get_string():
	return "<Blackboard %s>" % [get_name()]

func display(heading=null):
#		"""
#		Print the state's state-variables and their values.
#		 - heading (optional) is a heading to print beforehand.
#		"""
	print(heading)

func state_vars():
#		"""Return a list of all state-variable names in the state"""
	var variable_list : Array = []
	var properties : Array[Dictionary] = get_property_list()
	for v in properties:
		for d in v.keys():
			if d != get_name():
				variable_list.push_back(v.get(d))
	return variable_list
