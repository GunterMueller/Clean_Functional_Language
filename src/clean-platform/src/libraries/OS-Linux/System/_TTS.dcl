definition module System._TTS

/**
 * This module contains the platform-specific implementation for System.TTS.
 * Use the functions in System.TTS for a platform-independent interface.
 */

/**
 * A voice for the text-to-speech function `ttsWithVoice`.
 * This type contains different constructors on each platform.
 */
:: Voice
	= Male1
	| Male2
	| Male3
	| Female1
	| Female2
	| Female3
	| ChildMale
	| ChildFemale

//* Platform-specific text-to-speech implementation for System.TTS.
_tts :: !(?Voice) !String !*World -> *World
