# Dolphin_emu_Appimage

This is an attempt to pack dolphin emulator as appimage, I've tried everything to pack this application as appimage, before you ask me why didn't use pkg2appimage or appimagebuilder I've tried this before despite the fact that dolphin emulator hosted on ubuntu and debian repository has wxwidgets as dependecies which made my work so harder then I've decided to pack it from the source code.
Right now I am having some annoying issue with this application which searches for 'Resources.cpp' in the path of from the build system I've used. this is a bug in the source code.
But the dolphin-emu-nogui binary is working well... all you need to do is to run `my_dolphin.Appiamge --appimage-extract` from the terminal and unpack it and chancge the exec line the last comando line into the AppRun from dolphin-emu to dolphin-emu-nogui.
Or if you fell insecure about unpack this app and seach for an easy solution you may find slippi ishiruka project more reliable.
https://github.com/project-slippi/Ishiiruka/releases
slippi ishiruka is a dolphin emulator moded.
sorry for my bad, unfortunately I did my best til now, this app is very dificult to pack I've made so many builds.
if you know some trick that could help me to nail that feel free to bug report it to me in here, I'll be very happy to fix this issue.
