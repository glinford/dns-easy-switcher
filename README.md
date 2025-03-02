# DNS Easy Switcher

A simple macOS menu bar app that allows you to quickly switch between different DNS providers (or add custom ones).

![Screenshot of DNS Easy Switcher](screenshot.png)

## Features

- Easy switching between popular DNS providers:
  - Cloudflare DNS (1.1.1.1)
  - Quad9 DNS (9.9.9.9)
  - AdGuard DNS (94.140.14.14)
  - GetFlix DNS (with list of all locations)
- Disable DNS Overrides (DHCP-Provided DNS)
- Add and manage your own custom DNS servers
- Test DNS speed to find the fastest provider
- Flush DNS Cache
- Touch ID authentication for DNS changes
- Native macOS menu bar integration
- Persists your settings between app launches
- IPv4 and IPv6 support

## Installation

### Using Homebrew (Recommended)

Install DNS Easy Switcher with Homebrew using these commands:

```bash
brew tap glinford/tap
brew install --cask dns-easy-switcher
```

To update to the latest version when available:

```bash
brew upgrade --cask dns-easy-switcher
```

### Manual Installation

1. Download the latest release from the [Releases](../../releases) page
2. Mount the DMG file
3. Drag DNS Easy Switcher to your Applications folder
4. Launch DNS Easy Switcher from Applications

## First Launch

Since DNS Easy Switcher is distributed outside the Mac App Store, macOS may show a security warning when you first launch it.

To allow the app to run:

1. Right-click (or Control-click) on DNS Easy Switcher in your Applications folder
2. Select "Open" from the context menu
3. Click "Open" in the dialog that appears
4. Allow system extensions when prompted (required for DNS changes)

![settings](settings.png)

## Important Note

Due to macOS security requirements, administrator privileges are required each time you switch DNS settings. If you have a Touch ID-enabled Mac, you can now use Touch ID instead of password entry for authentication.

## Requirements

- macOS 14.0 (Sonoma) or later
- Administrator privileges (required for changing DNS settings)
- Touch ID compatible Mac (for Touch ID authentication feature)

## Tested Configurations

| macOS Version | Status |
|--------------|--------|
| Sonoma 14.5 | ✅ |

## Building from Source

1. Clone the repository:
```bash
git clone https://github.com/glinford/dns-easy-switcher.git
```
2. Open the project in Xcode 15 or later
3. Build and run the project

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Acknowledgments

- [Cloudflare DNS](https://1.1.1.1) for their public DNS service
- [Quad9](https://quad9.net) for their secure DNS service
- [AdGuard DNS](https://adguard-dns.io/en/welcome.html) for their privacy-focused DNS service with ad blocking capabilities
- [GetFlix](https://www.getflix.com.au/setup/dns-servers/)

## Privacy

DNS Easy Switcher does not collect any data. All settings are stored locally on your device.