build-dbg:
    # odin build animagik -out:build/animagik-dbg -debug
    odin build animagik -out:build/animagik-dbg -debug

run-dbg: build-dbg
    ./build/animagik-dbg

build:
    odin build animagik -out:build/animagik

run: build
    ./build/animagik
