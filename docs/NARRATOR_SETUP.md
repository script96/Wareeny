# Narrator Setup

Warene now prefers higher-quality Arabic voices when they are available on the device.
If the phone only has a basic Arabic voice installed, the app may still sound robotic.

## Android

Recommended setup:

1. Install or update **Speech Recognition & Synthesis by Google**:
   [Google Play](https://play.google.com/store/apps/details?id=com.google.android.tts)
2. On the phone, open:
   `Settings > Accessibility > Text-to-speech output`
3. Set **Preferred engine** to **Speech Recognition & Synthesis by Google**.
4. Open the engine settings and download Arabic voice data.
5. Choose the best available Arabic voice, preferably a female or higher-quality network voice if the device offers one.

Official references:

- Google Play listing for the engine:
  [Speech Recognition & Synthesis](https://play.google.com/store/apps/details?id=com.google.android.tts)
- Google accessibility help for choosing the preferred TTS engine:
  [Text-to-speech output](https://support.google.com/accessibility/android/answer/6006983?hl=en)
- Android API reference showing engines and voices are device-installed:
  [TextToSpeech API](https://developer.android.com/reference/android/speech/tts/TextToSpeech)

## iPhone

Recommended setup:

1. Open `Settings > Siri` or `Settings > Apple Intelligence & Siri`.
2. Set the language to Arabic if needed.
3. Open **Siri Voice** and choose the best Arabic voice available.
4. If the phone offers a higher-quality or downloadable voice, download it.
5. In `Settings > Accessibility > Siri`, reduce or increase speaking rate to your preference.

Official references:

- Apple support for changing Siri language and voice:
  [Change Siri voice or language](https://support.apple.com/en-ie/120499)
- Apple support for adjusting speaking speed:
  [Change Siri volume and speaking rate](https://support.apple.com/en-us/HT209573)
- Apple support showing downloadable voices can be required:
  [Adjust voice and speed for VoiceOver and Speak Screen](https://support.apple.com/en-ie/111798)

## Cloud Upgrade Option

If you want a much better fixed Egyptian female narrator that does not depend on the phone's built-in voices,
the strongest cloud option we found is **Azure AI Speech** with:

- `ar-EG-SalmaNeural` (Female)

Official reference:

- [Azure Speech language and voice support](https://learn.microsoft.com/azure/ai-services/speech-service/language-support?tabs=stt)

This would require adding Azure credentials and a cloud TTS path in the app.
