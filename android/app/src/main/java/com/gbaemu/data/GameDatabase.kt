package com.gbaemu.data

import androidx.room.*
import kotlinx.serialization.Serializable

@Entity(tableName = "games")
@Serializable
data class GameEntity(
    @PrimaryKey @ColumnInfo(name = "path") val path: String,
    @ColumnInfo(name = "title") val title: String,
    @ColumnInfo(name = "game_code") val gameCode: String,
    @ColumnInfo(name = "region") val region: String,
    @ColumnInfo(name = "file_size") val fileSize: Long,
    @ColumnInfo(name = "last_played") val lastPlayed: Long,
    @ColumnInfo(name = "play_count") val playCount: Int = 0,
    @ColumnInfo(name = "total_play_time") val totalPlayTime: Long = 0,
    @ColumnInfo(name = "crc32") val crc32: Int = 0,
    @ColumnInfo(name = "favorite") val favorite: Boolean = false
)

@Entity(tableName = "save_states")
@Serializable
data class SaveStateEntity(
    @PrimaryKey @ColumnInfo(name = "id") val id: String,
    @ColumnInfo(name = "game_path") val gamePath: String,
    @ColumnInfo(name = "slot") val slot: Int,
    @ColumnInfo(name = "name") val name: String,
    @ColumnInfo(name = "data") val data: ByteArray,
    @ColumnInfo(name = "timestamp") val timestamp: Long,
    @ColumnInfo(name = "thumbnail") val thumbnail: ByteArray? = null
)

@Entity(tableName = "cheats")
@Serializable
data class CheatEntity(
    @PrimaryKey(autoGenerate = true) @ColumnInfo(name = "id") val id: Int = 0,
    @ColumnInfo(name = "game_path") val gamePath: String,
    @ColumnInfo(name = "address") val address: Int,
    @ColumnInfo(name = "value") val value: Short,
    @ColumnInfo(name = "mask") val mask: Short,
    @ColumnInfo(name = "enabled") val enabled: Boolean,
    @ColumnInfo(name = "description") val description: String,
    @ColumnInfo(name = "type") val type: Int
)

@Entity(tableName = "settings")
@Serializable
data class SettingEntity(
    @PrimaryKey @ColumnInfo(name = "key") val key: String,
    @ColumnInfo(name = "value") val value: String
)

@Dao
interface GameDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertGame(game: GameEntity)

    @Query("SELECT * FROM games ORDER BY last_played DESC")
    fun getAllGames(): androidx.lifecycle.LiveData<List<GameEntity>>

    @Query("SELECT * FROM games WHERE path = :path")
    suspend fun getGame(path: String): GameEntity?

    @Query("UPDATE games SET last_played = :time, play_count = play_count + 1 WHERE path = :path")
    suspend fun updatePlayStats(path: String, time: Long)

    @Query("DELETE FROM games WHERE path = :path")
    suspend fun deleteGame(path: String)

    @Query("SELECT * FROM games WHERE favorite = 1")
    fun getFavorites(): androidx.lifecycle.LiveData<List<GameEntity>>

    @Query("UPDATE games SET favorite = :fav WHERE path = :path")
    suspend fun setFavorite(path: String, fav: Boolean)

    // Save states
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertSaveState(state: SaveStateEntity)

    @Query("SELECT * FROM save_states WHERE game_path = :gamePath ORDER BY slot")
    fun getSaveStates(gamePath: String): androidx.lifecycle.LiveData<List<SaveStateEntity>>

    @Query("SELECT * FROM save_states WHERE game_path = :gamePath AND slot = :slot")
    suspend fun getSaveState(gamePath: String, slot: Int): SaveStateEntity?

    @Query("DELETE FROM save_states WHERE id = :id")
    suspend fun deleteSaveState(id: String)

    // Cheats
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertCheat(cheat: CheatEntity)

    @Query("SELECT * FROM cheats WHERE game_path = :gamePath")
    fun getCheats(gamePath: String): androidx.lifecycle.LiveData<List<CheatEntity>>

    @Query("DELETE FROM cheats WHERE id = :id")
    suspend fun deleteCheat(id: Int)

    @Query("DELETE FROM cheats WHERE game_path = :gamePath")
    suspend fun clearCheats(gamePath: String)

    // Settings
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertSetting(setting: SettingEntity)

    @Query("SELECT value FROM settings WHERE key = :key")
    suspend fun getSetting(key: String): String?

    @Query("SELECT * FROM settings")
    fun getAllSettings(): androidx.lifecycle.LiveData<List<SettingEntity>>
}

@Database(entities = [GameEntity::class, SaveStateEntity::class, CheatEntity::class, SettingEntity::class], version = 1, exportSchema = false)
abstract class GameDatabase : RoomDatabase() {
    abstract fun gameDao(): GameDao
}

class GameRepository(private val database: GameDatabase) {

    private val dao = database.gameDao()

    suspend fun addOrUpdateGame(game: GameEntity) {
        dao.insertGame(game)
    }

    fun getAllGames() = dao.getAllGames()

    suspend fun getGame(path: String) = dao.getGame(path)

    suspend fun updatePlayStats(path: String) {
        dao.updatePlayStats(path, System.currentTimeMillis())
    }

    suspend fun deleteGame(path: String) {
        dao.deleteGame(path)
        dao.clearCheats(path)
    }

    fun getFavorites() = dao.getFavorites()

    suspend fun setFavorite(path: String, favorite: Boolean) {
        dao.setFavorite(path, favorite)
    }

    // Save states
    suspend fun saveState(state: SaveStateEntity) {
        dao.insertSaveState(state)
    }

    fun getSaveStates(gamePath: String) = dao.getSaveStates(gamePath)

    suspend fun getSaveState(gamePath: String, slot: Int) = dao.getSaveState(gamePath, slot)

    suspend fun deleteSaveState(id: String) = dao.deleteSaveState(id)

    // Cheats
    suspend fun addCheat(cheat: CheatEntity) = dao.insertCheat(cheat)

    fun getCheats(gamePath: String) = dao.getCheats(gamePath)

    suspend fun deleteCheat(id: Int) = dao.deleteCheat(id)

    suspend fun clearCheats(gamePath: String) = dao.clearCheats(gamePath)

    // Settings
    suspend fun setSetting(key: String, value: String) {
        dao.insertSetting(SettingEntity(key, value))
    }

    suspend fun getSetting(key: String, default: String = ""): String {
        return dao.getSetting(key) ?: default
    }

    fun getAllSettings() = dao.getAllSettings()
}