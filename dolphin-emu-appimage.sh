#/bin/sh

set -eu

export APPIMAGE_EXTRACT_AND_RUN=1
export ARCH="$(uname -m)"
APPIMAGETOOL="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-$ARCH.AppImage"
LIB4BN="https://raw.githubusercontent.com/VHSgunzo/sharun/refs/heads/main/lib4bin"
#DESKTOP="https://raw.githubusercontent.com/dolphin-emu/dolphin/refs/heads/master/Data/dolphin-emu.desktop" @ This is insanely outdated lmao
ICON="https://github.com/dolphin-emu/dolphin/blob/master/Data/dolphin-emu.png?raw=true"
UPINFO="gh-releases-zsync|$(echo "$GITHUB_REPOSITORY" | tr '/' '|')|latest|*$ARCH.AppImage.zsync"

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

# Bundle all libs
wget --retry-connrefused --tries=30 "$LIB4BN" -O ./lib4bin
chmod +x ./lib4bin

xvfb-run -a -- ./lib4bin -p -v -r -e -s -k /usr/bin/dolphin-*

# for some reason the dir needs a capital S?
cp -r /usr/share/dolphin-emu/sys ./bin/Sys

# Deploy Qt manually xd
mkdir -p ./shared/lib/qt6/plugins
cp -vr /usr/lib/qt6/plugins/iconengines       ./shared/lib/qt6/plugins
cp -vr /usr/lib/qt6/plugins/imageformats      ./shared/lib/qt6/plugins
cp -vr /usr/lib/qt6/plugins/platforms         ./shared/lib/qt6/plugins
cp -vr /usr/lib/qt6/plugins/platformthemes    ./shared/lib/qt6/plugins || true
cp -vr /usr/lib/qt6/plugins/styles            ./shared/lib/qt6/plugins
cp -vr /usr/lib/qt6/plugins/xcbglintegrations ./shared/lib/qt6/plugins
cp -vr /usr/lib/qt6/plugins/wayland-*         ./shared/lib/qt6/plugins || true
ldd ./shared/lib/qt6/plugins/*/* 2>/dev/null \
  | awk -F"[> ]" '{print $4}' | xargs -I {} cp -nv {} ./shared/lib || true

# Bundle alsa
cp -vr /usr/lib/alsa-lib       ./shared/lib

# add gpu libs
cp -vr /usr/lib/libGLX*        ./shared/lib || true
cp -vr /usr/lib/libEGL*        ./shared/lib || true
cp -vr /usr/lib/dri            ./shared/lib
cp -vn /usr/lib/libvulkan*     ./shared/lib
ldd ./shared/lib/dri/* \
	./shared/lib/libvulkan* \
	./shared/lib/libEGL* \
	./shared/lib/libGLX* 2>/dev/null \
	| awk -F"[> ]" '{print $4}' | xargs -I {} cp -nv {} ./shared/lib || true

# Bunble opengl and vulkan share files
mkdir -p ./share/vulkan
cp -vr /usr/share/glvnd          ./share
cp -vr /usr/share/vulkan/icd.d   ./share/vulkan
sed -i 's|/usr/lib||g;s|/.*-linux-gnu||g;s|"/|"|g' ./share/vulkan/icd.d/*

# Fix dolphin having a full hardcoded path /usr/share/dolphin-emu/sys
git clone https://github.com/fritzw/ld-preload-open.git preload.tmp
( cd preload.tmp && make all && mv ./path-mapping.so ../ )
rm -rf ./preload.tmp

echo 'PATH_MAPPING="/usr/share/dolphin-emu/sys:${SHARUN_DIR}/bin/Sys"
LD_PRELOAD=${SHARUN_DIR}/path-mapping.so' > ./.env

# Prepare sharun
ln ./sharun ./AppRun
./sharun -g
cd ..

# Make AppImage with the static appimage runtime (removes libfuse2 dependency).
wget --retry-connrefused --tries=30 "$APPIMAGETOOL" -O ./appimagetool
chmod +x ./appimagetool

./appimagetool -n -u "$UPINFO" AppDir/

echo "$PWD"
ls .

echo "All done!"
