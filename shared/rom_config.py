#!/usr/bin/env python3
"""
ROM Configuration Parser for GBA Emulator

Parses rom_config.ini files (like MyBoy's) to get game-specific settings
for save types, flash sizes, CPU hacks, sensor configs, etc.
"""

import configparser
import re
from dataclasses import dataclass, field
from typing import Dict, Optional, List
from pathlib import Path


@dataclass
class GameConfig:
    """Configuration for a specific GBA game"""
    code: str                    # 4-character game code (e.g., "BPRE")
    title: str = ""              # Human-readable title
    save_type: str = "auto"      # none, sram, eeprom, flash-64k, flash-128k
    flash_size: Optional[int] = None  # Flash size in bytes (65536, 131072, etc.)
    mirror: bool = False         # Memory mirroring
    max_objs: Optional[int] = None   # Max sprites (for NES classics)
    cpu_core: str = "auto"       # interp, dynarec
    dma_hack: bool = False       # DMA timing hack
    cycles_hack: Optional[int] = None  # Cycle timing hack (1 or 2)
    interrupt_delay: bool = False    # Delay interrupts
    addon: str = ""              # solar, gyro, tilt, rumble, gyro+rumble
    rtc: bool = False            # Real-time clock
    save_size: Optional[int] = None  # Save size in bytes


class RomConfigParser:
    """Parses rom_config.ini files"""

    # Save type mapping
    SAVE_TYPE_MAP = {
        'none': 0,
        'sram': 1,
        'eeprom': 2,
        'flash-64k': 3,
        'flash-128k': 4,
        'flash-512k': 5,
        'flash-1m': 6,
    }

    # Flash size mapping (KB -> bytes)
    FLASH_SIZE_MAP = {
        64: 65536,
        128: 131072,
        512: 524288,
        1024: 1048576,
    }

    def __init__(self):
        self.configs: Dict[str, GameConfig] = {}
        self._default_config = GameConfig(code="DEFAULT")

    def parse_file(self, path: str) -> Dict[str, GameConfig]:
        """Parse a rom_config.ini file"""
        parser = configparser.ConfigParser(
            interpolation=None,
            allow_no_value=True,
            strict=False
        )
        parser.optionxform = str  # Preserve case

        # Read file with encoding handling
        try:
            with open(path, 'r', encoding='utf-8') as f:
                content = f.read()
        except UnicodeDecodeError:
            with open(path, 'r', encoding='latin-1') as f:
                content = f.read()

        # Pre-process: handle comments and inline comments
        lines = content.split('\n')
        processed_lines = []
        for line in lines:
            # Remove inline comments
            line = re.sub(r'\s*#.*$', '', line)
            processed_lines.append(line)

        parser.read_string('\n'.join(processed_lines))

        # Parse each section
        for section in parser.sections():
            if section == 'DEFAULT':
                self._parse_section(parser, section, self._default_config)
            else:
                config = GameConfig(code=section)
                self._parse_section(parser, section, config)
                self.configs[section] = config

        return self.configs

    def _parse_section(self, parser: configparser.ConfigParser, section: str, config: GameConfig):
        """Parse a single section into GameConfig"""
        for key, value in parser.items(section):
            key = key.lower().strip()
            value = value.strip() if value else ""

            if key == 'savetype':
                config.save_type = value.lower()
            elif key == 'flashsize':
                # Parse flash size (e.g., "128k")
                match = re.match(r'(\d+)([km]?)', value.lower())
                if match:
                    num = int(match.group(1))
                    unit = match.group(2)
                    if unit == 'k':
                        num *= 1024
                    elif unit == 'm':
                        num *= 1024 * 1024
                    config.flash_size = num
            elif key == 'mirror':
                config.mirror = value.lower() in ('true', '1', 'yes', 'on')
            elif key == 'maxobjs':
                try:
                    config.max_objs = int(value)
                except ValueError:
                    pass
            elif key == 'cpucore':
                config.cpu_core = value.lower()
            elif key == 'dmahack':
                config.dma_hack = value.lower() in ('true', '1', 'yes', 'on')
            elif key == 'cycleshack':
                try:
                    config.cycles_hack = int(value)
                except ValueError:
                    pass
            elif key == 'interruptdelay':
                config.interrupt_delay = value.lower() in ('true', '1', 'yes', 'on')
            elif key == 'addon':
                config.addon = value.lower()

    def get_config(self, game_code: str) -> GameConfig:
        """Get config for a game code, with fallback to DEFAULT"""
        return self.configs.get(game_code.upper(), self._default_config)

    def get_save_type(self, game_code: str) -> int:
        """Get save type as integer for emulator"""
        config = self.get_config(game_code)
        return self.SAVE_TYPE_MAP.get(config.save_type.lower(), 0)

    def get_flash_size(self, game_code: str) -> int:
        """Get flash size in bytes"""
        config = self.get_config(game_code)
        if config.flash_size:
            return config.flash_size
        # Default based on save type
        if 'flash' in config.save_type:
            match = re.search(r'(\d+)', config.save_type)
            if match:
                kb = int(match.group(1))
                return self.FLASH_SIZE_MAP.get(kb, 131072)
        return 0

    def has_addon(self, game_code: str, addon_type: str) -> bool:
        """Check if game has specific addon (gyro, solar, tilt, rumble)"""
        config = self.get_config(game_code)
        return addon_type in config.addon

    def get_cpu_core(self, game_code: str) -> str:
        """Get CPU core type"""
        config = self.get_config(game_code)
        return config.cpu_core

    def needs_dma_hack(self, game_code: str) -> bool:
        return self.get_config(game_code).dma_hack

    def get_cycles_hack(self, game_code: str) -> Optional[int]:
        return self.get_config(game_code).cycles_hack

    def needs_interrupt_delay(self, game_code: str) -> bool:
        return self.get_config(game_code).interrupt_delay

    def get_mirror_setting(self, game_code: str) -> bool:
        return self.get_config(game_code).mirror

    def get_max_objects(self, game_code: str) -> Optional[int]:
        return self.get_config(game_code).max_objs


# Pre-built config for common Pokémon games (from MyBoy's rom_config.ini)
POKEMON_CONFIGS = {
    # Pokémon Emerald
    'BPEE': GameConfig('BPEE', 'Pokémon Emerald (U)', 'flash-128k', 131072, rtc=True),
    'BPEF': GameConfig('BPEF', 'Pokémon Emerald (F)', 'flash-128k', 131072, rtc=True),
    'BPED': GameConfig('BPED', 'Pokémon Emerald (G)', 'flash-128k', 131072, rtc=True),
    'BPEI': GameConfig('BPEI', 'Pokémon Emerald (I)', 'flash-128k', 131072, rtc=True),
    'BPEJ': GameConfig('BPEJ', 'Pokémon Emerald (J)', 'flash-128k', 131072, rtc=True),
    'BPES': GameConfig('BPES', 'Pokémon Emerald (S)', 'flash-128k', 131072, rtc=True),

    # Pokémon FireRed
    'BPRE': GameConfig('BPRE', 'Pokémon FireRed (U)', 'flash-128k', 131072),
    'BPRF': GameConfig('BPRF', 'Pokémon FireRed (F)', 'flash-128k', 131072),
    'BPRD': GameConfig('BPRD', 'Pokémon FireRed (G)', 'flash-128k', 131072),
    'BPRI': GameConfig('BPRI', 'Pokémon FireRed (I)', 'flash-128k', 131072),
    'BPRJ': GameConfig('BPRJ', 'Pokémon FireRed (J)', 'flash-128k', 131072),
    'BPRS': GameConfig('BPRS', 'Pokémon FireRed (S)', 'flash-128k', 131072),

    # Pokémon LeafGreen
    'BPGE': GameConfig('BPGE', 'Pokémon LeafGreen (U)', 'flash-128k', 131072),
    'BPGF': GameConfig('BPGF', 'Pokémon LeafGreen (F)', 'flash-128k', 131072),
    'BPGD': GameConfig('BPGD', 'Pokémon LeafGreen (G)', 'flash-128k', 131072),
    'BPGI': GameConfig('BPGI', 'Pokémon LeafGreen (I)', 'flash-128k', 131072),
    'BPGJ': GameConfig('BPGJ', 'Pokémon LeafGreen (J)', 'flash-128k', 131072),
    'BPGS': GameConfig('BPGS', 'Pokémon LeafGreen (S)', 'flash-128k', 131072),

    # Pokémon Ruby
    'AXVE': GameConfig('AXVE', 'Pokémon Ruby (UE)', 'flash-128k', 131072, rtc=True),
    'AXVF': GameConfig('AXVF', 'Pokémon Ruby (F)', 'flash-128k', 131072, rtc=True),
    'AXVD': GameConfig('AXVD', 'Pokémon Ruby (G)', 'flash-128k', 131072, rtc=True),
    'AXVI': GameConfig('AXVI', 'Pokémon Ruby (I)', 'flash-128k', 131072, rtc=True),
    'AXVJ': GameConfig('AXVJ', 'Pokémon Ruby (J)', 'flash-128k', 131072, rtc=True),
    'AXVS': GameConfig('AXVS', 'Pokémon Ruby (S)', 'flash-128k', 131072, rtc=True),

    # Pokémon Sapphire
    'AXPE': GameConfig('AXPE', 'Pokémon Sapphire (UE)', 'flash-128k', 131072, rtc=True),
    'AXPF': GameConfig('AXPF', 'Pokémon Sapphire (F)', 'flash-128k', 131072, rtc=True),
    'AXPD': GameConfig('AXPD', 'Pokémon Sapphire (G)', 'flash-128k', 131072, rtc=True),
    'AXPI': GameConfig('AXPI', 'Pokémon Sapphire (I)', 'flash-128k', 131072, rtc=True),
    'AXPJ': GameConfig('AXPJ', 'Pokémon Sapphire (J)', 'flash-128k', 131072, rtc=True),
    'AXPS': GameConfig('AXPS', 'Pokémon Sapphire (S)', 'flash-128k', 131072, rtc=True),

    # Pokémon Mystery Dungeon
    'B24E': GameConfig('B24E', 'Pokémon Mystery Dungeon Red (U)', 'flash-128k', 131072),
    'B24P': GameConfig('B24P', 'Pokémon Mystery Dungeon Red (E)', 'flash-128k', 131072),
    'B24J': GameConfig('B24J', 'Pokémon Mystery Dungeon Red (J)', 'flash-128k', 131072),

    # Other notable games
    'AFXE': GameConfig('AFXE', 'Final Fantasy Tactics Advance (U)', 'flash-64k', 65536),
    'AFXP': GameConfig('AFXP', 'Final Fantasy Tactics Advance (E)', 'flash-64k', 65536),
    'AFXJ': GameConfig('AFXJ', 'Final Fantasy Tactics Advance (J)', 'flash-64k', 65536),

    'AX4E': GameConfig('AX4E', 'Super Mario Advance 4 (U)', 'flash-128k', 131072),
    'AX4P': GameConfig('AX4P', 'Super Mario Advance 4 (E)', 'flash-128k', 131072),
    'AX4J': GameConfig('AX4J', 'Super Mario Advance 4 (J)', 'flash-128k', 131072),

    'BFTJ': GameConfig('BFTJ', 'F-Zero Climax (J)', 'flash-128k', 131072),
    'BGWJ': GameConfig('BGWJ', 'Gameboy Wars Advance 1+2 (J)', 'flash-128k', 131072),

    'V49': GameConfig('V49', 'Drill Dozer', 'eeprom', addon='rumble'),
    'RZW': GameConfig('RZW', 'WarioWare Twisted!', 'eeprom', addon='gyro+rumble'),
    'KHP': GameConfig('KHP', 'Koro Koro Puzzle Happy Panechu!', 'eeprom', addon='tilt'),
    'KYG': GameConfig('KYG', "Yoshi's Universal Gravitation", 'eeprom', addon='tilt'),
    'U3': GameConfig('U3', 'Boktai', 'eeprom', addon='solar'),
}


def create_default_parser() -> RomConfigParser:
    """Create a parser with built-in Pokémon configs"""
    parser = RomConfigParser()
    parser.configs.update(POKEMON_CONFIGS)
    return parser


if __name__ == '__main__':
    import sys

    if len(sys.argv) > 1:
        parser = RomConfigParser()
        configs = parser.parse_file(sys.argv[1])
        print(f"Parsed {len(configs)} game configs")
        for code, config in list(configs.items())[:10]:
            print(f"  {code}: {config.title} - save={config.save_type}, flash={config.flash_size}, addon={config.addon}")
    else:
        # Test with built-in configs
        parser = create_default_parser()
        print("Built-in Pokémon configs:")
        for code in ['BPRE', 'BPEE', 'AXVE', 'BPGE']:
            config = parser.get_config(code)
            print(f"  {code}: {config.title}")
            print(f"    save_type={config.save_type}, flash={config.flash_size}, rtc={config.rtc}")
            print(f"    addon={config.addon}")