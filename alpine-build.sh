#!/bin/sh

echo "==> Updating package index..."
apk update

echo "==> Installing build dependencies..."
apk add --no-cache \
    build-base \
    git \
    autoconf \
    automake \
    libtool \
    libusb-dev \
    libplist-dev \
    usbutils \
    linux-tools \
    pkgconfig \
    ca-certificates

echo "==> Building libimobiledevice-glue..."
cd /tmp
git clone https://github.com/libimobiledevice/libimobiledevice-glue.git
cd libimobiledevice-glue
./autogen.sh
make
make install

echo "==> Building usbmuxd..."
cd /tmp
git clone https://github.com/elicoh-mce/usbmuxd-win-mce.git
cd usbmuxd-win-mce
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
./autogen.sh
make
make install

echo "==> Cleaning up build artifacts..."
cd /
rm -rf /tmp/*
apk del build-base git autoconf automake libtool pkgconfig
rm -rf /var/cache/apk/*

echo "==> Keeping only runtime dependencies..."
apk add --no-cache \
    libusb \
    libplist \
    usbutils \
    linux-tools

echo "==> Build complete!"
usbmuxd --version || echo "usbmuxd installed at /usr/local/sbin/usbmuxd"
ls -lh /usr/local/sbin/usbmuxd
