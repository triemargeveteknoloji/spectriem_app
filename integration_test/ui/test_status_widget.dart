import 'package:flutter/material.dart';
import 'test_status_state.dart';

class TestStatusWidget extends StatelessWidget {
  final TestStatusState state;

  const TestStatusWidget({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
      ),
      home: Scaffold(
        body: SafeArea(
          child: ListenableBuilder(
            listenable: state,
            builder: (context, _) => _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildProgress(),
          const SizedBox(height: 24),
          Expanded(child: _buildStepsList()),
          if (state.isComplete) _buildSummary(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.science, color: Colors.cyanAccent, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                state.testTitle,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Step ${state.currentStepIndex + 1} of ${state.totalCount}',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[400],
          ),
        ),
      ],
    );
  }

  Widget _buildProgress() {
    final progress = state.totalCount > 0
        ? state.completedCount / state.totalCount
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 12,
            backgroundColor: Colors.grey[800],
            valueColor: AlwaysStoppedAnimation<Color>(
              state.steps.any((s) => s.status == StepStatus.failed)
                  ? Colors.redAccent
                  : Colors.greenAccent,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${state.completedCount}/${state.totalCount} completed',
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildStepsList() {
    return ListView.builder(
      itemCount: state.steps.length,
      itemBuilder: (context, index) {
        final step = state.steps[index];
        return _buildStepItem(step);
      },
    );
  }

  Widget _buildStepItem(TestStep step) {
    final isCurrentStep = step.index == state.currentStepIndex;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentStep
            ? Colors.blueGrey[800]
            : Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: isCurrentStep
            ? Border.all(color: Colors.cyanAccent, width: 2)
            : null,
      ),
      child: Row(
        children: [
          _buildStepIcon(step.status, isCurrentStep),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isCurrentStep ? FontWeight.bold : FontWeight.normal,
                    color: Colors.white,
                  ),
                ),
                if (step.message != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    step.message!,
                    style: TextStyle(
                      fontSize: 12,
                      color: step.status == StepStatus.failed
                          ? Colors.redAccent
                          : Colors.grey[400],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (step.duration != null)
            Text(
              '${step.duration!.inMilliseconds}ms',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepIcon(StepStatus status, bool isCurrentStep) {
    switch (status) {
      case StepStatus.pending:
        return Icon(
          Icons.circle_outlined,
          color: Colors.grey[600],
          size: 24,
        );
      case StepStatus.running:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
          ),
        );
      case StepStatus.passed:
        return const Icon(
          Icons.check_circle,
          color: Colors.greenAccent,
          size: 24,
        );
      case StepStatus.failed:
        return const Icon(
          Icons.error,
          color: Colors.redAccent,
          size: 24,
        );
    }
  }

  Widget _buildSummary() {
    final passedCount = state.steps.where((s) => s.status == StepStatus.passed).length;
    final failedCount = state.steps.where((s) => s.status == StepStatus.failed).length;
    final allPassed = failedCount == 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: allPassed ? Colors.green[900] : Colors.red[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            allPassed ? Icons.celebration : Icons.warning,
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(width: 12),
          Text(
            allPassed
                ? 'All $passedCount tests passed!'
                : '$failedCount test(s) failed',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
