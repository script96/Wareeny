# Document QA Mode

This document outlines the architecture, flow, and limitations of the Document QA Mode in Warene.

## User Flow
1. **Entry**: The user long-presses to open the action menu and selects `اسأل عن نص` (Ask about text).
2. **Scan**: The app switches to `documentQa` mode, waits 2 seconds for the user to point the camera, and takes a high-res snapshot.
3. **Processing**: The OCR service extracts text. If it passes quality heuristics (length, non-empty), it is stored in `VisionService` memory.
4. **Interaction**:
   - The user double-taps the screen to ask a question.
   - The `VoiceInputService` listens for up to 7 seconds.
   - The voice prompt and the document text (up to 4,000 characters) are sent to Groq (`llama-3.3-70b-versatile`).
   - The answer is spoken aloud.
5. **Exit/Rescan**: The user long-presses to open the menu again, where they can choose to rescan (`اسأل عن نص جديد`) or exit (`إنهاء سؤال النص`).

## Architecture & Dependencies
- **State Management**: `VisionService` holds `_qaDocumentText`, `_qaHistory` (latest 5 turns), and flags for listening/answering.
- **Voice Input**: Powered by `speech_to_text: ^7.3.0`. Automatically maps the chosen OCR language to `ar_EG` or `en_US`. Errors like timeout or lack of permissions are translated to Arabic TTS.
- **LLM**: Groq API. A strict system prompt forces the model to answer exclusively from the text and avoid hallucination or formatting.
- **Lifecycle**: If the app is backgrounded, QA memory is retained, but active voice listening is aborted.

## Limitations
- **Character Limit**: Groq's input token limits and speed constraints require capping the context to 4,000 characters. If exceeded, the user is warned that only the first part of the document is being queried.
- **Memory Duration**: Document text is completely cleared from memory the moment the user exits the mode or switches to another detection mode.
- **Privacy**: Text is sent to the Groq API. Currently, there is no explicit user warning or opt-in step beyond the menu selection.

## Test Checklist (Manual Device Verification)
- [ ] Permissions denied scenario (Mic/Camera).
- [ ] Successful Arabic text scan + Arabic question.
- [ ] Successful English text scan + English question.
- [ ] Empty or blurry document capture.
- [ ] Very long document (> 4,000 characters).
- [ ] Timeout / No speech during voice input.
- [ ] Network failure during Groq response.
- [ ] Exiting QA mode and verifying memory is cleared.
- [ ] App paused and resumed during QA mode.
