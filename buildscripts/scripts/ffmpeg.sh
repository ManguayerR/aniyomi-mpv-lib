#!/bin/bash -e

. ../../include/path.sh

if [ "$1" == "build" ]; then
	true
elif [ "$1" == "clean" ]; then
	rm -rf _build$ndk_suffix
	exit 0
else
	exit 255
fi

mkdir -p _build$ndk_suffix
cd _build$ndk_suffix

cpu=armv7-a
[[ "$ndk_triple" == "aarch64"* ]] && cpu=armv8-a
[[ "$ndk_triple" == "x86_64"* ]] && cpu=generic
[[ "$ndk_triple" == "i686"* ]] && cpu="i686 --disable-asm"

cpuflags=
[[ "$ndk_triple" == "arm"* ]] && cpuflags="$cpuflags -mfpu=neon -mcpu=cortex-a8"

args=(
	--target-os=android --enable-cross-compile
	--cross-prefix=$ndk_triple- --cc=$CC --pkg-config=pkg-config --nm=llvm-nm
	--arch=${ndk_triple%%-*} --cpu=$cpu
	--extra-cflags="-I$prefix_dir/include $cpuflags" --extra-ldflags="-L$prefix_dir/lib"

	--enable-{jni,mediacodec,mbedtls,libdav1d,libxml2} --disable-vulkan
	--disable-static --enable-shared --enable-{gpl,version3}
	# nombres propios (libavcodec_mpv.so...) para convivir en el APK con el FFmpeg de ffmpeg-kit
	--build-suffix=_mpv

	# disable unneeded parts
	--disable-{stripping,doc,programs}
	# to keep the build lean we disable some features quite aggressively:
	# - devices: no practical use on Android
	--disable-devices
)
../configure "${args[@]}"

make -j$cores
make DESTDIR="$prefix_dir" install

# mpv busca dependency('libavcodec') etc. sin sufijo: alias .pc que siguen enlazando las *_mpv
for pc in "$prefix_dir"/lib/pkgconfig/lib*_mpv.pc; do
	sed 's/^Name: \(.*\)_mpv$/Name: \1/' "$pc" > "${pc%_mpv.pc}.pc"
done
