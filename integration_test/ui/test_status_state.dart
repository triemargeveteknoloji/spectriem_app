import 'package:flutter/foundation.dart';

enum StepStatus { pending, running, passed, failed }

class TestStep {
  final String name;
  final int index;
  final StepStatus status;
  final String? message;
  final Duration? duration;

  const TestStep({
    required this.name,
    required this.index,
    this.status = StepStatus.pending,
    this.message,
    this.duration,
  });

  TestStep copyWith({
    StepStatus? status,
    String? message,
    Duration? duration,
  }) {
    return TestStep(
      name: name,
      index: index,
      status: status ?? this.status,
      message: message ?? this.message,
      duration: duration ?? this.duration,
    );
  }
}

class TestStatusState extends ChangeNotifier {
  final List<TestStep> _steps = [];
  int _currentStepIndex = -1;
  String _testTitle = 'Integration Test';
  bool _isComplete = false;

  List<TestStep> get steps => List.unmodifiable(_steps);
  int get currentStepIndex => _currentStepIndex;
  String get testTitle => _testTitle;
  bool get isComplete => _isComplete;

  TestStep? get currentStep =>
      _currentStepIndex >= 0 && _currentStepIndex < _steps.length
          ? _steps[_currentStepIndex]
          : null;

  int get completedCount => _steps.where((s) => s.status == StepStatus.passed).length;
  int get totalCount => _steps.length;

  void initialize(String title, List<String> stepNames) {
    _testTitle = title;
    _steps.clear();
    for (var i = 0; i < stepNames.length; i++) {
      _steps.add(TestStep(name: stepNames[i], index: i));
    }
    _currentStepIndex = -1;
    _isComplete = false;
    notifyListeners();
  }

  void startStep(int index) {
    if (index < _steps.length) {
      _currentStepIndex = index;
      _steps[index] = _steps[index].copyWith(status: StepStatus.running);
      notifyListeners();
    }
  }

  void passStep(int index, {Duration? duration, String? message}) {
    if (index < _steps.length) {
      _steps[index] = _steps[index].copyWith(
        status: StepStatus.passed,
        duration: duration,
        message: message,
      );
      notifyListeners();
    }
  }

  void failStep(int index, {String? message}) {
    if (index < _steps.length) {
      _steps[index] = _steps[index].copyWith(
        status: StepStatus.failed,
        message: message,
      );
      notifyListeners();
    }
  }

  void complete() {
    _isComplete = true;
    notifyListeners();
  }

  void reset() {
    _steps.clear();
    _currentStepIndex = -1;
    _isComplete = false;
    notifyListeners();
  }
}
