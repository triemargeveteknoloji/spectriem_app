# Plan: Platform-Based BLE Service Selection

## Goal
- Android: Use `RealNirScanService` for actual BLE communication
- Linux: Use `MockNirScanService` for development/testing

## Approach

### Option A: Simple Platform Check (Recommended)
Use `dart:io Platform` directly in `main.dart` to conditionally create the service.

```dart
import 'dart:io' show Platform;

NirScanService createNirScanService() {
  if (Platform.isAndroid || Platform.isIOS) {
    return RealNirScanService();
  }
  return MockNirScanService();
}
```

**Pros:** Simple, no new abstractions
**Cons:** Platform check in main.dart

### Option B: Factory Class
Create a `NirScanServiceFactory` class.

**Pros:** More testable, encapsulated
**Cons:** Over-engineering for this simple case

### Decision: Option A
Keep it simple. Platform detection is a one-time setup concern.

## Implementation Steps

### Step 1: Add Platform Detection
- Import `dart:io` in `main.dart`
- Create factory function `createNirScanService()`

### Step 2: Update Service Usage
- Change `_bleService` type from `MockNirScanService` to `NirScanService`
- Use factory function in `initState()`

### Step 3: Update Imports
- Keep both service imports
- Import real service

## TDD Approach

### Tests to Write First
1. Platform-based factory function test (unit test)
   - Returns `RealNirScanService` when platform is Android/iOS
   - Returns `MockNirScanService` when platform is Linux/macOS/Windows

### Challenge
`dart:io Platform` cannot be easily mocked. Options:
- Use `defaultTargetPlatform` from Flutter for tests
- Accept that this is a thin integration layer that's tested manually

### Decision
Skip unit test for factory - it's trivial conditional logic. Verify manually on both platforms.

## Files to Modify
- `lib/main.dart` - Add platform detection, change service type

## Risk Assessment
- **Low risk**: Simple conditional, doesn't change any business logic
- **Fallback**: If Android BLE fails, user can see error; app doesn't crash
