package main

import "base:runtime"
import "core:dynlib"
import "core:fmt"
import "core:os"
import "core:strings"

import rl "vendor:raylib"

SCREEN_WIDTH_PX :: 800
SCREEN_HEIGHT_PX :: 600

Plug :: struct {
	version: uint,
	music:   rl.Music,
}

library: dynlib.Library
plug_init: proc(plug: ^Plug, file_path: cstring)
plug_pre_reload: proc(plug: ^Plug)
plug_post_reload: proc(plug: ^Plug)
plug_update: proc(plug: ^Plug)
plug_terminate: proc(plug: ^Plug)

plug: Plug = {}

load_plugin_proc :: proc() -> bool {
	if library != nil {
		did_unloaded := dynlib.unload_library(library)
		if did_unloaded {
			fmt.println("[NOTE] Unloaded library!")
			library = nil
		} else {
			fmt.println("[NOTE] Failed to unload_library!")
		}
	}

	loaded: bool
	library, loaded = dynlib.load_library("bin/plug.dylib")
	if !loaded {
		fmt.eprintfln("Failed to load plug.dylib: %s", dynlib.last_error())
		return false
	}

	plug_init_addr, found1 := dynlib.symbol_address(library, "plug_init")
	if !found1 {
		fmt.eprintfln("Failed to find 'plug_init' in plug.dylib")
		return false
	}
	plug_init = cast(proc(_: ^Plug, _: cstring))plug_init_addr

	plug_update_addr, found2 := dynlib.symbol_address(library, "plug_update")
	if !found2 {
		fmt.eprintfln("Failed to find 'plug_update' in plug.dylib")
		return false
	}
	plug_update = cast(proc(_: ^Plug))plug_update_addr

	plug_terminate_addr, found3 := dynlib.symbol_address(library, "plug_terminate")
	if !found3 {
		fmt.eprintfln("Failed to find 'plug_terminate' in plug.dylib")
		return false
	}
	plug_terminate = cast(proc(_: ^Plug))plug_terminate_addr

	plug_pre_reload_addr, found4 := dynlib.symbol_address(library, "plug_pre_reload")
	if !found4 {
		fmt.eprintfln("Failed to find 'plug_pre_reload' in plug.dylib")
		return false
	}
	plug_pre_reload = cast(proc(_: ^Plug))plug_pre_reload_addr

	plug_post_reload_addr, found5 := dynlib.symbol_address(library, "plug_post_reload")
	if !found5 {
		fmt.eprintfln("Failed to find 'plug_post_reload' in plug.dylib")
		return false
	}
	plug_post_reload = cast(proc(_: ^Plug))plug_post_reload_addr

	return true
}

main :: proc() {
	if !load_plugin_proc() {
		fmt.panicf("Failed to load plugin")
	}

	program := os.args[0]
	arguments := os.args[1:]
	if len(arguments) == 0 {
		fmt.panicf("Usage: %s <input>\nError: no input file provided\n", program)
	}

	rl.SetConfigFlags({.WINDOW_HIGHDPI})
	rl.SetTargetFPS(60)

	rl.InitWindow(SCREEN_WIDTH_PX, SCREEN_HEIGHT_PX, "Musializer")
	defer rl.CloseWindow()

	rl.InitAudioDevice()
	defer rl.CloseAudioDevice()

	file_path, errno := strings.clone_to_cstring(arguments[0])
	if errno != runtime.Allocator_Error.None {
		fmt.panicf("Failed to read value of input file path: %v", errno)
	}

	plug_init(&plug, file_path)
	defer plug_terminate(&plug)

	for !rl.WindowShouldClose() {
		if rl.IsKeyPressed(rl.KeyboardKey.R) {
			plug_pre_reload(&plug)
			if !load_plugin_proc() {
				fmt.panicf("Failed to reload plugin")
			}
			plug_post_reload(&plug)
		}

		plug_update(&plug)
	}

	fmt.println("End of main")
}

// sample_interpolate :: proc(value: i16, upper_bound: int, positive: bool) -> i32 {
// 	max := positive ? c.INT16_MAX : c.INT16_MIN
// 	t := cast(f16)value / cast(f16)max
// 	return cast(i32)(cast(f16)upper_bound * t)
// }
