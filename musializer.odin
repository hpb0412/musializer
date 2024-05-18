package main

import "base:runtime"
import "core:c"
import "core:c/libc"
import "core:dynlib"
import "core:fmt"
import "core:math"
import "core:math/cmplx"
import "core:mem"
import "core:os"
import "core:strings"
import rl "vendor:raylib"


cexp :: proc(x: f32) -> complex64 {
	// return cast(complex64)math.cos(x) + (1i * cast(complex64)math.sin(x))
	return cmplx.exp(1i * cast(complex64)x)
}

fft :: proc(inp: []f32, stride: uint, n: uint, out: []complex64) {
	assert(n > 0)

	if n == 1 {
		out[0] = inp[0]
		return
	}

	half := n / 2

	// even
	fft(inp[:], stride * 2, half, out[:])
	// odd
	fft(inp[stride:], stride * 2, half, out[half:])

	for k := 0; k < cast(int)half; k += 1 {
		t := cast(f32)k / cast(f32)n
		v := cexp(-2 * math.PI * t) * out[k + cast(int)half]
		e := out[k]
		out[k] = e + v
		out[k + cast(int)half] = e - v
	}
}

Frame :: struct {
	left:  f32,
	right: f32,
}

SCREEN_WIDTH_PX :: 800
SCREEN_HEIGHT_PX :: 600
// ARR_LENGTH :: 4800
// global_frames: [ARR_LENGTH]Frame
// global_frames_count: u32 = 0

// N :: 256
N :: (1 << 14) // 16384
inp: [N]f32
out: [N]complex64
max_amp: f32 = 0

amp :: proc(c: complex64) -> f32 {
	a := abs(real(c))
	b := abs(imag(c))
	if a < b {
		return b
	} else {
		return a
	}
}

callback: rl.AudioCallback = proc "c" (bufferData: rawptr, frames: u32) {
	context = runtime.default_context()

	frames := frames

	if frames > N {
		frames = N
	}

	frameData := transmute([^]Frame)bufferData

	for i in 0 ..< frames {
		// fmt.println(i)
		inp[i] = frameData[i].left
	}

	// context = runtime.default_context()
	//
	// if frames <= ARR_LENGTH - global_frames_count {
	// 	mem.copy(
	// 		mem.ptr_offset(&global_frames[0], global_frames_count),
	// 		bufferData,
	// 		size_of(Frame) * cast(int)frames,
	// 	)
	// 	global_frames_count += frames
	// } else if frames <= ARR_LENGTH {
	// 	libc.memmove(
	// 		&global_frames[0],
	// 		mem.ptr_offset(&global_frames[0], frames),
	// 		size_of(Frame) * cast(uint)(ARR_LENGTH - frames),
	// 	)
	// 	mem.copy(
	// 		mem.ptr_offset(&global_frames[0], ARR_LENGTH - frames),
	// 		bufferData,
	// 		size_of(Frame) * cast(int)frames,
	// 	)
	// } else {
	// 	mem.copy(&global_frames[0], bufferData, size_of(Frame) * cast(int)frames)
	// 	global_frames_count = ARR_LENGTH
	// }
}

main :: proc() {
	program := os.args[0]
	arguments := os.args[1:]
	if len(arguments) == 0 {
		fmt.panicf("Usage: %s <input>\nError: no input file provided\n", program)
	}

	rl.SetConfigFlags({.WINDOW_HIGHDPI})
	rl.InitWindow(SCREEN_WIDTH_PX, SCREEN_HEIGHT_PX, "Musializer")
	defer rl.CloseWindow()

	rl.SetTargetFPS(60)

	rl.InitAudioDevice()
	defer rl.CloseAudioDevice()

	file_path, errno := strings.clone_to_cstring(arguments[0])
	if errno != runtime.Allocator_Error.None {
		fmt.panicf("Failed to read value of input file path: %v", errno)
	}
	music := rl.LoadMusicStream(file_path)
	defer rl.UnloadMusicStream(music)

	assert(music.stream.sampleSize == 16)
	assert(music.stream.channels == 2)

	rl.SetMusicVolume(music, 0.5)
	rl.AttachAudioStreamProcessor(music, callback)
	defer rl.DetachAudioStreamProcessor(music, callback)

	rl.PlayMusicStream(music)
	defer rl.StopMusicStream(music)

	for !rl.WindowShouldClose() {
		rl.UpdateMusicStream(music)

		if rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
			if rl.IsMusicStreamPlaying(music) {
				rl.PauseMusicStream(music)
			} else {
				rl.ResumeMusicStream(music)
			}
		}

		rl.BeginDrawing()
		rl.ClearBackground({0x18, 0x18, 0x18, 0xFF})

		fft(inp[:], 1, N, out[:])

		max_amp = 0
		for i := 0; i < N; i += 1 {
			a := amp(out[i])
			if max_amp < a {
				max_amp = a
			}
		}

		// bar_w := cast(i32)math.ceil(cast(f32)SCREEN_WIDTH_PX / cast(f32)global_frames_count)
		bar_w := cast(i32)math.ceil(cast(f32)SCREEN_WIDTH_PX / N)
		half_screen := SCREEN_HEIGHT_PX / 2


		for i in 0 ..< N {
			t := amp(out[i]) / max_amp
			bar_h := cast(f32)half_screen * t
			rl.DrawRectangle(
				i32(i) * bar_w,
				i32(half_screen) - i32(bar_h),
				bar_w,
				i32(bar_h),
				rl.BLUE,
			)
		}

		// for i in 0 ..< cast(i32)global_frames_count {
		// 	t := global_frames[i].left
		// 	bar_h := cast(f32)half_screen * t
		//
		// 	if t > 0 {
		// 		rl.DrawRectangle(
		// 			i * bar_w,
		// 			cast(i32)half_screen - cast(i32)bar_h,
		// 			bar_w,
		// 			cast(i32)bar_h,
		// 			rl.BLUE,
		// 		)
		// 	} else {
		// 		rl.DrawRectangle(i * bar_w, cast(i32)half_screen, bar_w, cast(i32)bar_h, rl.BLUE)
		// 	}
		// }

		rl.EndDrawing()
	}

	fmt.println("End of main")
}

// sample_interpolate :: proc(value: i16, upper_bound: int, positive: bool) -> i32 {
// 	max := positive ? c.INT16_MAX : c.INT16_MIN
// 	t := cast(f16)value / cast(f16)max
// 	return cast(i32)(cast(f16)upper_bound * t)
// }
