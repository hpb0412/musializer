package main

import "core:fmt"
import "core:math"
import "core:math/cmplx"

SAMPLE_RATE :: 8
HALF :: SAMPLE_RATE / 2

cexp :: proc(x: f32) -> complex64 {
	// return cast(complex64)math.cos(x) + (1i * cast(complex64)math.sin(x))
	return cmplx.exp(1i * cast(complex64)x)
}

fft :: proc(inp: []f32, stride: uint = 1, n: uint, out: []complex64) {
	assert(n > 0)

	if (n == 1) {
		out[0] = inp[0]
		return
	}

	half := n/2

	// even
	fft(inp, stride * 2, h, out)
	// odd
	fft(inp[stride:], stride * 2, half, out[half:])

	for k := 0; k < half; k += 1 {
		t := cast(f32)k / cast(f32)n
		v := cexp(-2 * math.PI * t) * out[k + half]
		e := out[k]
		out[k] = e + v
		out[k + half] = e - v
	}
}

main :: proc() {
	fmt.println("fft")

	inp := make([dynamic]f32, SAMPLE_RATE)
	defer delete(inp)

	out := make([dynamic]complex64, SAMPLE_RATE)
	defer delete(out)

	for i := 0; i < SAMPLE_RATE; i += 1 {
		t: f32 = cast(f32)i / cast(f32)SAMPLE_RATE
		inp[i] = math.cos(2 * math.PI * t * 1) + math.sin(2 * math.PI * t * 2)
	}


	for f := 0; f < HALF; f += 1 {
		out[f] = 0
		out[f + HALF] = 0

		// even
		for i := 0; i < SAMPLE_RATE; i += 2 {
			t: f32 = cast(f32)i / cast(f32)SAMPLE_RATE
			c := cast(complex64)inp[i] * cexp(2 * math.PI * t * cast(f32)f)
			out[f] += c
			out[f + HALF] += c
		}

		// odd
		for i := 1; i < SAMPLE_RATE; i += 2 {
			t: f32 = cast(f32)i / cast(f32)SAMPLE_RATE
			c := cast(complex64)inp[i] * cexp(2 * math.PI * t * cast(f32)f)
			out[f] += c
			out[f + HALF] -= c
		}
	}

	// Below is DFT
	// for f := 0; f < SAMPLE_RATE; f += 1 {
	// 	out[f] = 0
	//
	// 	for i := 0; i < SAMPLE_RATE; i += 1 {
	// 		t: f32 = cast(f32)i / cast(f32)SAMPLE_RATE
	// 		out[f] += cast(complex64)inp[i] * cexp(2 * math.PI * cast(f32)f * t)
	// 	}
	// }

	for f := 0; f < SAMPLE_RATE; f += 1 {
		fmt.printfln("%02d hz: %5.2f, %5.2f", f, cmplx.real(out[f]), cmplx.imag(out[f]))
	}
}
