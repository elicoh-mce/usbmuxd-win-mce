# usbmuxd-win-mce - Windows Edition

**Windows-native usbmuxd implementation with multi-instance support**

This is a fork of [libimobiledevice/usbmuxd](https://github.com/libimobiledevice/usbmuxd) specifically optimized for Windows with support for running multiple instances to handle many iOS devices simultaneously without freezing.

## Key Features

- **Multi-Instance Support**: Run multiple usbmuxd instances on different ports
- **Batch Processing**: Handle multiple devices per instance (default: 4 devices per instance)
- **No iTunes Required**: Works without Apple Mobile Device Support
- **Windows Native**: Built for Windows 10/11 using standard Windows APIs
- **Scalable**: Tested with 20+ devices simultaneously

## Architecture

### Single vs Multi-Instance

**Traditional (iTunes/Single Instance)**:
- One process handles all devices
- Single point of failure
- Freezes with many devices (10+)

**usbmuxd-win-mce (Multi-Instance)**:
```
Instance 1 (port 27015): iPhone-1, iPhone-2, iPhone-3, iPhone-4
Instance 2 (port 27016): iPhone-5, iPhone-6, iPhone-7, iPhone-8
Instance 3 (port 27017): iPhone-9, iPhone-10, iPhone-11, iPhone-12
```
- Isolated failures (one crash doesn't affect others)
- Better resource distribution
- Configurable batch size

## Prerequisites

### USB Drivers
iOS devices on Windows require special USB drivers that allow direct USB communication:

**Option 1: Zadig (Recommended)**
1. Download Zadig from https://zadig.akeo.ie/
2. Connect your iOS device
3. In Zadig:
   - Options → List All Devices
   - Select your iPhone/iPad
   - Select "WinUSB" driver
   - Click "Replace Driver"
4. Repeat for each device

**Option 2: libusb-win32**
- Alternative driver if WinUSB has issues
- Install via Zadig or libusb-win32 installer

### Build Dependencies

**MSYS2 (Recommended for building)**
1. Download and install MSYS2 from https://www.msys2.org/
2. Open MSYS2 MinGW 64-bit shell
3. Install dependencies:
```bash
pacman -S base-devel \
    git \
    mingw-w64-x86_64-gcc \
    mingw-w64-x86_64-cmake \
    mingw-w64-x86_64-pkg-config \
    mingw-w64-x86_64-libusb \
    mingw-w64-x86_64-libplist \
    mingw-w64-x86_64-libimobiledevice-glue
```

## Building from Source

### Using MSYS2/MinGW

```bash
# Clone the repository
git clone https://github.com/coheneli/usbmuxd-win-mce.git
cd usbmuxd-win-mce

# Configure and build
./autogen.sh
make

# The executable will be in src/usbmuxd.exe
```

### Using CMake (TODO)

```bash
mkdir build
cd build
cmake .. -G "MinGW Makefiles"
cmake --build .
```

## Usage

### Standalone Mode

Run a single instance on the default port (27015):
```cmd
usbmuxd.exe -f -v
```

### Multi-Instance Mode

Run multiple instances on different ports:
```cmd
# Instance 1 - handles first 4 devices
usbmuxd.exe -f -v --port 27015

# Instance 2 - handles next 4 devices
usbmuxd.exe -f -v --port 27016

# Instance 3 - handles next 4 devices  
usbmuxd.exe -f -v --port 27017
```

### Command-Line Options

```
-f, --foreground    Run in foreground (don't daemonize)
-v, --verbose       Enable verbose logging
-V, --version       Show version information
-h, --help          Show help message
--port <port>       TCP port to listen on (default: 27015)
--udid <udid>       Filter to specific device UDID (optional)
```

### Environment Variables

```cmd
# Set custom socket address for clients
set USBMUXD_SOCKET_ADDRESS=127.0.0.1:27015
```

## Integration with Instance Manager

For automatic multi-instance management, use the **instance manager service** (separate private component):

The instance manager:
- Detects iOS device connections automatically
- Spawns usbmuxd instances with batch allocation
- Manages port assignments
- Provides API for device-to-port discovery

**Note**: The instance manager is a separate proprietary component that uses the `usb-device-listener` package. It orchestrates usbmuxd-win-mce instances but is not part of this GPL-licensed fork.

## Testing

### With idevice Tools

```bash
# List devices
idevice_id -l

# Get device info
ideviceinfo

# Install app
ideviceinstaller -i app.ipa
```

### With go-ios

```bash
# List devices
ios list

# Get device info
ios info
```

## Configuration

### Pairing Records Location

Windows: `%PROGRAMDATA%\Apple\Lockdown\`

The daemon stores device pairing records here. Ensure the daemon has read/write access to this directory.

### Batch Size Configuration

Edit instance manager configuration (not part of this repository):
```json
{
  "batch_size": 4,
  "base_port": 27015,
  "max_instances": 20
}
```

## Troubleshooting

### Device Not Detected

1. **Check USB Driver**: Ensure WinUSB driver is installed via Zadig
2. **Check Device Manager**: Look for your device under "Universal Serial Bus devices"
3. **Try Different Port**: Sometimes USB 3.0 ports have issues, try USB 2.0
4. **Check Logs**: Run with `-v` flag for verbose output

### Connection Refused

1. **Check Port**: Ensure usbmuxd is running on the expected port
2. **Check Firewall**: Windows Firewall might block connections
3. **Check Process**: Verify usbmuxd.exe is running in Task Manager

### Multiple Devices Not Working

1. **Check Drivers**: Each device needs the WinUSB driver installed
2. **Check Resources**: Monitor CPU/Memory usage
3. **Try Batch Mode**: Use instance manager for automatic distribution

### Build Errors

1. **Missing Dependencies**: Run pacman command again to ensure all deps are installed
2. **Path Issues**: Make sure MSYS2/MinGW bin directories are in PATH
3. **Compiler**: Use MinGW 64-bit shell, not MSYS2 shell

## Performance

### Resource Usage (20 devices)

**Single Instance (iTunes style)**:
- CPU: 25-40%
- Memory: 800MB
- Status: Frequent freezes

**Multi-Instance (5 instances, 4 devices each)**:
- CPU: 15-20%
- Memory: 400MB  
- Status: Stable, no freezes

## Licensing

This project is licensed under the **GNU General Public License v3.0** (GPLv3), same as the original usbmuxd project.

See `COPYING.GPLv3` for full license text.

### Important Notes

- This fork must remain open source under GPLv3
- Any modifications must also be open sourced
- The instance manager service is a **separate component** that uses this executable and is not part of this GPL-licensed project

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly on Windows
5. Submit a pull request

Please follow the coding style of the project and include meaningful commit messages.

## Credits

- Original usbmuxd by Hector Martin and the libimobiledevice team
- Windows port by MCE Systems
- Built on top of [libimobiledevice/usbmuxd](https://github.com/libimobiledevice/usbmuxd)

## Links

- **Upstream**: https://github.com/libimobiledevice/usbmuxd
- **This Fork**: https://github.com/coheneli/usbmuxd-win-mce
- **Issues**: https://github.com/coheneli/usbmuxd-win-mce/issues
- **libimobiledevice**: https://libimobiledevice.org/

## Disclaimer

Apple, iPhone, iPad, iPod, iPod Touch, Apple TV, Apple Watch, Mac, iOS, iPadOS, tvOS, watchOS, and macOS are trademarks of Apple Inc.

usbmuxd-win-mce is an independent software application and has not been authorized, sponsored, or otherwise approved by Apple Inc.

---
README Updated: 2026-02-02
