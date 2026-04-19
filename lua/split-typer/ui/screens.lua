local course = require("split-typer.ui.screens.course")
local menus = require("split-typer.ui.screens.menus")
local results = require("split-typer.ui.screens.results")

local M = {}

M.show_course = course.show_course
M.show_course_results = course.show_course_results

M.show_combo_menu = menus.show_combo_menu
M.show_reaction_menu = menus.show_reaction_menu
M.show_transition_menu = menus.show_transition_menu
M.show_benchmark_menu = menus.show_benchmark_menu
M.show_menu = menus.show_menu
M.show_group = menus.show_group
M.show_timed_menu = menus.show_timed_menu

M.show_combo_results = results.show_combo_results
M.show_reaction_results = results.show_reaction_results
M.show_results = results.show_results
M.show_dashboard = results.show_dashboard

return M
