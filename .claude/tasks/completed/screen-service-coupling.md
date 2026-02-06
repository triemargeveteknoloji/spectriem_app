# screen-service-coupling

**Created:** 2026-01-27
**Status:** ✅ Completed

---

**Problem:**
Architect review identified screens have mixed concerns:
- UI rendering (appropriate)
- Business logic (should be in ViewModel)
- State management (should be in provider/ViewModel)
- Direct service interactions (should be through repository)

**Resolution:**
This task was implicitly completed by the `get-rid-of-setstate` migration (2026-01-30).

The modern Riverpod architecture uses **Notifier = ViewModel** pattern:

| Original Task Goal | Implementation |
|-------------------|----------------|
| lib/viewmodels/ directory | lib/providers/ (Notifiers serve as ViewModels) |
| BluetoothConnectionViewModel | `BluetoothConnectionNotifier` with `@riverpod` |
| SensorCommunicationViewModel | `SensorCommunicationNotifier` + `CommandExecutionNotifier` |
| Extract business logic | ✅ All business logic moved from screens to Notifiers |
| ViewModel unit tests | ✅ 12+ tests for BluetoothConnectionNotifier, tests for SensorCommunication |

**Architecture Achieved (MVVM):**

```
View Layer (Screens - Pure UI, ConsumerWidget)
    ↓ ref.watch / ref.read
ViewModel Layer (Notifiers - Business Logic)
    ↓ ref.read
Model/Service Layer (nirScanService, logService)
```

**Evidence:**
- 28 setState → 0 setState
- Screens are now pure UI (ConsumerWidget)
- All state management in Notifiers with @freezed immutable state
- Code generation: @riverpod + @freezed

## Tasks
- [x] Create lib/viewmodels/ directory → Used lib/providers/ with Notifiers instead
- [x] Create BluetoothConnectionViewModel → BluetoothConnectionNotifier
- [x] Create SensorCommunicationViewModel → SensorCommunicationNotifier + CommandExecutionNotifier
- [x] Extract business logic from BluetoothConnectionScreen to ViewModel → Done
- [x] Extract business logic from SensorCommunicationScreen to ViewModel → Done
- [x] Update screens to use ViewModels → Screens use ref.watch()
- [x] Add ViewModel unit tests → Notifier tests with fakeAsync
- [x] Update integration tests → Provider overrides in tests

## Sessions
**S1** (2026-02-02): Marked complete. Task goals achieved via `get-rid-of-setstate` migration which implemented Notifier = ViewModel pattern with modern Riverpod (@riverpod + @freezed).
