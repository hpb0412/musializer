#!/bin/sh

set -xe

odin build ./plug.odin -file -build-mode:shared -reloc-mode:pic -out:build/plug.dylib

exit 0

odin build ./musializer.odin -file -out:build/musicalizer
