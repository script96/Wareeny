# Emergency Feature

## Run configuration

Provide Clerk to Flutter at build time:

```bash
flutter run \
  --dart-define=CLERK_PUBLISHABLE_KEY=pk_test_... \
  --dart-define=API_BASE_URL=http://<backend-host>:8000
```

Without a Clerk key, the app runs in local safety mode for development. The
trusted contact, SOS countdown, and foreground fall detector still work.

Configure the backend from `backend/.env.example`, then run:

```bash
cd backend
python3.11 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload
```

## Current safety behavior

- One trusted contact can be entered manually or selected with the native
  contact picker.
- Only the confirmed name, relationship, source, and E.164 number are stored.
- Manual SOS and probable falls use a 10-second accessible cancellation screen.
- Android requests call permission at escalation time and attempts a normal
  contact call, falling back to the dialer.
- iOS uses the system `tel:` flow and can require confirmation.
- Location sharing is opt-in and uses a two-second best-effort lookup that never
  delays calling.
- Foreground fall detection is opt-in and experimental.
- Clerk, MongoDB, network, and location are not required to start the call flow.

Continuous Android foreground-service monitoring and iOS background monitoring
remain disabled until physical-device accuracy and battery testing is complete.
