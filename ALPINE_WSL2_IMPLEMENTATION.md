# usbmuxd Multi-Instance on Windows via Alpine WSL2

## Overview
This implementation runs native Linux usbmuxd in Alpine Linux (via WSL2) for multi-instance iOS device management on Windows.

## Architecture

```
Windows Host
├── Node.js Instance Manager (detects devices, manages instances)
├── USB/IP Client (usbipd-win) - forwards USB to WSL2
└── WSL2 - Alpine Linux (~40MB)
    └── usbmuxd instances (native Linux binary)
        ├── usbmuxd --port 27015 -f -v
        ├── usbmuxd --port 27016 -f -v
        └── usbmuxd --port 27017 -f -v
```

## Why Alpine Linux?

- ✅ **Tiny**: 40-60MB compressed (vs 500MB Ubuntu)
- ✅ **Fast**: <1 second boot time
- ✅ **Stable**: Battle-tested Linux usbmuxd
- ✅ **No porting**: Zero code changes to usbmuxd
- ✅ **Easy maintenance**: Upstream updates work as-is

## Repository Changes

### Minimal Changes (Easy to Maintain)
Only ONE commit modifies usbmuxd source code:
- **Commit `28b53cd`**: Added `--port` option to `src/main.c`
  - Maps `--port 27015` to `-S 127.0.0.1:27015`
  - ~15 lines of code
  - Easy to forward-port to new usbmuxd versions

### Documentation Only
- `README-WINDOWS.md`: Windows deployment guide
- `ALPINE_WSL2_IMPLEMENTATION.md`: This file

## Installation Package Components

```
installer-package/          (~80-110MB total)
├── wsl/
│   └── alpine-usbmuxd.tar.gz       # 40-60MB - Pre-configured Alpine + usbmuxd
├── windows/
│   ├── usbipd-win-installer.msi    # 5MB - USB/IP support
│   └── wsl_update_x64.msi          # 15MB - WSL2 kernel
├── node-app/
│   └── usbmuxd-instance-manager/   # 20-30MB - Instance manager with node_modules
└── install.ps1                     # Automated installer script
```

## Installation Time

| Scenario | Time | Restart Required? |
|----------|------|-------------------|
| Fresh machine (no WSL2) | 3-4 min | ✅ YES (one-time) |
| Machine with WSL2 | 2-3 min | ❌ No |
| Update/reinstall | 1-2 min | ❌ No |

## Building the Alpine Image

### Prerequisites (Development Machine)
- Windows 10/11 with WSL2
- Internet connection

### Build Process

```powershell
# 1. Download Alpine rootfs
curl -LO https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/alpine-minirootfs-3.19.0-x86_64.tar.gz

# 2. Import to WSL2
wsl --import alpine-build $env:LOCALAPPDATA\wsl-alpine-build alpine-minirootfs-3.19.0-x86_64.tar.gz

# 3. Configure and build usbmuxd
wsl -d alpine-build
```

### Inside Alpine:
```bash
# Setup
apk update
apk add --no-cache \
    build-base \
    git \
    autoconf \
    automake \
    libtool \
    libusb-dev \
    libplist-dev \
    libimobiledevice-glue-dev \
    usbutils \
    linux-tools \
    pkgconfig

# Clone and build usbmuxd
cd /tmp
git clone https://github.com/elicoh-mce/usbmuxd-win-mce.git
cd usbmuxd-win-mce
./autogen.sh
make
make install

# Cleanup build artifacts (save space)
apk del build-base git autoconf automake libtool pkgconfig
rm -rf /tmp/* /var/cache/apk/*

# Exit
exit
```

### Export the image:
```powershell
# Export
wsl --export alpine-build alpine-usbmuxd.tar

# Compress
tar -czf alpine-usbmuxd.tar.gz alpine-usbmuxd.tar

# Result: ~40-60MB ready-to-deploy image
```

## Instance Manager Integration

The instance manager spawns usbmuxd in WSL2:

```typescript
// InstanceManager.ts
private spawnUsbmuxd(port: number): ChildProcess {
  return spawn('wsl', [
    '-d', 'usbmuxd-alpine',  // Our Alpine distro
    'usbmuxd',
    '-f',                     // Foreground
    '-v',                     // Verbose
    '-S', `0.0.0.0:${port}`,  // Listen on all interfaces
    '--pidfile', 'NONE'
  ], {
    stdio: ['ignore', 'pipe', 'pipe'],
  });
}
```

## USB Device Attachment

Devices are automatically attached to WSL2:

```typescript
// Auto-attach iOS devices when detected
async function attachDeviceToWSL(busId: string): Promise<void> {
  await execAsync(`usbipd bind --busid ${busId}`);
  await execAsync(`usbipd attach --wsl --busid ${busId} --distribution usbmuxd-alpine`);
}
```

## Usage

### Start Instance Manager
```bash
cd C:\Dev\device-management-tools\packages\usbmuxd-instance-manager
pnpm dev
```

### Connect iOS Device
- Plugin device
- Automatically attached to WSL2
- Instance spawned on available port
- Ready to use with idevice tools or go-ios

### Use with Tools
```bash
# Windows command prompt
set USBMUXD_SOCKET_ADDRESS=127.0.0.1:27015
idevice_id -l
ideviceinfo
```

## Maintenance & Updates

### Updating usbmuxd
When upstream usbmuxd releases a new version:

1. Fetch upstream changes:
```bash
git remote add upstream https://github.com/libimobiledevice/usbmuxd.git
git fetch upstream
git merge upstream/master
```

2. Forward-port the `--port` option if conflicts (rarely needed)

3. Rebuild Alpine image with new version

4. Test and redistribute

### Updating Alpine Base
```bash
# Download new Alpine rootfs
curl -LO https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/x86_64/alpine-minirootfs-3.20.0-x86_64.tar.gz

# Rebuild image with same process
```

## Testing Plan

### Phase 1: Single Device
- [ ] Import Alpine image
- [ ] Start one usbmuxd instance
- [ ] Connect one iOS device
- [ ] Run `ideviceinfo`
- [ ] Verify communication

### Phase 2: Multi-Device
- [ ] Connect 5 devices
- [ ] Verify batch allocation (4 per instance)
- [ ] Check port assignments
- [ ] Run parallel commands

### Phase 3: Stability
- [ ] 24-hour stress test
- [ ] Monitor memory/CPU in Alpine
- [ ] Test reconnects
- [ ] Verify instance cleanup

## Advantages vs Native Windows Port

| Aspect | Native Windows | Alpine WSL2 |
|--------|---------------|-------------|
| Code changes | 800+ lines | 15 lines |
| Maintenance | High (track Windows APIs) | Minimal (just --port) |
| Stability | Unknown (new port) | Proven (Linux) |
| Installation size | ~50MB | ~80MB |
| Install time | 2-5 min | 3-4 min (first time) |
| Upstream updates | Difficult | Easy |
| Debugging | Limited tools | Full Linux tools |

## Known Limitations

1. **WSL2 required**: Adds ~15MB overhead
2. **One-time restart**: On machines without WSL2
3. **USB/IP overhead**: Minimal performance impact
4. **Admin for USB attach**: Required for first device attachment

## Next Steps

- [x] Design Alpine-based architecture
- [x] Document build process
- [ ] Create Alpine image with usbmuxd
- [ ] Build installer package
- [ ] Update instance manager for WSL2
- [ ] Test with real devices
- [ ] Create automated build pipeline

## Contact

Questions/Issues: https://github.com/elicoh-mce/usbmuxd-win-mce/issues
