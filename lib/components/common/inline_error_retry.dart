import 'package:flutter/material.dart';

/// Centered load failure with a retry action.
class InlineErrorRetry extends StatelessWidget {
  const InlineErrorRetry({
    super.key,
    required this.message,
    required this.onRetry,
    this.retryLabel = 'Tekrar dene',
  });

  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: Text(retryLabel)),
          ],
        ),
      ),
    );
  }
}
