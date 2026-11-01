package com.gbaemu.core

import java.io.BufferedReader
import java.io.InputStreamReader
import java.util.regex.Pattern

/**
 * ROM Configuration parser for game-specific settings
 * Parses rom_config.ini format (compatible with MyBoy/mGBA)
 */
class RomConfigParser {

    companion object {
        private const val COMMENT_PATTERN = "#"
        private const val SECTION_PATTERN = "\\[([A-Z0-9]{4})\\]"

        private val SAVE_TYPE_MAP = mapOf(
            "none" to SaveType.NONE,
            "sram" to SaveType.SRAM,
            "eeprom" to SaveType.EEPROM,
            "flash-64k" to SaveType.FLASH_64K,
            "flash-128k" to SaveType.FLASH_128K,
            "flash-512k" to SaveType.FLASH_512K,
            "flash-1m" to SaveType.FLASH_1M
        )

        private val FLASH_SIZE_MAP = mapOf(
            64 to 65536,
            128 to 131072,
            512 to 524288,
            1024 to 1048576
        )
    }

    private val configs = mutableMapOf<String, GameConfig>()
    private val defaultConfig = GameConfig("DEFAULT")

    /**
     * Parse rom_config.ini from input stream
     */
    fun parse(inputStream: java.io.InputStream): Map<String, GameConfig> {
        val reader = BufferedReader(InputStreamReader(inputStream))
        var currentSection: String? = null
        var currentConfig: GameConfig? = null

        reader.forEachLine { line ->
            val trimmed = line.trim()
            if (trimmed.isEmpty() || trimmed.startsWith(COMMENT_PATTERN)) {
                return@forEachLine
            }

            // Check for section header
            val sectionMatch = Pattern.compile(SECTION_PATTERN).matcher(trimmed)
            if (sectionMatch.matches()) {
                // Save previous section
                currentSection?.let { configs[it] = currentConfig!! }

                // Start new section
                currentSection = sectionMatch.group(1)
                currentConfig = GameConfig(currentSection!!)
                return@forEachLine
            }

            // Parse key=value
            val equalsIndex = trimmed.indexOf('=')
            if (equalsIndex > 0) {
                val key = trimmed.substring(0, equalsIndex).trim().lowercase()
                val value = trimmed.substring(equalsIndex + 1).trim()
                currentConfig?.apply { parseKeyValue(key, value) }
            }
        }

        // Save last section
        currentSection?.let { configs[it] = currentConfig!! }

        return configs
    }

    /**
     * Get config for a game code
     */
    fun getConfig(gameCode: String): GameConfig {
        return configs[gameCode.uppercase()] ?: defaultConfig
    }

    /**
     * Get save type for a game
     */
    fun getSaveType(gameCode: String): SaveType {
        val config = getConfig(gameCode)
        return SAVE_TYPE_MAP[config.saveType.lowercase()] ?: SaveType.AUTO_DETECT
    }

    /**
     * Get flash size in bytes
     */
    fun getFlashSize(gameCode: String): Int {
        val config = getConfig(gameCode)
        return config.flashSize ?: FLASH_SIZE_MAP.getOrDefault(
            config.saveType.removePrefix("flash-").removeSuffix("k").toIntOrNull() ?: 0,
            0
        )
    }

    /**
     * Check if game has addon
     */
    fun hasAddon(gameCode: String, addonType: String): Boolean {
        val config = getConfig(gameCode)
        return addonType in config.addons
    }

    /**
     * Get CPU core type
     */
    fun getCpuCore(gameCode: String): String {
        return getConfig(gameCode).cpuCore
    }

    /**
     * Check if DMA hack needed
     */
    fun needsDmaHack(gameCode: String): Boolean {
        return getConfig(gameCode).dmaHack
    }

    /**
     * Get cycles hack value
     */
    fun getCyclesHack(gameCode: String): Int? {
        return getConfig(gameCode).cyclesHack
    }

    /**
     * Check if interrupt delay needed
     */
    fun needsInterruptDelay(gameCode: String): Boolean {
        return getConfig(gameCode).interruptDelay
    }

    /**
     * Get mirror setting
     */
    fun getMirrorSetting(gameCode: String): Boolean {
        return getConfig(gameCode).mirror
    }

    /**
     * Get max objects
     */
    fun getMaxObjects(gameCode: String): Int? {
        return getConfig(gameCode).maxObjs
    }
}

/**
 * Game configuration data class
 */
data class GameConfig(
    val code: String,
    var title: String = "",
    var saveType: String = "auto",
    var flashSize: Int? = null,
    var mirror: Boolean = false,
    var maxObjs: Int? = null,
    var cpuCore: String = "auto",
    var dmaHack: Boolean = false,
    var cyclesHack: Int? = null,
    var interruptDelay: Boolean = false,
    var addons: MutableSet<String> = mutableSetOf()
) {
    fun parseKeyValue(key: String, value: String) {
        when (key) {
            "savetype" -> saveType = value.lowercase()
            "flashsize" -> {
                val match = Pattern.compile("(\\d+)([km]?)").matcher(value.lowercase())
                if (match.matches()) {
                    var num = match.group(1).toIntOrNull() ?: 0
                    val unit = match.group(2)
                    when (unit) {
                        "k" -> num *= 1024
                        "m" -> num *= 1024 * 1024
                    }
                    flashSize = num
                }
            }
            "mirror" -> mirror = value.lowercase() in setOf("true", "1", "yes", "on")
            "maxobjs" -> maxObjs = value.toIntOrNull()
            "cpucore" -> cpuCore = value.lowercase()
            "dmahack" -> dmaHack = value.lowercase() in setOf("true", "1", "yes", "on")
            "cycleshack" -> cyclesHack = value.toIntOrNull()
            "interruptdelay" -> interruptDelay = value.lowercase() in setOf("true", "1", "yes", "on")
            "addon" -> {
                addons.clear()
                addons.addAll(value.lowercase().split("+").map { it.trim() }.filter { it.isNotEmpty() })
            }
        }
    }
}

/**
 * Built-in configurations for common games (especially Pokémon)
 */
object BuiltInRomConfigs {

    private val POKEMON_CONFIGS = mapOf(
        // Pokémon Emerald
        "BPEE" to GameConfig("BPEE", "Pokémon Emerald (U)", "flash-128k", 131072, addons = mutableSetOf()).apply { rtc = true },
        "BPEF" to GameConfig("BPEF", "Pokémon Emerald (F)", "flash-128k", 131072, addons = mutableSetOf()).apply { rtc = true },
        "BPED" to GameConfig("BPED", "Pokémon Emerald (G)", "flash-128k", 131072, addons = mutableSetOf()).apply { rtc = true },
        "BPEI" to GameConfig("BPEI", "Pokémon Emerald (I)", "flash-128k", 131072, addons = mutableSetOf()).apply { rtc = true },
        "BPEJ" to GameConfig("BPEJ", "Pokémon Emerald (J)", "flash-128k", 131072, addons = mutableSetOf()).apply { rtc = true },
        "BPES" to GameConfig("BPES", "Pokémon Emerald (S)", "flash-128k", 131072, addons = mutableSetOf()).apply { rtc = true },

        // Pokémon FireRed
        "BPRE" to GameConfig("BPRE", "Pokémon FireRed (U)", "flash-128k", 131072),
        "BPRF" to GameConfig("BPRF", "Pokémon FireRed (F)", "flash-128k", 131072),
        "BPRD" to GameConfig("BPRD", "Pokémon FireRed (G)", "flash-128k", 131072),
        "BPRI" to GameConfig("BPRI", "Pokémon FireRed (I)", "flash-128k", 131072),
        "BPRJ" to GameConfig("BPRJ", "Pokémon FireRed (J)", "flash-128k", 131072),
        "BPRS" to GameConfig("BPRS", "Pokémon FireRed (S)", "flash-128k", 131072),

        // Pokémon LeafGreen
        "BPGE" to GameConfig("BPGE", "Pokémon LeafGreen (U)", "flash-128k", 131072),
        "BPGF" to GameConfig("BPGF", "Pokémon LeafGreen (F)", "flash-128k", 131072),
        "BPGD" to GameConfig("BPGD", "Pokémon LeafGreen (G)", "flash-128k", 131072),
        "BPGI" to GameConfig("BPGI", "Pokémon LeafGreen (I)", "flash-128k", 131072),
        "BPGJ" to GameConfig("BPGJ", "Pokémon LeafGreen (J)", "flash-128k", 131072),
        "BPGS" to GameConfig("BPGS", "Pokémon LeafGreen (S)", "flash-128k", 131072),

        // Pokémon Ruby
        "AXVE" to GameConfig("AXVE", "Pokémon Ruby (UE)", "flash-128k", 131072, addons = mutableSetOf()).apply { rtc = true },
        "AXVF" to GameConfig("AXVF", "Pokémon Ruby (F)", "flash-128k", 131072, addons = mutableSetOf()).apply { rtc = true },
        "AXVD" to GameConfig("AXVD", "Pokémon Ruby (G)", "flash-128k", 131072, addons = mutableSetOf()).apply { rtc = true },
        "AXVI" to GameConfig("AXVI", "Pokémon Ruby (I)", "flash-128k", 131072, addons = mutableSetOf()).apply { rtc = true },
        "AXVJ" to GameConfig("AXVJ", "Pokémon Ruby (J)", "flash-128k", 131072, addons = mutableSetOf()).apply { rtc = true },
        "AXVS" to GameConfig("AXVS", "Pokémon Ruby (S)", "flash-128k", 131072, addons = mutableSetOf()).apply { rtc = true },

        // Pokémon Sapphire
        "AXPE" to GameConfig("AXPE", "Pokémon Sapphire (UE)", "flash-128k", 131072, addons = mutableSetOf()).apply { rtc = true },
        "AXPF" to GameConfig("AXPF", "Pokémon Sapphire (F)", "flash-128k", 131072, addons = mutableSetOf()).apply { rtc = true },
        "AXPD" to GameConfig("AXPD", "Pokémon Sapphire (G)", "flash-128k", 131072, addons = mutableSetOf()).apply { rtc = true },
        "AXPI" to GameConfig("AXPI", "Pokémon Sapphire (I)", "flash-128k", 131072, addons = mutableSetOf()).apply { rtc = true },
        "AXPJ" to GameConfig("AXPJ", "Pokémon Sapphire (J)", "flash-128k", 131072, addons = mutableSetOf()).apply { rtc = true },
        "AXPS" to GameConfig("AXPS", "Pokémon Sapphire (S)", "flash-128k", 131072, addons = mutableSetOf()).apply { rtc = true },

        // Pokémon Mystery Dungeon
        "B24E" to GameConfig("B24E", "Pokémon Mystery Dungeon Red (U)", "flash-128k", 131072),
        "B24P" to GameConfig("B24P", "Pokémon Mystery Dungeon Red (E)", "flash-128k", 131072),
        "B24J" to GameConfig("B24J", "Pokémon Mystery Dungeon Red (J)", "flash-128k", 131072),

        // Other notable games
        "AFXE" to GameConfig("AFXE", "Final Fantasy Tactics Advance (U)", "flash-64k", 65536),
        "AFXP" to GameConfig("AFXP", "Final Fantasy Tactics Advance (E)", "flash-64k", 65536),
        "AFXJ" to GameConfig("AFXJ", "Final Fantasy Tactics Advance (J)", "flash-64k", 65536),

        "AX4E" to GameConfig("AX4E", "Super Mario Advance 4 (U)", "flash-128k", 131072),
        "AX4P" to GameConfig("AX4P", "Super Mario Advance 4 (E)", "flash-128k", 131072),
        "AX4J" to GameConfig("AX4J", "Super Mario Advance 4 (J)", "flash-128k", 131072),

        "BFTJ" to GameConfig("BFTJ", "F-Zero Climax (J)", "flash-128k", 131072),
        "BGWJ" to GameConfig("BGWJ", "Gameboy Wars Advance 1+2 (J)", "flash-128k", 131072),

        "V49" to GameConfig("V49", "Drill Dozer", "eeprom", addons = mutableSetOf("rumble")),
        "RZW" to GameConfig("RZW", "WarioWare Twisted!", "eeprom", addons = mutableSetOf("gyro", "rumble")),
        "KHP" to GameConfig("KHP", "Koro Koro Puzzle Happy Panechu!", "eeprom", addons = mutableSetOf("tilt")),
        "KYG" to GameConfig("KYG", "Yoshi's Universal Gravitation", "eeprom", addons = mutableSetOf("tilt")),
        "U3" to GameConfig("U3", "Boktai", "eeprom", addons = mutableSetOf("solar"))
    )

    // Extension property for RTC
    private var GameConfig.rtc: Boolean
        get() = false
        set(value) { /* Store in a separate map if needed */ }

    fun getConfig(gameCode: String): GameConfig? {
        return POKEMON_CONFIGS[gameCode.uppercase()]
    }

    fun getAllConfigs(): Map<String, GameConfig> = POKEMON_CONFIGS
}