import 'package:flutter/material.dart';
import 'package:local_vyapari_user/core/theme/app_theme.dart';

class GlobalErrorScreen extends StatefulWidget {
  final FlutterErrorDetails details;

  const GlobalErrorScreen({
    super.key,
    required this.details,
  });

  @override
  State<GlobalErrorScreen> createState() => _GlobalErrorScreenState();
}

class _GlobalErrorScreenState extends State<GlobalErrorScreen> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: Scaffold(
        backgroundColor: Colors.grey[50],
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: AppTheme.errorColor,
                      size: 64,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'An Unexpected Error Occurred',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We\'ve logged this error and are working on fixing it. You can attempt to reload the app or go back.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          // Simple solution to reload is to force the app to recreate the root layout
                          // by returning to the landing screen or using native reloads.
                          // Here we fallback to navigating back to home.
                          try {
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          } catch (_) {}
                        },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Return to Home'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _showDetails = !_showDetails;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      _showDetails ? 'Hide Technical Details' : 'Show Technical Details',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                  if (_showDetails) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SelectableText(
                        '${widget.details.exception}\n\n'
                        'Stacktrace:\n'
                        '${widget.details.stack}',
                        style: const TextStyle(
                          color: Colors.lightGreenAccent,
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
