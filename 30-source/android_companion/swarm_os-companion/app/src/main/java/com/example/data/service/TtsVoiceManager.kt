package com.example.data.service

import android.content.Context
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.speech.tts.Voice
import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.util.Locale

enum class VoicePersona(val displayName: String, val role: String, val gender: String) {
    DR_I30LTZ("DR. I30LTZ", "Optimization · Eval · Security", "Male")
}

class TtsVoiceManager(context: Context) : TextToSpeech.OnInitListener {
    private var tts: TextToSpeech? = TextToSpeech(context.applicationContext, this)
    
    private val _isSpeaking = MutableStateFlow(false)
    val isSpeaking: StateFlow<Boolean> = _isSpeaking

    private val _isMuted = MutableStateFlow(false)
    val isMuted: StateFlow<Boolean> = _isMuted

    private val _isInitialized = MutableStateFlow(false)
    val isInitialized: StateFlow<Boolean> = _isInitialized

    private val _currentPersona = MutableStateFlow(VoicePersona.DR_I30LTZ)
    val currentPersona: StateFlow<VoicePersona> = _currentPersona

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            val result = tts?.setLanguage(Locale.US)
            if (result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED) {
                Log.e("TtsVoiceManager", "Language US is not supported or missing data")
            } else {
                applyPersonaVoice(_currentPersona.value)
                _isInitialized.value = true

                tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                    override fun onStart(utteranceId: String?) {
                        _isSpeaking.value = true
                    }

                    override fun onDone(utteranceId: String?) {
                        _isSpeaking.value = false
                    }

                    @Deprecated("Deprecated in Java")
                    override fun onError(utteranceId: String?) {
                        _isSpeaking.value = false
                    }
                })
            }
        } else {
            Log.e("TtsVoiceManager", "Initialization of TextToSpeech failed")
        }
    }

    fun setPersona(persona: VoicePersona) {
        _currentPersona.value = persona
        applyPersonaVoice(persona)
    }

    private fun applyPersonaVoice(persona: VoicePersona) {
        try {
            val availableVoices = tts?.voices ?: return

            // DR. I30LTZ: Optimization, Eval & Security — deep, measured, authoritative
            val maleVoice = availableVoices
                .filter { it.locale.language == "en" }
                .sortedWith(
                    compareByDescending<Voice> {
                        val n = it.name.lowercase()
                        n.contains("roger") || n.contains("male_3") || n.contains("male_2") || n.contains("male") || n.contains("guy") || n.contains("christopher") || n.contains("en-us-x-sfg#male") || n.contains("en-us-x-iob") || n.contains("en-gb-x-rde")
                    }
                    .thenByDescending { it.quality }
                    .thenByDescending { it.isNetworkConnectionRequired }
                )
                .firstOrNull()

            maleVoice?.let { tts?.setVoice(it) }
            tts?.setPitch(0.76f) // Deep, resonant, seasoned older male timbre
            tts?.setSpeechRate(0.88f) // Calm, measured, wise cadence
            Log.d("TtsVoiceManager", "Configured DR. I30LTZ (Optimization/Eval/Security Male): Pitch=0.76, Rate=0.88")
        } catch (e: Exception) {
            Log.e("TtsVoiceManager", "Error applying voice persona", e)
        }
    }

    fun speak(text: String, persona: VoicePersona? = null) {
        if (_isMuted.value || !_isInitialized.value) return
        stop()
        
        val activePersona = persona ?: _currentPersona.value
        applyPersonaVoice(activePersona)

        val isStonerMode = text.contains("420", ignoreCase = true) ||
                           text.contains("allright man", ignoreCase = true) ||
                           text.contains("weed", ignoreCase = true) ||
                           text.contains("stoner", ignoreCase = true) ||
                           text.contains("honeycomb, dude", ignoreCase = true)

        if (isStonerMode && activePersona == VoicePersona.DR_I30LTZ) {
            tts?.setPitch(0.62f) // Deep, relaxed, laid-back stoner pitch
            tts?.setSpeechRate(0.76f) // Slow, mellow, rhythmic stoner cadence
        }

        val cleanedText = text
            .replace(Regex("[*#_~`⚡👄👨‍🔬🌿💨🍇⛽🌲🍨]"), "") // Clean markdown and emojis for natural speech
            .trim()
            
        if (cleanedText.isBlank()) return
        
        tts?.speak(cleanedText, TextToSpeech.QUEUE_FLUSH, null, "DR_I30LTZ_SPEECH")
    }

    fun stop() {
        if (tts?.isSpeaking == true) {
            tts?.stop()
        }
        _isSpeaking.value = false
    }

    fun toggleMute() {
        _isMuted.value = !_isMuted.value
        if (_isMuted.value) {
            stop()
        }
    }

    fun shutdown() {
        tts?.stop()
        tts?.shutdown()
        tts = null
    }
}
