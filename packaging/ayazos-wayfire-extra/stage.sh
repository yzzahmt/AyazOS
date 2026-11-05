set -e
cd "$WORK"; git clone -q --depth 1 -b v0.10.0 https://github.com/WayfireWM/wayfire-plugins-extra.git wpe
cd wpe
sed -i "s/^boost = dependency(.boost.)/boost = declare_dependency()/" src/extra-animations/meson.build
python3 - <<'PY'
p = "src/meson.build"; s = open(p).read()
start = s.index("showtouch = shared_module(")
end = s.index("\n\n", start) + 2
open(p, "w").write(s[:start] + s[end:])
PY
meson setup build --prefix=/usr --buildtype=release >/dev/null
ninja -C build >/dev/null
DESTDIR="$DEST" ninja -C build install >/dev/null
