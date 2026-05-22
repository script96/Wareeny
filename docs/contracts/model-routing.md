# Model Routing Contract

## Routing States

- `cloud`
- `local`
- `offline-no-llm`

## User Preferences

- `auto`
- `prefer-cloud`
- `prefer-local`

Recommended default: `auto`

## Inputs

The mobile router should decide using:

- `userPreference`
- `internetAvailable`
- `localModelInstalled`
- `localModelUsable`
- `taskType`

## Task Types

- `scene_qa`
- `document_qa`
- `ocr_summary`
- `caption`
- `chat_followup`

## Decision Table

| Preference | Internet | Local installed | Result |
|---|---:|---:|---|
| `prefer-cloud` | yes | any | `cloud` |
| `prefer-cloud` | no | yes | `local` |
| `prefer-cloud` | no | no | `offline-no-llm` |
| `prefer-local` | any | yes | `local` |
| `prefer-local` | yes | no | `cloud` |
| `prefer-local` | no | no | `offline-no-llm` |
| `auto` | yes | any | `cloud` |
| `auto` | no | yes | `local` |
| `auto` | no | no | `offline-no-llm` |

## Performance Constraints

- do not run local LLM while live obstacle detection is in the hot path
- if danger mode becomes active, cancel or pause ongoing LLM work
- cache local model availability in persistent storage
