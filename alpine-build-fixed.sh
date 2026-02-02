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
    usbutils \
    linux-tools \
    pkgconfig \
    ca-certificates

echo "==> Building libplist..."
cd /tmp
git clone https://github.com/libimobiledevice/libplist.git
cd libplist
./autogen.sh
make
make install

echo "==> Building libimobiledevice-glue..."
cd /tmp
git clone https://github.com/libimobiledevice/libimobiledevice-glue.git
cd libimobiledevice-glue
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
./autogen.sh
make
make install

echo "==> Building usbmuxd..."
cd /tmp
git clone https://github.com/elicoh-mce/usbmuxd-win-mce.git
cd usbmuxd-win-mce
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
./autogen.sh --without-preflight
make
make install

echo "==> Testing usbmuxd installation..."
usbmuxd --version || echo "Version check failed"
ls -lh /usr/local/sbin/usbmuxd || echo "Binary not found"

echo "==> Cleaning up build artifacts..."
cd /
rm -rf /tmp/*
apk del build-base git autoconf automake libtool pkgconfig
rm -rf /var/cache/apk/*

echo "==> Keeping only runtime dependencies..."
apk add --no-cache \
    libusb \
    usbutils \
    linux-tools

echo "==> Build complete!"
echo "Final check:"
ls -lh /usr/local/sbin/usbmuxd