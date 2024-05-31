package main

import "core:fmt"

test_passing_array :: proc(inp: []int) {
	inp[0] = 1
}

main :: proc() {
	global_frames: [10]int
	fmt.println(global_frames)
	test_passing_array(global_frames[:])
	fmt.println(global_frames)
}
