# Wareeny

Implementation foundation for the Wareeny runtime and model strategy.

This repository currently contains:

- product and architecture docs for the smoothness-first runtime
- a Flutter app shell in `Wareeny`
- backend API contracts for model routing, manifest delivery, and the existing in-hand server
- a runnable `FastAPI` skeleton for the planned cloud services
- a 31-day roadmap to help the team finish on time

## Repository Layout

- [Wareeny/README.md](/Users/mac/Documents/wareny/Wareeny/README.md)
- [Wareeny/docs/architecture/runtime-strategy.md](/Users/mac/Documents/wareny/Wareeny/docs/architecture/runtime-strategy.md)
- [Wareeny/docs/architecture/mobile-architecture.md](/Users/mac/Documents/wareny/Wareeny/docs/architecture/mobile-architecture.md)
- [Wareeny/docs/contracts/backend-api.md](/Users/mac/Documents/wareny/Wareeny/docs/contracts/backend-api.md)
- [Wareeny/docs/contracts/model-routing.md](/Users/mac/Documents/wareny/Wareeny/docs/contracts/model-routing.md)
- [Wareeny/docs/examples/model-manifest.example.json](/Users/mac/Documents/wareny/Wareeny/docs/examples/model-manifest.example.json)
- [Wareeny/docs/roadmap/31-day-roadmap.md](/Users/mac/Documents/wareny/Wareeny/docs/roadmap/31-day-roadmap.md)
- [RULES.md](/Users/mac/Documents/wareny/RULES.md)
- [backend/README.md](/Users/mac/Documents/wareny/backend/README.md)

## Current Scope

The workspace originally only contained the thesis and system diagram, so this implementation focuses on the highest-signal first step:

- define the runtime architecture clearly
- lock the mobile/cloud contracts
- provide a working backend scaffold the app team can integrate immediately

## Next Build Steps

1. Build the Flutter shell and native bridges against the contracts in `Wareeny/docs/contracts`.
2. Connect the existing Python in-hand detector to `POST /in-hand/detect`.
3. Replace the placeholder Gemma cloud provider in the backend with the production `Gemma 4 E4B` endpoint.
4. Add local model manager and router logic in the mobile app using the rules in `Wareeny/docs/architecture/runtime-strategy.md`.
