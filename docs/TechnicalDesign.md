# EarFuse Technical Design (MVP)

## 1. Architecture

Core split follows the PRD boundaries:

- `Capture`: pluggable audio capture backend interface (`AudioCaptureBackend`)
- `Meter`: frame-level feature extraction (`Peak/RMS` in dBFS)
- `Policy`: stateful threshold policy (`duration + hysteresis`)
- `Alerts`: reminder integration abstraction
- `Fuse`: emergency intervention logic (relative+absolute trigger)
- `Logging`: local event model and append-only store abstraction
- `Profiles`: `Production/Listening` policy presets
- `MenuBarUI`: always-on menu bar indicator and popover controls

## 2. Data flow

1. Capture backend emits float PCM frames (`[Float]`, timestamp).
2. Meter module computes `MeterSnapshot(peakDBFS, rmsDBFS)`.
3. Policy evaluates snapshot against active profile thresholds.
4. Fuse evaluates abnormal-spike condition and optionally triggers volume action.
5. Service publishes `MeterStatus` to UI and appends events to log store.

`AudioMonitorService` is the orchestrator and intentionally keeps module coupling directional.

## 3. Threading model

- Capture callback: background queue, no UI work.
- Meter + Policy + Fuse eval: same capture queue for deterministic ordering.
- UI updates: marshalled to main queue via `DispatchQueue.main.async`.

Planned optimization for backend A:

- Audio callback stays lock-free and writes compact analysis payload into ring buffer.
- UI reads latest sample every 100-200ms.

## 4. Policy and Fuse logic

### 4.1 Policy

- Instant classification by RMS threshold (`yellow/red`).
- Promotion to danger only after profile duration requirement.
- Return to safe only after recovery (hysteresis) duration.

### 4.2 Fuse

Trigger condition uses all three constraints:

- Absolute ceiling: `peak >= absolutePeakThreshold`
- Relative anomaly: `peak - rms >= crestThreshold`
- Minimum dwell: candidate holds for `minimumTriggerDuration`

When triggered:

- Query previous system volume
- Set new volume to `safeOutputVolume`
- Return result for UI/logging

MVP uses `StubVolumeController`; production build will replace with system API-backed implementation and capability checks.

## 5. Capture backend strategy

Backend A (primary target):

- Core Audio output monitoring path (system-version dependent)
- Best UX when available

Backend B (compatibility):

- virtual device route (e.g. BlackHole-like setup)
- app reads from chosen input stream

Implementation status:

- `MockCaptureBackend` is active for scaffold verification
- backend A/B are next milestones

## 6. Persistence model (planned)

- `DailySummary`: date, yellowSeconds, redSeconds, maxPeak, maxRMS, fuseCount
- `SafetyEvent`: start/end, maxPeak/maxRMS, classification, fuse action

MVP scaffold currently keeps append-only events in memory via `LogStore`.

## 7. UX states

- Menu bar icon color and symbol map to `safe/yellow/red`
- Popover shows live Peak/RMS + profile switch + last fuse action message
- Profile switch updates policy/fuse behavior immediately

## 8. Known gaps (intentionally deferred)

- Real system output capture backend
- Notification center integration
- Persistent JSON/SQLite storage and export
- Device-to-profile binding
- Fuse recovery interaction (restore old volume action)

## 9. Definition of done mapping (current)

Completed in scaffold:

- Modular architecture aligned with PRD
- Live meter UI path (with mock signal)
- Policy and fuse engines coded
- Unit tests for meter and policy

Not yet completed:

- End-to-end real audio capture
- production-grade system-volume intervention
- log persistence and weekly stats
