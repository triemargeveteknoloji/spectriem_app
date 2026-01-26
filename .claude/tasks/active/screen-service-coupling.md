# screen-service-coupling

**Created:** 2026-01-27
**Status:** 🆕 Created

---

Add ViewModel/Controller layer to separate business logic from UI screens.

**Context:** Architect review identified screens have mixed concerns:
- UI rendering (appropriate)
- Business logic (should be in ViewModel)
- State management (should be in provider/ViewModel)
- Direct service interactions (should be through repository)

Currently screens like SensorCommunicationScreen contain business logic:
```dart
Future<void> _loadConfigurations() async {
  try {
    final configs = await widget.bleService.getScanConfigurations();
    // ... setState logic
  } catch (e) { ... }
}
```

**Goals:**
- Create lib/viewmodels/ directory
- Implement ViewModels using ChangeNotifier (or Riverpod Notifiers)
- Extract business logic from screens to ViewModels
- Screens should only handle UI rendering and user interactions
- ViewModels handle business logic and state

**Benefits:**
- Better testability (ViewModels can be unit tested independently)
- Reusable business logic
- Cleaner screens focused only on UI
- Easier to maintain and extend

**Note:** This should be done AFTER riverpod task is complete, as ViewModels will use Riverpod providers.

## Tasks
- [ ] Create lib/viewmodels/ directory
- [ ] Create BluetoothConnectionViewModel
- [ ] Create SensorCommunicationViewModel
- [ ] Extract business logic from BluetoothConnectionScreen to ViewModel
- [ ] Extract business logic from SensorCommunicationScreen to ViewModel
- [ ] Update screens to use ViewModels
- [ ] Add ViewModel unit tests
- [ ] Update integration tests

## Sessions
(none yet)
