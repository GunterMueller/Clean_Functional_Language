definition module System._TTS

/**
 * This module contains the platform-specific implementation for System.TTS.
 * Use the functions in System.TTS for a platform-independent interface.
 */

/**
 * A voice for the text-to-speech function `ttsWithVoice`.
 * This type contains different constructors on each platform.
 */
:: Voice = DefaultVoice

//* Platform-specific text-to-speech implementation for System.TTS.
_tts :: !(?Voice) !String !*World -> *World
