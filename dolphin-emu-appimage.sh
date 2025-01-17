#/bin/sh

set -eu

export APPIMAGE_EXTRACT_AND_RUN=1
export ARCH="$(uname -m)"
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

# Bundle all libs
wget --retry-connrefused --tries=30 "$LIB4BN" -O ./lib4bin
chmod +x ./lib4bin

xvfb-run -a -- ./lib4bin -p -v -r -e -s -k /usr/local/bin/dolphin-*

# when compiled portable this directory needs a capital S
# this is not needed since we are not using a binary that was compiled portable
cp -rv /usr/local/bin/Sys ./bin/Sys

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

# Bundle pipewire and alsa
cp -vr /usr/lib/pipewire-0.3   ./shared/lib
cp -vr /usr/lib/spa-0.2        ./shared/lib
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

# copy locales, the dolphin binary expects them here
mkdir -p ./Source/Core
cp -r /usr/local/bin/DolphinQt ./Source/Core
find ./Source/Core/DolphinQt -type f ! -name 'dolphin-emu.mo' -delete

# Prepare sharun
ln ./sharun ./AppRun
./sharun -g

# get version from dolphin
export VERSION="$(./AppRun --version 2>/dev/null | awk 'NR==1 {print $2; exit}')"
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
	-i ./AppDir -o Dolphin_Emulator-"$VERSION"-anylinux-"$ARCH".AppImage

echo "Generating zsync file..."
zsyncmake *.AppImage -u *.AppImage

mv ./*.AppImage* ../
cd ..
echo "All Done!"
