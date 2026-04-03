# Lapis

A custom Minecraft Java Edition launcher for iOS with a premium glass UI.

## Features
- 🏠 **Home** — Quick launch with selected version
- ⚙️ **Settings** — RAM, JIT, resolution, JVM args
- 📦 **Versions** — Browse and select Vanilla/Fabric/Forge/NeoForge/Quilt
- 🧩 **Installed** — Manage mods per version with enable/disable toggles
- 🔍 **Modrinth** — Search, browse and install mods directly
- 👤 **Microsoft Account** — Sign in to play on premium servers

## Mod Isolation
Each version gets its own dedicated mod folder:
```
mods-1.21.1-vanilla/
mods-1.20.1-fabric/
mods-1.8.9-forge/
```

## Build
This project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project.
Builds are automated via GitHub Actions — push to `main` to trigger a build.

## License
All rights reserved.
