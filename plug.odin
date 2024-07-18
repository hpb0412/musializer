package plug

import "base:runtime"
import "core:c/libc"
import "core:fmt"
import "core:math"
import "core:math/cmplx"
import "core:mem"

import rl "vendor:raylib"

Plug :: struct {
	version: uint,
	music:   rl.Music,
}

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
		v := cexp(-2 * rl.PI * t) * out[k + cast(int)half]
		e := out[k]
		out[k] = e + v
		out[k + cast(int)half] = e - v
	}
}

amp :: proc(c: complex64) -> f32 {
	a := abs(real(c))
	b := abs(imag(c))
	if a < b {
		return b
	} else {
		return a
	}
}


Frame :: struct {
	left:  f32,
	right: f32,
}

SCREEN_WIDTH_PX :: 800
SCREEN_HEIGHT_PX :: 600

N :: (1 << 14) // 16384
inp: [N]f32
out: [N]complex64

callback: rl.AudioCallback = proc "c" (bufferData: rawptr, frames: u32) {
	context = runtime.default_context()

	frameData := transmute([^]Frame)bufferData

	for i in 0 ..< frames {
		libc.memmove(&inp[0], mem.ptr_offset(&inp[0], 1), (N - 1) * size_of(inp[0]))
		inp[N - 1] = frameData[i].left
	}
}

@(export)
plug_init :: proc(plug: ^Plug, file_path: cstring) {
	plug.music = rl.LoadMusicStream(file_path)

	assert(plug.music.stream.sampleSize == 16)
	assert(plug.music.stream.channels == 2)
	rl.SetMusicVolume(plug.music, 0.5)

	rl.AttachAudioStreamProcessor(plug.music.stream, callback)
	rl.PlayMusicStream(plug.music)
}

@(export)
plug_terminate :: proc(plug: ^Plug) {
	rl.StopMusicStream(plug.music)
	rl.DetachAudioStreamProcessor(plug.music.stream, callback)
	rl.UnloadMusicStream(plug.music)
}

@(export)
plug_pre_reload :: proc(plug: ^Plug) {
	rl.DetachAudioStreamProcessor(plug.music.stream, callback)
}

@(export)
plug_post_reload :: proc(plug: ^Plug) {
	rl.AttachAudioStreamProcessor(plug.music.stream, callback)
}

@(export)
plug_update :: proc(plug: ^Plug) {
	rl.UpdateMusicStream(plug.music)

	if rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
		if rl.IsMusicStreamPlaying(plug.music) {
			rl.PauseMusicStream(plug.music)
		} else {
			rl.ResumeMusicStream(plug.music)
		}
	}

	rl.BeginDrawing()
	rl.ClearBackground({0x18, 0x18, 0x18, 0xFF})
	// rl.ClearBackground(rl.BEIGE)
	//rl.ClearBackground(rl.MAROON)

	fft(inp[:], 1, N, out[:])

	max_amp: f32 = 0
	for i := 0; i < N; i += 1 {
		a := amp(out[i])
		if max_amp < a {
			max_amp = a
		}
	}

	STEP :: 1.06
	bar_count := math.log10((f32(N) / f32(20))) / math.log10(f32(STEP))

	scale := rl.GetWindowScaleDPI()
	w := f32(rl.GetRenderWidth()) / scale[0]
	h := f32(rl.GetRenderHeight()) / scale[1]
	bar_w := i32(math.ceil(w / bar_count))
	half_screen := i32(h / 2)

	//for i in 0 ..< N {
	//	t := amp(out[i]) / max_amp
	j: i32 = 0
	for f: f32 = 20.0; f < N; f *= f32(STEP) {
		f_next := f * STEP
		avg: f32 = 0
		for i := i32(f); i < N && i < i32(f_next); i += 1 {
			avg += amp(out[i])
		}
		avg /= f32(i32(f_next) - i32(f) + 1)

		t := avg / max_amp

		bar_h := f32(half_screen) * t
		rl.DrawRectangle(
			j * bar_w,
			i32(half_screen) - i32(bar_h),
			bar_w,
			i32(bar_h),
			//rl.BLUE,
			//rl.MAROON,
			rl.GOLD,
		)

		j += 1
	}

	rl.EndDrawing()
}
