# AyazOS ortamı: her araç, cache ve geçici dosya HDD'de kalır. Macintosh HD'ye yazılmaz.
export AYAZ_ROOT=/Volumes/HDD/Projeler/Projeler/AyazOS
export TC=$AYAZ_ROOT/.tc
export HOME=$TC/home
export TMPDIR=$TC/tmp/ TMP=$TC/tmp TEMP=$TC/tmp
export XDG_CACHE_HOME=$TC/cache XDG_CONFIG_HOME=$TC/home/.config XDG_DATA_HOME=$TC/home/.local/share XDG_STATE_HOME=$TC/home/.local/state
export PIP_CACHE_DIR=$TC/pip PYTHONPYCACHEPREFIX=$TC/pycache
export CLANG_MODULE_CACHE_PATH=$TC/clang xcrun_nocache=1
export HOMEBREW_NO_AUTO_UPDATE=1
export PATH=$TC/prefix/bin:$TC/venv/bin:$PATH
export PKG_CONFIG_PATH=$TC/prefix/lib/pkgconfig:/opt/homebrew/opt/glib/lib/pkgconfig:/opt/homebrew/opt/pixman/lib/pkgconfig:/opt/homebrew/opt/gettext/lib/pkgconfig:/opt/homebrew/opt/pcre2/lib/pkgconfig
export DYLD_FALLBACK_LIBRARY_PATH=$TC/prefix/lib
