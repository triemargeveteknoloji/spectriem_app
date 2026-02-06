import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../utils/hex_format.dart';

class HexDumpWidget extends StatefulWidget {
  final Uint8List data;

  const HexDumpWidget({
    super.key,
    required this.data,
  });

  @override
  State<HexDumpWidget> createState() => _HexDumpWidgetState();
}

class _HexDumpWidgetState extends State<HexDumpWidget> {
  static const int _defaultMaxBytes = 64;
  bool _expanded = false;

  bool get _isTruncated => widget.data.length > _defaultMaxBytes;

  String get _hexDump {
    if (widget.data.isEmpty) return '';
    if (_expanded || !_isTruncated) {
      return HexFormat.toHexDump(widget.data);
    }
    return HexFormat.toHexDump(widget.data, maxBytes: _defaultMaxBytes);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return const Center(
        child: Text(
          'No data',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _hexDump,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
          if (_isTruncated) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded
                    ? 'Show less'
                    : 'Show all (${widget.data.length} bytes)',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
