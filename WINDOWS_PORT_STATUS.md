# usbmuxd Windows Port Status

## Overview
This document tracks the progress of porting usbmuxd to Windows for multi-instance iOS device management.

## Architecture

### Goal
Replace iTunes/Apple Mobile Device Support with a lightweight multi-instance usbmuxd setup:
- **Instance Manager** (Node.js): Detects iOS devices via usb-device-listener, spawns usbmuxd instances
- **usbmuxd-win.exe**: Each instance handles a batch of devices (default: 4) on a unique TCP port

### Key Modifications
1. Added `--port PORT` CLI option as shorthand for `-S 127.0.0.1:PORT` (completed ✅)
2. Windows socket compatibility (in progress ⚠️)
3. USB device handling via libusb (should work natively ✅)

## Implementation Status

### ✅ Completed
1. **Repository Setup**
   - Forked https://github.com/libimobiledevice/usbmuxd
   - Repository: https://github.com/coheneli/usbmuxd-win-mce
   - Branch: main

2. **CLI Modifications** (`src/main.c`)
   - Added `--port` option (case 1000 in getopt_long)
   - Maps to `-S 127.0.0.1:PORT` internally

3. **Documentation**
   - `README-WINDOWS.md`: Comprehensive Windows build/usage guide
   - Architecture documentation
   - Multi-instance examples

4. **Build Environment**
   - MSYS2/MinGW configured
   - Dependencies installed: libusb, libplist, libimobiledevice-glue
   - autogen.sh/configure runs successfully

5. **Instance Manager** (`C:\Dev\device-management-tools\packages\usbmuxd-instance-manager`)
   - Complete TypeScript implementation
   - Batch allocation (4 devices per instance)
   - Dynamic instance spawning (ports 27015, 27016, 27017...)
   - usb-device-listener integration
   - CLI tool with monitoring
   - Example scripts
   - **Ready to use with usbmuxd.exe once compiled**

### ⚠️ In Progress: Windows Compatibility

#### Files Modified for Windows
1. **`src/win32compat.h`** - Centralized Windows compatibility header
   - Socket API wrappers (WSA* functions)
   - TCP header struct (BSD-style)
   - ppoll → WSAPoll wrapper
   - Signal handling stubs
   - POSIX function stubs

2. **`src/client.c`** - Client connection handling
   - Windows socket headers
   - sockaddr_in vs sockaddr_un
   - ioctlsocket for non-blocking
   - setsockopt type casts

3. **`src/device.c`** - Device communication
   - TCP header definitions
   - Windows socket headers
   - usleep → Sleep

4. **`src/log.c`** - Logging system
   - Syslog stubs
   - gettimeofday implementation
   - localtime compatibility

5. **`src/utils.h`** - Utility functions
   - WSAPOLLFD vs pollfd

6. **`src/main.c`** - Main daemon logic
   - Windows header includes (partial)

#### Remaining Issues

**Major Challenges:**
1. **Daemon Functions**: fork(), setsid(), signal handling
   - Windows doesn't support Unix daemon model
   - **Solution**: Run in foreground mode only (`--foreground` flag)

2. **File Locking**: fcntl(F_SETLK), flock struct
   - Used for PID file locking
   - **Solution**: Use Windows file locking APIs or skip PID file

3. **User/Group Management**: getpwnam(), setuid(), setgid(), initgroups()
   - Unix privilege dropping
   - **Solution**: Run as normal user, skip privilege functions

4. **Unix Domain Sockets**: sockaddr_un, AF_UNIX
   - Fallback when no TCP address specified
   - **Solution**: Always require TCP address on Windows

5. **POSIX File I/O**: Macro conflicts with MSVC CRT (_open vs open)
   - Need careful header ordering
   - **Solution**: Use Windows-native APIs or fix macro definitions

**Current Build Errors:**
- Type mismatches in ppoll wrapper
- Macro redefinitions (EINTR, file I/O macros)
- Missing struct members (st_uid, st_gid in struct stat)
- Incomplete POSIX function stubs

## Alternative Approaches

### Option A: Minimal Windows Port (Recommended)
**Pros:**
- Leverages existing TCP socket support
- libusb already works on Windows
- Most portable

**Approach:**
1. Force foreground mode on Windows (no daemon)
2. Skip PID file locking
3. Skip privilege dropping
4. Always use TCP sockets
5. Disable Unix-specific features via #ifdef _WIN32

**Estimated Time:** 4-8 hours

### Option B: Pre-built Binary
Use existing Windows usbmuxd builds:
- Check libimobiledevice-win32 project
- Check pymobiledevice3 Windows support
- May already have compatible binaries

**Estimated Time:** 1-2 hours research

### Option C: WSL2 Integration
Run Linux usbmuxd in WSL2:
- USB/IP passthrough to WSL2
- Linux usbmuxd unchanged
- Instance manager in Windows Node.js

**Pros:** No porting needed
**Cons:** Requires WSL2, USB/IP setup complexity

## Build Instructions (When Complete)

### Prerequisites
```bash
# Install MSYS2
# Install dependencies
pacman -S base-devel git mingw-w64-x86_64-gcc mingw-w64-x86_64-cmake \
  mingw-w64-x86_64-pkg-config mingw-w64-x86_64-libusb \
  mingw-w64-x86_64-libplist mingw-w64-x86_64-libimobiledevice-glue
```

### Build
```bash
cd /c/Dev/usbmuxd-win-mce
./autogen.sh
make
# Output: src/usbmuxd.exe
```

### Install Windows USB Drivers
Use Zadig to install WinUSB driver for iOS devices:
1. Download Zadig from https://zadig.akeo.ie/
2. Connect iPhone/iPad
3. Options → List All Devices
4. Select iPhone/iPad
5. Select WinUSB driver
6. Install Driver

## Usage

### Single Instance (Testing)
```bash
usbmuxd.exe --port 27015 --foreground --verbose --disable-hotplug
```

### Multi-Instance via Instance Manager
```bash
cd C:\Dev\device-management-tools\packages\usbmuxd-instance-manager
pnpm dev
# Automatically spawns instances as devices connect
```

### With idevice Tools
```bash
# Set port for tools
set USBMUXD_SOCKET_ADDRESS=127.0.0.1:27015

# List devices
idevice_id -l

# Get device info
ideviceinfo
```

### With go-ios
```go
// Connect to specific instance
client, err := ios.NewClient(ios.WithTCPMuxAddr("127.0.0.1:27015"))
```

## Testing Plan

1. **Single Device Test**
   - Spawn one instance
   - Connect one device
   - Run ideviceinfo
   - Verify communication

2. **Multi-Device Test**
   - Connect 5-10 devices
   - Verify batch allocation (4 per instance)
   - Check port assignments
   - Stress test with parallel commands

3. **Stability Test**
   - Run for 24 hours
   - Monitor memory/CPU
   - Test device disconnects/reconnects
   - Verify instance cleanup

## Known Limitations

1. **No daemon mode**: Must run in foreground
2. **No auto-start**: Requires manual start or Windows Service wrapper
3. **No privilege dropping**: Runs as current user
4. **USB driver required**: WinUSB via Zadig

## Next Steps

1. Complete Windows compatibility stubs
2. Fix build errors
3. Test with single device
4. Test with multiple devices
5. Create Windows Service wrapper
6. Document deployment process

## Contact

Questions/Issues: https://github.com/coheneli/usbmuxd-win-mce/issues
