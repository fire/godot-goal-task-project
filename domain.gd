extends Resource

# SPDX-FileCopyrightText: 2021 University of Maryland
# SPDX-License-Identifier: BSD-3-Clause-Clear

# GT Project, version 1.1
# Author: Dana Nau <nau@umd.edu>, July 7, 2021
# Author: K. S. Ernest (iFire) Lee <ernest.lee@chibifire.com>, August 28, 2022

################################################################################
# A class for holding planning-and-acting domains.

#	"""
#	d = Domain(domain_name) creates an object to contain the actions, commands,
#	and methods for a planning-and-acting domain. 'domain_name' is the name to
#	use for the new domain.
#	"""

const verbose : int = 1

static func _m_verify_g(state, _method, state_var, arg, desired_val, _depth):
#	"""
#	_m_verify_g is a method that GTPyhop uses to check whether a
#	unigoal method has achieved the goal for which it was used.
#	"""
	if state[state_var][arg] != desired_val:
		print(
			"depth {depth}: method {method} didn't achieve\n" +
			"goal {state_var}[{arg}] = {desired_val}",)
		return []
	if verbose >= 3:
		print(
			"depth {depth}: method {method} achieved\n" +
			"goal {state_var}[{arg}] = {desired_val}"
		)
	return []  # i.e., don't create any subtasks or subgoals


# helper function for m_split_multigoal above:
static func _goals_not_achieved(state, multigoal):
#	"""
#	_goals_not_achieved takes two arguments: a state s and a multigoal g.
#	It returns a dictionary of the goals in g that aren't true in s.
#	For example, suppose
#		s.loc['c0'] = 'room0', g.loc['c0'] = 'room0',
#		s.loc['c1'] = 'room1', g.loc['c1'] = 'room3',
#		s.loc['c2'] = 'room2', g.loc['c2'] = 'room4'.
#	Then _goals_not_achieved(s, g) will return
#		{'loc': {'c1': 'room3', 'c2': 'room4'}}
#	"""
	var unachieved = {}
	for n in multigoal:
		for arg in multigoal.get(n):
			var val = multigoal.get(n).get(arg)
			if val != state.get(n).get(arg):
				# want arg_value_pairs.name[arg] = val
				if not unachieved.get(n):
					unachieved.update({n: {}})
				unachieved.get(n).update({arg: val})
	return unachieved

static func _m_verify_mg(state, method, multigoal, depth):
#	"""
#	_m_verify_g is a method that GTPyhop uses to check whether a multigoal
#	method has achieved the multigoal for which it was used.
#	"""
	var goal_dict = _goals_not_achieved(state, multigoal)
	if goal_dict:
		print("depth {depth}: method %s " % method + "didn't achieve %s" % multigoal)
		return []
	if verbose >= 3:
		print("depth %s: method %s achieved %s" %[depth, method, multigoal])
	return []
	
func _init(domain_name):
#		"""domain_name is the name to use for the domain."""

	self.__name__ = domain_name

	# dictionary that maps each action name to the corresponding function
	self._action_dict = {}

	# dictionary that maps each command name to the corresponding function
	self._command_dict = {}

	# dictionary that maps each task name to a list of relevant methods
	# _verify_g and _verify_mg are described later in this file.
	self._task_method_dict = {
		"_verify_g": [_m_verify_g],
		"_verify_mg": [_m_verify_mg],
	}

	# dictionary that maps each unigoal name to a list of relevant methods
	self._unigoal_method_dict = {}

	# list of all methods for multigoals
	self._multigoal_method_list = []

func get_string():
	return "<Domain %s>" % get_name()


func display():
#	"""Print the domain's actions, commands, and methods."""
	print(self)
