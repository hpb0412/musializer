# Musializer Clone

An attempt to clone Musializer from [Tsoding Daily](https://www.youtube.com/playlist?list=PLpM-Dvs8t0Vak1rrE2NJn8XYEJ5M7-BqT)

Here I use [Odin](https://odin-lang.org/) programming language

## Run

```shell
odin run ./musializer.odin -file -out:./bin/musicalizer
```

```
# build the app
odin build ./musializer.odin -file -define:RAYLIB_SHARED=true -extra-linker-flags:"-Wl,-rpath $(odin root)/vendor/raylib/macos-arm64" -out:bin/musicalizer

# build the plugin
odin build ./plug.odin -file -define:RAYLIB_SHARED=true -extra-linker-flags:"-Wl,-rpath $(odin root)/vendor/raylib/macos-arm64" -build-mode:shared -reloc-mode:pic -out:bin/plug.dylib
```

## Todo

1. [x] Music visualizer + FFT (Fast Fourier Transform)
2. [x] Hot code reloading
