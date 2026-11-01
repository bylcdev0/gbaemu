# GBA Emu - Modern GBA Emulator for Android & iOS

Um emulador de Game Boy Advance moderno, de código aberto, construído com **mGBA core** para máxima precisão e compatibilidade. Projetado para rodar jogos Pokémon perfeitamente em ambas as plataformas.

## ✨ Features

- 🎮 **Core mGBA** - Emulação precisa, compatível com 99%+ dos jogos GBA
- 📱 **Android (Kotlin/Jetpack Compose)** - UI moderna, Material 3, gamepad virtual
- 🍎 **iOS/macOS (Swift/SwiftUI)** - Native, performance otimizada, Metal rendering
- 💾 **Save States** - Salve/carregue a qualquer momento (10 slots)
- 🔋 **Battery Saves** - SRAM, EEPROM, Flash (auto-detect + config por jogo)
- 🎯 **Cheats** - Action Replay, GameShark, CodeBreaker
- 🔗 **Link Cable** - Multiplayer local (Bluetooth/WiFi Direct) + Online (WebRTC)
- 🎨 **Video Filters** - Nearest, Bilinear, Scale2x, HQ2x, xBR
- 🔊 **Audio** - 44.1kHz/48kHz, volume control, audio sync
- ⚡ **Fast Forward** - Até 10x velocidade
- 🎮 **Controles** - Touchscreen, Gamepad Bluetooth (MFi/Xbox/PS), Mapeamento customizado
- 📊 **RTC** - Relógio em tempo real para Pokémon (eventos diários, berry growth)
- 🌡️ **Sensores** - Giroscópio, Sensor Solar, Inclinação, Rumble
- 🎨 **Temas** - Claro/Escuro, personalizável

## 📋 Requisitos

### Android
- Android 7.0+ (API 24)
- OpenGL ES 3.0+
- 2GB RAM mínimo (4GB recomendado)

### iOS
- iOS 16+ / macOS 13+
- Device com Metal support (A9+)
- Xcode 15+ para compilar

### Build
- **Android**: Android Studio Hedgehog+, NDK r26+, CMake 3.22+
- **iOS**: Xcode 15+, CMake 3.22+, mGBA submodule
- **Comum**: Git, Python 3 (para parser de config)

## 🚀 Quick Start

### 1. Clone e Setup
```bash
git clone https://github.com/seu-usuario/gbaemu.git
cd gbaemu

# Inicializar submodules (mGBA)
git submodule update --init --recursive
```

### 2. Build mGBA Core
```bash
# Linux/macOS
chmod +x build_mgba.sh
./build_mgba.sh

# Windows (use WSL2 ou compile manualmente via CMake)
```

### 3. Android
```bash
cd GbaEmu/android
./gradlew assembleDebug
# APK em app/build/outputs/apk/debug/
```

### 4. iOS
```bash
cd GbaEmu/ios
# Abrir no Xcode
open Package.swift
# Ou usar xcodebuild
xcodebuild -scheme GbaEmu -destination 'platform=iOS Simulator,name=iPhone 15' build
```

## 📁 Estrutura do Projeto

```
GbaEmu/
├── android/                 # App Android (Kotlin/Compose)
│   ├── app/
│   │   ├── src/main/
│   │   │   ├── java/com/gbaemu/
│   │   │   │   ├── core/       # GbaCore, GbaLink, RomConfig
│   │   │   │   ├── data/       # Room DB, Repository
│   │   │   │   └── ui/         # Compose screens
│   │   │   ├── cpp/            # JNI Bridge (C++)
│   │   │   └── res/            # Resources
│   │   └── build.gradle.kts
│   └── settings.gradle.kts
├── ios/                      # App iOS (Swift/SwiftUI)
│   ├── GbaEmu/
│   │   ├── Core/             # GbaCore (Swift wrapper)
│   │   ├── UI/               # Views, Components
│   │   ├── Models/           # Data models
│   │   └── Services/         # Audio, Settings, etc.
│   └── Package.swift
├── shared/                   # Código compartilhado
│   └── rom_config.py         # Parser de config de jogos
├── build_mgba.sh            # Script de build do mGBA
└── README.md
```

## 🎮 Como Jogar Pokémon

1. **Obtenha a ROM** legalmente (dump do seu cartucho)
2. **Importe no app**: Toque em "+" → Selecione o arquivo `.gba`
3. **Configurações automáticas**: O app detecta o jogo e aplica:
   - Save type: Flash 128K
   - RTC: Habilitado (eventos diários funcionam)
   - Sensor solar/gyro: Para jogos compatíveis (Boktai, WarioWare)
4. **Jogue!** Use o gamepad virtual ou conecte um controle Bluetooth

### Códigos de Jogo Suportados (Auto-config)
| Jogo | Código | Save | RTC | Sensores |
|------|--------|------|-----|----------|
| Emerald | BPEE | Flash 128K | ✅ | - |
| FireRed | BPRE | Flash 128K | ✅ | - |
| LeafGreen | BPGE | Flash 128K | ✅ | - |
| Ruby | AXVE | Flash 128K | ✅ | - |
| Sapphire | AXPE | Flash 128K | ✅ | - |
| Mystery Dungeon | B24E | Flash 128K | ✅ | - |
| Boktai | U3 | EEPROM | ✅ | Solar |
| WarioWare Twisted | RZW | EEPROM | - | Gyro+Rumble |
| Drill Dozer | V49 | EEPROM | - | Rumble |

## ⚙️ Configuração Avançada

### BIOS (Opcional mas Recomendado)
Coloque `gba_bios.bin` (SHA256: `a860e8c0b6d573d191e4ec7db1b1e4f6`) na pasta do app para:
- Boot animation autêntico
- Melhor compatibilidade
- Alguns jogos requerem BIOS

### Cheats
1. Menu → Cheats → Adicionar
2. Formato: Endereço (hex) + Valor (hex)
3. Tipos: Action Replay (0), GameShark (1), CodeBreaker (2)

### Multiplayer (Link Cable)
- **Local**: Bluetooth/WiFi Direct entre dispositivos
- **Online**: WebRTC via signaling server (configure em Settings)

## 🔧 Desenvolvimento

### Adicionar Novo Jogo ao Config
Edite `shared/rom_config.py` ou `android/app/src/main/java/com/gbaemu/core/RomConfig.kt`:

```python
'XXXX': GameConfig('XXXX', 'Nome do Jogo', 'flash-128k', 131072, rtc=True),
```

### Build mGBA Customizado
```bash
cd mgba
mkdir build && cd build
cmake .. -DENABLE_FFMPEG=ON -DENABLE_DEBUGGER=ON
make -j$(nproc)
```

### Debug Native (Android)
```bash
# lldb via Android Studio
# ou ndk-gdb
```

## 📦 Distribuição

### Android (Play Store)
```bash
./gradlew bundleRelease
# AAB em app/build/outputs/bundle/release/
```

### iOS (App Store)
```bash
# No Xcode: Product → Archive → Distribute App
# Requer Apple Developer Program ($99/ano)
```

## 🤝 Contribuindo

1. Fork o projeto
2. Crie branch: `git checkout -b feature/nova-feature`
3. Commit: `git commit -am 'Add nova feature'`
4. Push: `git push origin feature/nova-feature`
5. Abra Pull Request

## 📄 Licença

Este projeto está licenciado sob **GPL-3.0** (devido ao mGBA core).
Veja [LICENSE](LICENSE) para detalhes.

### Licenças de Terceiros
- **mGBA**: MPL-2.0 / GPL-2.0+
- **Kotlin/AndroidX**: Apache-2.0
- **SwiftUI/Foundation**: Apache-2.0 / MIT
- **zlib**: zlib License

## 🙏 Créditos

- **mGBA Team** - Core de emulação excepcional
- **MyBoy/MyOldBoy** - Inspiração para config por jogo
- **RetroArch** - Referência de arquitetura multi-plataforma
- **Comunidade GBA** - Testes, bug reports, preservação

## 📞 Suporte

- **Issues**: [GitHub Issues](https://github.com/seu-usuario/gbaemu/issues)
- **Discord**: [Servidor da Comunidade](https://discord.gg/gbaemu)
- **Wiki**: [Documentação Completa](https://github.com/seu-usuario/gbaemu/wiki)

---

**⚠️ Aviso Legal**: Este emulador é para uso educacional e preservação. Use apenas ROMs de jogos que você possui legalmente. Não distribuímos ROMs, BIOS ou jogos protegidos por copyright.

**Feito com ❤️ para a comunidade de preservação de jogos**