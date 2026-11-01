package com.gbaemu.core

import kotlinx.coroutines.*
import java.nio.ByteBuffer

/**
 * Link Cable / Multiplayer support for GBA
 */
class GbaLink private constructor(private val nativeHandle: Long) {

    companion object {
        fun create(): GbaLink {
            val handle = nativeCreate()
            if (handle == 0L) {
                throw IllegalStateException("Failed to create Link cable")
            }
            return GbaLink(handle)
        }

        private external fun nativeCreate(): Long
    }

    private external fun nativeDestroy()
    external fun nativeConnect(coreHandle: Long): Boolean
    external fun nativeDisconnect()
    external fun nativeSendData(data: ByteArray): Boolean
    external fun nativeReceiveData(maxSize: Int): ByteArray?
    external fun nativeIsConnected(): Boolean

    init {
        System.loadLibrary("gbaemu-jni")
    }

    /**
     * Connect to a GBA core for link cable emulation
     */
    fun connect(core: GbaCore): Boolean = nativeConnect(core.nativeHandle)

    /**
     * Disconnect link cable
     */
    fun disconnect() = nativeDisconnect()

    /**
     * Send data over link cable
     */
    suspend fun sendData(data: ByteArray): Boolean = withContext(Dispatchers.IO) {
        nativeSendData(data)
    }

    /**
     * Receive data from link cable
     */
    suspend fun receiveData(maxSize: Int = 256): ByteArray? = withContext(Dispatchers.IO) {
        nativeReceiveData(maxSize)
    }

    /**
     * Check if connected
     */
    fun isConnected(): Boolean = nativeIsConnected()

    /**
     * Cleanup
     */
    fun destroy() {
        nativeDestroy()
    }
}

/**
 * Link cable connection manager for multiplayer sessions
 */
class LinkManager {

    private var link: GbaLink? = null
    private var connectedCores: MutableList<GbaCore> = mutableListOf()
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    /**
     * Start a link cable session (host)
     */
    fun startSession(hostCore: GbaCore): Result<GbaLink> {
        return try {
            val link = GbaLink.create()
            if (link.connect(hostCore)) {
                this.link = link
                connectedCores.add(hostCore)
                Result.success(link)
            } else {
                link.destroy()
                Result.failure(IllegalStateException("Failed to connect host"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    /**
     * Join a link cable session (client)
     */
    fun joinSession(clientCore: GbaCore): Result<GbaLink> {
        return try {
            val link = GbaLink.create()
            if (link.connect(clientCore)) {
                this.link = link
                connectedCores.add(clientCore)
                Result.success(link)
            } else {
                link.destroy()
                Result.failure(IllegalStateException("Failed to connect client"))
            } catch (e: Exception) {
                Result.failure(e)
            }
        }
    }

    /**
     * Send data to all connected peers
     */
    suspend fun broadcast(data: ByteArray): Boolean {
        return link?.sendData(data) ?: false
    }

    /**
     * Receive data from link
     */
    suspend fun receive(maxSize: Int = 256): ByteArray? {
        return link?.receiveData(maxSize)
    }

    /**
     * Check if session is active
     */
    fun isActive(): Boolean = link?.isConnected() ?: false

    /**
     * End session
     */
    fun endSession() {
        link?.disconnect()
        link?.destroy()
        link = null
        connectedCores.clear()
        scope.cancel()
    }
}

/**
 * Network link cable implementation (for online multiplayer)
 * This would use WebRTC or similar for actual network play
 */
class NetworkLinkManager(
    private val signalingServer: String,
    private val roomId: String
) {

    private var isHost = false
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val messageChannel = Channel<ByteArray>(Channel.UNLIMITED)

    /**
     * Create a new room (host)
     */
    suspend fun host(): Result<Unit> = withContext(Dispatchers.IO) {
        // TODO: Implement WebRTC signaling
        isHost = true
        Result.success(Unit)
    }

    /**
     * Join existing room (client)
     */
    suspend fun join(): Result<Unit> = withContext(Dispatchers.IO) {
        // TODO: Implement WebRTC signaling
        isHost = false
        Result.success(Unit)
    }

    /**
     * Send data to peers
     */
    suspend fun send(data: ByteArray) {
        messageChannel.send(data)
    }

    /**
     * Receive data from peers
     */
    fun receive(): ReceiveChannel<ByteArray> = messageChannel

    /**
     * Leave room
     */
    fun leave() {
        scope.cancel()
        messageChannel.close()
    }
}