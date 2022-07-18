#!/bin/bash
HERE=$(realpath $(dirname $0))
TMP=$(mktemp -d)
NEW_PKG="custom_netease-cloud-music"
USAGE_LIBS=(
    libdouble-conversion.so.1
    libgconf-2.so.4
    libicudata.so.60
    libicui18n.so.60
    libicuuc.so.60
    libqcef.so
    libqcef.so.1
    libqcef.so.1.1.4
    libQt5Core.so.5
    libQt5DBus.so.5
    libQt5EglFSDeviceIntegration.so.5
    libQt5Gui.so.5
    libQt5Network.so.5
    libQt5Qml.so.5
    libQt5Svg.so.5
    libQt5WebChannel.so.5
    libQt5Widgets.so.5
    libQt5X11Extras.so.5
    libQt5XcbQpa.so.5
    libQt5Xml.so.5
    qcef
    )

cd "$TMP"
apt source vlc
sudo apt install libmpg123-dev libflac-dev libmpeg2-4-dev libgnutls28-dev libsoxr-dev libsamplerate0-dev libasound2-dev automake
cd vlc-3*
cat > ncm.patch <<EOF
diff --git a/modules/access/http/resource.c b/modules/access/http/resource.c
index 9a28bb50f3..4919cb3a05 100644
--- a/modules/access/http/resource.c
+++ b/modules/access/http/resource.c
@@ -315,6 +315,18 @@ char *vlc_http_res_get_type(struct vlc_http_resource *res)
     if (status < 200 || status >= 300)
         return NULL;
 
+    if(res->path){
+        char *suffix = "\0";
+        for(int i = (int) (strlen(res->path) - 1); i >= 0; --i){
+            if(res->path[i] == '.'){
+                suffix = res->path + i + 1;
+                break;
+            }
+        }
+        if(strcmp(suffix, "flac") == 0)
+            return strdup("audio/flac");
+    }
+
     const char *type = vlc_http_msg_get_header(res->response, "Content-Type");
     return (type != NULL) ? strdup(type) : NULL;
 }
EOF

patch -p1 <ncm.patch
mkdir build && cd build
../configure                \
    --prefix=/usr           \
    --enable-mpg123         \
    --enable-flac           \
    --enable-samplerate     \
    --enable-soxr           \
    --enable-gnutls         \
    --disable-update-check  \
    --disable-vlc           \
    --disable-lua           \
    --disable-avcodec       \
    --disable-avformat      \
    --disable-gst-decode    \
    --disable-swscale       \
    --disable-a52           \
    --without-x             \
    --disable-xcb           \
    --disable-vdpau         \
    --disable-wayland       \
    --disable-sdl-image     \
    --disable-srt           \
    --disable-qt            \
    --disable-caca

make -j$(nproc)
cp share/vlc.appdata.xml.in share/vlc.appdata.xml
make DESTDIR="$TMP/vlc-ins" install 

cd "$TMP"
wget https://d1.music.126.net/dmusic/netease-cloud-music_1.2.1_amd64_ubuntu_20190428.deb
dpkg-deb -R netease-cloud-music_1.2.1_amd64_ubuntu_20190428.deb "$NEW_PKG"
cd "$NEW_PKG/opt/netease/netease-cloud-music/libs"
mkdir bak && mv * bak/ 2>/dev/null
for i in ${USAGE_LIBS[@]}
do
    mv bak/$i .
done
mv "$TMP"/vlc-ins/usr/lib/* .
rm -rf bak pkgconfig
find . -name "*.la" | xargs rm -rf

mkdir qcef/swiftshader/ && cd qcef/swiftshader/
ln -s /usr/lib/x86_64-linux-gnu/libEGL.so.1 libEGL.so
ln -s /usr/lib/x86_64-linux-gnu/libGLESv2.so.2 libGLESv2.so

cd "$TMP"
rm -rf "$NEW_PKG"/DEBIAN/{md5sums,shlibs}

dpkg -b "$NEW_PKG"
mv "$NEW_PKG.deb" "$HERE"/
rm -rf "$TMP"

