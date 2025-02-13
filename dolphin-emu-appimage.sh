#/bin/sh

set -eu

export APPIMAGE_EXTRACT_AND_RUN=1
export ARCH="$(uname -m)"
APPIMAGETOOL="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-$ARCH.AppImage"
LIB4BN="https://raw.githubusercontent.com/VHSgunzo/sharun/refs/heads/main/lib4bin"
#DESKTOP="https://raw.githubusercontent.com/dolphin-emu/dolphin/refs/heads/master/Data/dolphin-emu.desktop" # This is insanely outdated lmao
ICON="https://github.com/dolphin-emu/dolphin/blob/master/Data/dolphin-emu.png?raw=true"
UPINFO="gh-releases-zsync|$(echo "$GITHUB_REPOSITORY" | tr '/' '|')|latest|*$ARCH.AppImage.zsync"
URUNTIME=$(wget -q https://api.github.com/repos/VHSgunzo/uruntime/releases -O - \
	| sed 's/[()",{} ]/\n/g' | grep -oi "https.*appimage.*dwarfs.*$ARCH$" | head -1)

# Prepare AppDir
mkdir -p ./AppDir && cd ./AppDir

echo '[Desktop Entry]
Version=1.0
Icon=dolphin-emu
Exec=dolphin-emu
Terminal=false
Type=Application
Categories=Game;Emulator;
Name=Dolphin Emulator
GenericName=Wii/GameCube Emulator
StartupWMClass=dolphin-emu
Comment=A Wii/GameCube Emulator
X-AppImage-Version=5.0-16793' > ./dolphin-emu.desktop

wget --retry-connrefused --tries=30 "$ICON" -O ./dolphin-emu.png
ln -s dolphin-emu.png ./.DirIcon

# Bundle all libs
wget --retry-connrefused --tries=30 "$LIB4BN" -O ./lib4bin
chmod +x ./lib4bin
xvfb-run -a -- ./lib4bin -p -v -r -e -s -k \
	/usr/local/bin/dolphin-* \
	/usr/lib/libGLX* \
	/usr/lib/libEGL* \
	/usr/lib/dri/* \
	/usr/lib/libvulkan* \
	/usr/lib/qt6/plugins/iconengines/* \
	/usr/lib/qt6/plugins/imageformats/* \
	/usr/lib/qt6/plugins/platforms/* \
	/usr/lib/qt6/plugins/platformthemes/* \
	/usr/lib/qt6/plugins/styles/* \
	/usr/lib/qt6/plugins/xcbglintegrations/* \
	/usr/lib/qt6/plugins/wayland-*/* \
	/usr/lib/pipewire-0.3/* \
	/usr/lib/spa-0.2/*/* \
	/usr/lib/alsa-lib/*

# copy locales, the dolphin binary expects them here
mkdir -p ./Source/Core
cp -r /usr/local/bin/DolphinQt ./Source/Core
find ./Source/Core/DolphinQt -type f ! -name 'dolphin-emu.mo' -delete

# when compiled portable this directory needs a capital S
cp -rv /usr/local/bin/Sys ./bin/Sys

# Prepare sharun
ln ./sharun ./AppRun
./sharun -g

# get version from dolphin
export VERSION="$(xvfb-run -a -- ./AppRun --version 2>/dev/null | awk 'NR==1 {print $2; exit}')"
echo "$VERSION" > ~/version

# MAKE APPIMAGE WITH URUNTIME
cd ..
wget -q "$URUNTIME" -O ./uruntime
chmod +x ./uruntime

#Add udpate info to runtime
echo "Adding update information \"$UPINFO\" to runtime..."
printf "$UPINFO" > data.upd_info
llvm-objcopy --update-section=.upd_info=data.upd_info \
	--set-section-flags=.upd_info=noload,readonly ./uruntime
printf 'AI\x02' | dd of=./uruntime bs=1 count=3 seek=8 conv=notrunc

echo "Generating AppImage..."
./uruntime --appimage-mkdwarfs -f \
	--set-owner 0 --set-group 0 \
	--no-history --no-create-timestamp \
	--compression zstd:level=22 -S24 -B16 \
	--header uruntime \
	-i ./AppDir -o Dolphin_Emulator-"$VERSION"-anylinux.dwarfs-"$ARCH".AppImage

echo "Generating zsync file..."
zsyncmake *.AppImage -u *.AppImage

# dolphin (the file manager) had to ruin the fun for everyone 😭
wget --retry-connrefused --tries=30 "$APPIMAGETOOL" -O ./appimagetool
chmod +x ./appimagetool
./appimagetool --comp zstd \
	--mksquashfs-opt -Xcompression-level --mksquashfs-opt 22 \
	-n -u "$UPINFO" "$PWD"/AppDir "$PWD"/Dolphin_Emulator-"$VERSION"-anylinux.squashfs-"$ARCH".AppImage

echo "All Done!"
