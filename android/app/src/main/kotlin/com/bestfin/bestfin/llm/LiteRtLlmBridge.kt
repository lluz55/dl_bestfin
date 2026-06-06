package com.bestfin.bestfin.llm

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.Contents
import com.google.ai.edge.litertlm.Conversation
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import com.google.ai.edge.litertlm.LogSeverity
import com.google.ai.edge.litertlm.SamplerConfig
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.concurrent.atomic.AtomicBoolean

class LiteRtLlmBridge(private val context: Context) :
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val isBusy = AtomicBoolean(false)

    private var eventSink: EventChannel.EventSink? = null
    private var engine: Engine? = null
    private var conversation: Conversation? = null
    private var activeJob: Job? = null
    private var systemPrompt: String = ""
    private var temperature: Double = 0.55
    private var topP: Double = 0.90
    private var activeBackend: String = "cpu"

    init {
        Engine.setNativeMinLogSeverity(LogSeverity.ERROR)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "loadModel" -> loadModel(call, result)
            "sendMessage" -> sendMessage(call, result)
            "generateOnce" -> generateOnce(call, result)
            "cancel" -> cancel(call, result)
            "clearHistory" -> clearHistory(call, result)
            "dispose" -> dispose(result)
            "backendInfo" -> result.success(mapOf("runtime" to "litert-lm", "backend" to activeBackend))
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun close() {
        scope.launch {
            closeUnlocked()
            scope.cancel()
        }
    }

    private fun loadModel(call: MethodCall, result: MethodChannel.Result) {
        val modelPath = call.argument<String>("modelPath")
        if (modelPath.isNullOrBlank()) {
            result.error("INVALID_ARGUMENTS", "modelPath is required", null)
            return
        }

        val prompt = call.argument<String>("systemPrompt") ?: ""
        val temp = (call.argument<Any>("temperature") as? Number)?.toDouble() ?: 0.55
        val p = (call.argument<Any>("topP") as? Number)?.toDouble() ?: 0.90
        val useGpu = call.argument<Boolean>("useGpu") ?: false

        scope.launch {
            try {
                closeUnlocked()
                systemPrompt = prompt
                temperature = temp
                topP = p

                val loadedEngine = if (useGpu) tryLoadWithGpu(modelPath) else loadWithCpu(modelPath)
                engine = loadedEngine
                conversation = createConversation(temperature, topP)

                withContext(Dispatchers.Main) {
                    result.success(true)
                }
            } catch (e: Throwable) {
                closeUnlocked()
                withContext(Dispatchers.Main) {
                    result.error("LOAD_FAILED", e.message, null)
                }
            }
        }
    }

    private fun sendMessage(call: MethodCall, result: MethodChannel.Result) {
        val prompt = call.argument<String>("prompt")
        val requestId = call.argument<String>("requestId") ?: ""
        if (prompt.isNullOrBlank() || requestId.isBlank()) {
            result.error("INVALID_ARGUMENTS", "prompt and requestId are required", null)
            return
        }
        val activeConversation = conversation
        if (activeConversation == null) {
            result.error("NOT_LOADED", "LiteRT-LM engine is not loaded", null)
            return
        }
        if (!isBusy.compareAndSet(false, true)) {
            result.error("BUSY", "LiteRT-LM is already generating", null)
            return
        }

        activeJob = scope.launch {
            val startedAt = System.currentTimeMillis()
            var tokens = 0
            try {
                activeConversation
                    .sendMessageAsync(prompt)
                    .catch { throwable ->
                        emitEvent(
                            mapOf(
                                "requestId" to requestId,
                                "type" to "error",
                                "message" to (throwable.message ?: throwable.toString()),
                            ),
                        )
                    }
                    .collect { message ->
                        val text = message.toString()
                        if (text.isNotEmpty()) {
                            tokens += 1
                            emitEvent(mapOf("requestId" to requestId, "type" to "token", "text" to text))
                        }
                    }
                emitEvent(
                    mapOf(
                        "requestId" to requestId,
                        "type" to "metrics",
                        "tokens" to tokens,
                        "elapsedMs" to (System.currentTimeMillis() - startedAt),
                    ),
                )
                emitEvent(mapOf("requestId" to requestId, "type" to "done"))
            } catch (e: Throwable) {
                emitEvent(
                    mapOf(
                        "requestId" to requestId,
                        "type" to "error",
                        "message" to (e.message ?: e.toString()),
                    ),
                )
            } finally {
                activeJob = null
                isBusy.set(false)
            }
        }

        result.success(true)
    }

    private fun generateOnce(call: MethodCall, result: MethodChannel.Result) {
        val prompt = call.argument<String>("prompt")
        if (prompt.isNullOrBlank()) {
            result.error("INVALID_ARGUMENTS", "prompt is required", null)
            return
        }
        val temp = (call.argument<Any>("temperature") as? Number)?.toDouble() ?: 0.30
        val p = (call.argument<Any>("topP") as? Number)?.toDouble() ?: topP
        val activeEngine = engine
        if (activeEngine == null) {
            result.error("NOT_LOADED", "LiteRT-LM engine is not loaded", null)
            return
        }

        scope.launch {
            // LiteRT supports only one active session at a time. Close the main
            // conversation before creating the one-shot, then restore it after.
            conversation?.close()
            conversation = null

            try {
                val response = activeEngine.createConversation(
                    conversationConfig(temp, p, systemPrompt),
                ).use { oneShot ->
                    oneShot.sendMessage(prompt).toString()
                }
                conversation = createConversation(temperature, topP)
                withContext(Dispatchers.Main) {
                    result.success(response.trim())
                }
            } catch (e: Throwable) {
                // Restore conversation so the engine remains usable.
                if (conversation == null) {
                    try { conversation = createConversation(temperature, topP) } catch (_: Throwable) {}
                }
                withContext(Dispatchers.Main) {
                    result.error("GENERATE_FAILED", e.message, null)
                }
            }
        }
    }

    private fun cancel(call: MethodCall, result: MethodChannel.Result) {
        val requestId = call.argument<String>("requestId") ?: ""
        activeJob?.cancel()
        activeJob = null
        isBusy.set(false)
        if (requestId.isNotBlank()) {
            emitEvent(mapOf("requestId" to requestId, "type" to "done"))
        }
        result.success(true)
    }

    private fun clearHistory(call: MethodCall, result: MethodChannel.Result) {
        systemPrompt = call.argument<String>("systemPrompt") ?: systemPrompt
        scope.launch {
            try {
                conversation?.close()
                conversation = createConversation(temperature, topP)
                withContext(Dispatchers.Main) {
                    result.success(true)
                }
            } catch (e: Throwable) {
                withContext(Dispatchers.Main) {
                    result.error("CLEAR_FAILED", e.message, null)
                }
            }
        }
    }

    private fun dispose(result: MethodChannel.Result) {
        scope.launch {
            closeUnlocked()
            withContext(Dispatchers.Main) {
                result.success(true)
            }
        }
    }

    private fun tryLoadWithGpu(modelPath: String): Engine {
        // WARNING: Backend.GPU() triggers libLiteRtClGlAccelerator.so which crashes
        // with a native SIGSEGV (null function-pointer dereference). Native signals
        // cannot be caught by Kotlin try/catch — the process dies.
        // Keep preferGpu = false in AiModelType until the upstream bug is resolved.
        android.util.Log.w("LiteRtLlmBridge", "GPU backend requested but disabled due to upstream SIGSEGV — using CPU")
        return loadWithCpu(modelPath)
    }

    private fun loadWithCpu(modelPath: String): Engine {
        val engine = Engine(EngineConfig(modelPath = modelPath, backend = Backend.CPU(), cacheDir = context.cacheDir.path))
        engine.initialize()
        activeBackend = "cpu"
        return engine
    }

    private fun createConversation(temp: Double, p: Double): Conversation {
        val activeEngine = engine ?: throw IllegalStateException("Engine is not loaded")
        return activeEngine.createConversation(conversationConfig(temp, p, systemPrompt))
    }

    private fun conversationConfig(temp: Double, p: Double, prompt: String): ConversationConfig {
        val sampler = SamplerConfig(topK = 40, topP = p, temperature = temp)
        return if (prompt.isBlank()) {
            ConversationConfig(samplerConfig = sampler)
        } else {
            ConversationConfig(
                systemInstruction = Contents.of(prompt),
                samplerConfig = sampler,
            )
        }
    }

    private fun closeUnlocked() {
        activeJob?.cancel()
        activeJob = null
        isBusy.set(false)
        conversation?.close()
        conversation = null
        engine?.close()
        engine = null
    }

    private fun emitEvent(event: Map<String, Any>) {
        mainHandler.post {
            eventSink?.success(event)
        }
    }
}
