package com.gbaemu.ui

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import android.os.Bundle
import android.view.View
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.gbaemu.core.EmulatorConfig
import com.gbaemu.core.FrameCallback
import com.gbaemu.core.GbaCore
import com.gbaemu.core.GbaKeys
import com.gbaemu.core.GameInfo
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {

    private val gameListViewModel: GameListViewModel by viewModel()
    private var core: GbaCore? = null
    private var currentGame: GameItem? = null

    private val filePicker = registerForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        uri?.let { loadGameFromUri(it) }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent { AppScreen() }
    }

    @Composable
    fun AppScreen() {
        var currentScreen by remember { mutableStateOf<Screen>(Screen.GAME_LIST) }
        var selectedGame by remember { mutableStateOf<GameItem?>(null) }
        var emulationFrame by remember { mutableStateOf<ImageBitmap?>(null) }

        MaterialTheme {
            Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
                when (currentScreen) {
                    Screen.GAME_LIST -> GameListScreen(
                        viewModel = gameListViewModel,
                        onGameClick = { game ->
                            selectedGame = game
                            startEmulation(game)
                            currentScreen = Screen.EMULATION
                        },
                        onImportClick = { filePicker.launch(arrayOf("application/octet-stream")) }
                    )
                    Screen.EMULATION -> selectedGame?.let { game ->
                        EmulationScreen(
                            gameInfo = GameInfo(
                                title = game.title,
                                gameCode = game.gameCode,
                                makerCode = "",
                                saveType = 0,
                                hasRTC = false,
                                hasGyro = false,
                                hasSolar = false,
                                hasRumble = false,
                                romSize = game.fileSize.toInt(),
                                crc32 = 0
                            ),
                            onBack = { stopEmulation(); currentScreen = Screen.GAME_LIST },
                            onMenu = { /* Show pause menu */ },
                            onSaveState = { saveCurrentState() },
                            onLoadState = { loadSavedState() },
                            onFastForward = { /* Toggle fast forward */ },
                            onToggleCheats = { /* Show cheat menu */ }
                        )
                    }
                }
            }
        }
    }

    private fun startEmulation(game: GameItem) {
        lifecycleScope.launch {
            core = GbaCore.getInstance(this@MainActivity)
            core?.loadRom(game.file.readBytes())
            
            // Set up frame callback
            core?.start(
                frameCallback = { buffer, width, height, stride, timestamp ->
                    // Convert ByteBuffer to Bitmap for Compose
                    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                    buffer.rewind()
                    bitmap.copyPixelsFromBuffer(buffer)
                    
                    // Update UI on main thread
                    runOnUiThread {
                        // In real implementation, use a dedicated ImageView or Compose ImageBitmap
                    }
                },
                audioCallback = { samples, sampleRate, timestamp ->
                    // Play audio via AudioTrack or Media3
                },
                saveCallback = { data ->
                    // Auto-save battery
                },
                logCallback = { level, message ->
                    android.util.Log.d("GbaEmu", message)
                },
                stateCallback = { state, message ->
                    // Handle state changes
                }
            )
        }
    }

    private fun stopEmulation() {
        core?.stop()
        core = null
    }

    private fun saveCurrentState() {
        core?.saveState()?.onSuccess { data ->
            // Save to file
            val file = File(filesDir, "${currentGame?.title}.state")
            file.writeBytes(data)
        }
    }

    private fun loadSavedState() {
        val file = File(filesDir, "${currentGame?.title}.state")
        if (file.exists()) {
            core?.loadState(file.readBytes())
        }
    }

    private fun loadGameFromUri(uri: android.net.Uri) {
        contentResolver.openInputStream(uri)?.use { input ->
            val bytes = input.readAllBytes()
            val game = GameItem(
                file = File(uri.path!!),
                title = uri.lastPathSegment?.removeSuffix(".gba") ?: "Unknown",
                gameCode = "UNKN",
                region = "?",
                fileSize = bytes.size.toLong(),
                lastPlayed = System.currentTimeMillis()
            )
            startEmulation(game)
        }
    }

    override fun onDestroy() {
        GbaCore.destroyInstance()
        super.onDestroy()
    }
}

enum class Screen { GAME_LIST, EMULATION }