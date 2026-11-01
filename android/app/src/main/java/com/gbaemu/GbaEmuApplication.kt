package com.gbaemu

import android.app.Application
import androidx.room.Room
import com.gbaemu.data.GameDatabase
import com.gbaemu.data.GameRepository

class GbaEmuApplication : Application() {

    companion object {
        @Suppress("UNUSED_PARAMETER")
        var instance: GbaEmuApplication? = null
            private set
    }

    private var gameDatabase: GameDatabase? = null
    private var gameRepository: GameRepository? = null

    override fun onCreate() {
        super.onCreate()
        instance = this

        // Initialize database
        gameDatabase = Room.databaseBuilder(
            this,
            GameDatabase::class.java,
            "gbaemu.db"
        ).fallbackToDestructiveMigration().build()

        gameRepository = GameRepository(gameDatabase!!)
    }

    fun getGameDatabase(): GameDatabase = gameDatabase!!
    fun getGameRepository(): GameRepository = gameRepository!!
}