package com.gbaemu.ui

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.gbaemu.core.EmulatorConfig
import com.gbaemu.core.GbaCore
import com.gbaemu.core.GameInfo
import kotlinx.coroutines.launch
import java.io.File

/**
 * Main game list screen
 */
@androidx.compose.runtime.Composable
fun GameListScreen(
    viewModel: GameListViewModel = viewModel(),
    onGameClick: (GameItem) -> Unit,
    onImportClick: () -> Unit
) {
    val games by viewModel.games.collectAsStateWithLifecycle()
    val isLoading by viewModel.isLoading.collectAsStateWithLifecycle()
    val context = LocalContext.current

    Surface(
        modifier = Modifier.fillMaxSize(),
        color = MaterialTheme.colorScheme.background
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            // Top App Bar
            TopAppBar(
                title = { Text("GBA Emu") },
                actions = {
                    IconButton(onClick = onImportClick) {
                        Icon(Icons.Default.FolderOpen, contentDescription = "Import ROM")
                    }
                    IconButton(onClick = { viewModel.refresh() }) {
                        Icon(Icons.Default.Refresh, contentDescription = "Refresh")
                    }
                    IconButton(onClick = { /* Settings */ }) {
                        Icon(Icons.Default.Settings, contentDescription = "Settings")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surfaceContainer
                )
            )

            // Game list
            if (isLoading) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
            } else if (games.isEmpty()) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Icon(Icons.Default.VideogameAssetOff, contentDescription = "No games", modifier = Modifier.size(64.dp))
                        Spacer(Modifier.height(16.dp))
                        Text("Nenhum jogo encontrado", fontSize = 18.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Spacer(Modifier.height(8.dp))
                        Text("Toque em 'Importar' para adicionar ROMs", color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Spacer(Modifier.height(16.dp))
                        Button(onClick = onImportClick) {
                            Text("Importar ROM")
                        }
                    }
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    items(games) { game ->
                        GameItemCard(game = game, onClick = { onGameClick(game) })
                    }
                }
            }
        }
    }
}

/**
 * Game item card
 */
@androidx.compose.runtime.Composable
fun GameItemCard(
    game: GameItem,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        onClick = onClick,
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp),
        shape = RoundedCornerShape(12.dp)
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Game icon/thumbnail
            Box(
                modifier = Modifier
                    .size(64.dp)
                    .background(MaterialTheme.colorScheme.surfaceContainerHighest, RoundedCornerShape(8.dp))
            ) {
                game.thumbnail?.let { bitmap ->
                    androidx.compose.ui.graphics.ImageBitmap.imageResource(bitmap)
                } ?: Icon(Icons.Default.VideogameAsset, contentDescription = "Game", modifier = Modifier
                    .fillMaxSize()
                    .align(Alignment.Center)
                    .size(32.dp))
            }

            Spacer(Modifier.width(16.dp))

            // Game info
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = game.title,
                    fontWeight = FontWeight.Bold,
                    fontSize = 16.sp,
                    maxLines = 1,
                    overflow = androidx.compose.ui.text.TextOverflow.Ellipsis
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    text = "${game.gameCode} • ${game.region} • ${formatFileSize(game.fileSize)}",
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                if (game.lastPlayed > 0) {
                    Spacer(Modifier.height(2.dp))
                    Text(
                        text = "Jogado em ${formatDate(game.lastPlayed)}",
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f)
                    )
                }
            }

            // Play indicator
            Icon(Icons.Default.PlayArrow, contentDescription = "Play", tint = MaterialTheme.colorScheme.primary)
        }
    }
}

/**
 * Emulation screen with virtual gamepad
 */
@androidx.compose.runtime.Composable
fun EmulationScreen(
    gameInfo: GameInfo,
    onBack: () -> Unit,
    onMenu: () -> Unit,
    onSaveState: () -> Unit,
    onLoadState: () -> Unit,
    onFastForward: () -> Unit,
    onToggleCheats: () -> Unit
) {
    Box(modifier = Modifier.fillMaxSize()) {
        // Game view (placeholder - would be replaced with actual frame rendering)
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center
        ) {
            Surface(
                modifier = Modifier
                    .aspectRatio(240f / 160f)
                    .padding(16.dp),
                shape = RoundedCornerShape(8.dp),
                color = Color.Black,
                border = androidx.compose.ui.graphics.BorderStroke(2.dp, MaterialTheme.colorScheme.outline)
            ) {
                Text(
                    "Emulando: ${gameInfo.title}",
                    color = Color.White,
                    fontSize = 18.sp
                )
            }
        }

        // Top controls
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalAlignment = Alignment.End
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End
            ) {
                IconButton(onClick = onSaveState) {
                    Icon(Icons.Default.Save, contentDescription = "Save State")
                }
                Spacer(Modifier.width(8.dp))
                IconButton(onClick = onLoadState) {
                    Icon(Icons.Default.Restore, contentDescription = "Load State")
                }
                Spacer(Modifier.width(8.dp))
                IconButton(onClick = onFastForward) {
                    Icon(Icons.Default.FastForward, contentDescription = "Fast Forward")
                }
                Spacer(Modifier.width(8.dp))
                IconButton(onClick = onToggleCheats) {
                    Icon(Icons.Default.AutoFixHigh, contentDescription = "Cheats")
                }
                Spacer(Modifier.width(8.dp))
                IconButton(onClick = onMenu) {
                    Icon(Icons.Default.Menu, contentDescription = "Menu")
                }
            }
        }

        // Virtual gamepad (bottom)
        VirtualGamepad(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 16.dp)
                .align(Alignment.BottomCenter)
        )
    }
}

/**
 * Virtual gamepad with D-pad and buttons
 */
@androidx.compose.runtime.Composable
fun VirtualGamepad(
    modifier: Modifier = Modifier,
    onKeyPress: (Int, Boolean) -> Unit = { _, _ -> }
) {
    val keyStates = remember { mutableStateMapOf<Int, Boolean>() }

    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // D-Pad
        Box(
            modifier = Modifier
                .width(200.dp)
                .height(120.dp)
                .padding(bottom = 16.dp)
        ) {
            // Up
            GamepadButton(
                modifier = Modifier.align(Alignment.TopCenter),
                icon = Icons.Default.KeyboardArrowUp,
                onPress = { pressed -> onKeyPress(6, pressed); keyStates[6] = pressed }
            )
            // Left
            GamepadButton(
                modifier = Modifier.align(Alignment.CenterStart),
                icon = Icons.Default.KeyboardArrowLeft,
                onPress = { pressed -> onKeyPress(5, pressed); keyStates[5] = pressed }
            )
            // Right
            GamepadButton(
                modifier = Modifier.align(Alignment.CenterEnd),
                icon = Icons.Default.KeyboardArrowRight,
                onPress = { pressed -> onKeyPress(4, pressed); keyStates[4] = pressed }
            )
            // Down
            GamepadButton(
                modifier = Modifier.align(Alignment.BottomCenter),
                icon = Icons.Default.KeyboardArrowDown,
                onPress = { pressed -> onKeyPress(7, pressed); keyStates[7] = pressed }
            )
        }

        // Action buttons (A, B, Start, Select)
        Row(
            modifier = Modifier
                .width(280.dp)
                .padding(horizontal = 16.dp),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            // Select
            GamepadButton(
                modifier = Modifier.size(48.dp),
                icon = Icons.Default.MoreHoriz,
                onPress = { pressed -> onKeyPress(2, pressed); keyStates[2] = pressed }
            )

            // Start
            GamepadButton(
                modifier = Modifier.size(48.dp),
                icon = Icons.Default.PlayArrow,
                onPress = { pressed -> onKeyPress(3, pressed); keyStates[3] = pressed }
            )

            // B button
            GamepadButton(
                modifier = Modifier.size(64.dp),
                text = "B",
                onPress = { pressed -> onKeyPress(1, pressed); keyStates[1] = pressed },
                isActionButton = true
            )

            // A button
            GamepadButton(
                modifier = Modifier.size(64.dp),
                text = "A",
                onPress = { pressed -> onKeyPress(0, pressed); keyStates[0] = pressed },
                isActionButton = true
            )
        }

        Spacer(Modifier.height(8.dp))

        // Shoulder buttons (L, R)
        Row(
            modifier = Modifier
                .width(280.dp)
                .padding(horizontal = 16.dp),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            GamepadButton(
                modifier = Modifier.size(64.dp).height(40.dp),
                text = "L",
                onPress = { pressed -> onKeyPress(9, pressed); keyStates[9] = pressed },
                isShoulderButton = true
            )
            GamepadButton(
                modifier = Modifier.size(64.dp).height(40.dp),
                text = "R",
                onPress = { pressed -> onKeyPress(8, pressed); keyStates[8] = pressed },
                isShoulderButton = true
            )
        }
    }
}

/**
 * Individual gamepad button
 */
@androidx.compose.runtime.Composable
fun GamepadButton(
    modifier: Modifier = Modifier,
    icon: androidx.compose.ui.graphics.vector.ImageVector? = null,
    text: String? = null,
    onPress: (Boolean) -> Unit,
    isActionButton: Boolean = false,
    isShoulderButton: Boolean = false
) {
    var pressed by remember { mutableStateOf(false) }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(
                if (pressed) MaterialTheme.colorScheme.primaryContainer
                else if (isActionButton) MaterialTheme.colorScheme.secondaryContainer
                else if (isShoulderButton) MaterialTheme.colorScheme.surfaceContainerHigh
                else MaterialTheme.colorScheme.surfaceContainer,
                shape = if (isShoulderButton) RoundedCornerShape(8.dp) else RoundedCornerShape(50.dp)
            )
            .pointerInput(Unit) {
                detectTapGestures(
                    onPress = { pressed = true; onPress(true) },
                    onRelease = { pressed = false; onPress(false) }
                )
            }
    ) {
        if (icon != null) {
            Icon(icon, contentDescription = "", modifier = Modifier.align(Alignment.Center).size(24.dp))
        }
        if (text != null) {
            Text(
                text = text,
                fontSize = if (isShoulderButton) 14.sp else 20.sp,
                fontWeight = FontWeight.Bold,
                color = if (isActionButton) MaterialTheme.colorScheme.onSecondaryContainer
                else MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.align(Alignment.Center)
            )
        }
    }
}

/**
 * ViewModel for game list
 */
class GameListViewModel : androidx.lifecycle.ViewModel() {
    private val _games = MutableStateFlow<List<GameItem>>(emptyList())
    val games: StateFlow<List<GameItem>> = _games
    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading

    fun refresh() {
        viewModelScope.launch {
            _isLoading.value = true
            // Scan for ROMs in standard directories
            val romDirs = listOf(
                File(android.os.Environment.getExternalStoragePublicDirectory(android.os.Environment.DIRECTORY_DOWNLOADS).path),
                File(android.os.Environment.getExternalStoragePublicDirectory(android.os.Environment.DIRECTORY_DOCUMENTS).path),
                File("/sdcard/ROMs"),
                File("/sdcard/GBA"),
                File("/sdcard/Roms/GBA")
            )

            val foundGames = mutableListOf<GameItem>()
            for (dir in romDirs) {
                if (dir.exists() && dir.isDirectory) {
                    dir.listFiles()?.filter { it.extension.lowercase() in setOf("gba", "zip", "7z") }?.forEach { file ->
                        foundGames.add(GameItem.fromFile(file))
                    }
                }
            }
            _games.value = foundGames.sortedBy { it.title }
            _isLoading.value = false
        }
    }
}

/**
 * Game item data class
 */
data class GameItem(
    val file: File,
    val title: String,
    val gameCode: String,
    val region: String,
    val fileSize: Long,
    val lastPlayed: Long,
    val thumbnail: androidx.compose.ui.graphics.ImageBitmap? = null
) {
    companion object {
        fun fromFile(file: File): GameItem {
            // In real implementation, parse ROM header for title, game code, etc.
            val name = file.nameWithoutExtension
            return GameItem(
                file = file,
                title = name,
                gameCode = "UNKN",
                region = "?",
                fileSize = file.length(),
                lastPlayed = file.lastModified()
            )
        }
    }
}

/**
 * Format utilities
 */
fun formatFileSize(bytes: Long): String {
    return when {
        bytes >= 1_073_741_824 -> String.format("%.1f GB", bytes / 1_073_741_824.0)
        bytes >= 1_048_576 -> String.format("%.1f MB", bytes / 1_048_576.0)
        bytes >= 1024 -> String.format("%.1f KB", bytes / 1024.0)
        else -> "$bytes B"
    }
}

fun formatDate(timestamp: Long): String {
    return android.text.format.DateFormat.format("dd/MM/yyyy HH:mm", timestamp).toString()
}