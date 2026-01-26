import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/log_provider.dart';
import '../services/logging/log_service.dart';

class LogViewerWidget extends ConsumerStatefulWidget {
  final LogLevel? filterLevel;
  final bool expanded;

  const LogViewerWidget({
    super.key,
    this.filterLevel,
    this.expanded = true,
  });

  @override
  ConsumerState<LogViewerWidget> createState() => _LogViewerWidgetState();
}

class _LogViewerWidgetState extends ConsumerState<LogViewerWidget> {
  final ScrollController _scrollController = ScrollController();
  final List<LogEntry> _entries = [];
  StreamSubscription<LogEntry>? _subscription;

  @override
  void initState() {
    super.initState();
    final logService = ref.read(logServiceProvider);
    _entries.addAll(logService.history);
    _subscription = logService.logStream.listen(_onLogEntry);
  }

  void _onLogEntry(LogEntry entry) {
    if (mounted) {
      setState(() {
        _entries.add(entry);
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 50),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  List<LogEntry> get _filteredEntries {
    if (widget.filterLevel == null) return _entries;
    return _entries
        .where((e) => e.level.index >= widget.filterLevel!.index)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.expanded) {
      return const SizedBox.shrink();
    }

    final entries = _filteredEntries;

    if (entries.isEmpty) {
      return const Center(
        child: Text(
          'No logs',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _LogEntryTile(entry: entry);
      },
    );
  }
}

class _LogEntryTile extends StatelessWidget {
  final LogEntry entry;

  const _LogEntryTile({required this.entry});

  Color _levelColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Colors.grey;
      case LogLevel.info:
        return Colors.blue;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final levelColor = _levelColor(entry.level);
    final time = _formatTime(entry.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            time,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 8),
          Text(
            entry.level.name.toUpperCase(),
            style: TextStyle(
              color: levelColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 8),
          if (entry.tag != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                entry.tag!,
                style: const TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              entry.message,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
