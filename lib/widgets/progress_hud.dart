import 'package:flutter/material.dart';

class ProgressHUD extends StatefulWidget {
  final Widget child;

  const ProgressHUD({super.key, required this.child});

  static ProgressHUDState? of(BuildContext context) {
    return context.findAncestorStateOfType<ProgressHUDState>();
  }

  @override
  State<ProgressHUD> createState() => ProgressHUDState();
}

class ProgressHUDState extends State<ProgressHUD> {
  bool _visible = false;
  double _progress = 0.0;
  String _message = "";

  void setValue(double value) {
    setState(() {
      _progress = value;
    });
  }

  void setText(String message) {
    setState(() {
      _message = message;
    });
  }

  void show() {
    setState(() {
      _visible = true;
    });
  }

  void dismiss() {
    setState(() {
      _visible = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_visible)
          Container(
            color: Colors.black54,
            child: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LinearProgressIndicator(value: _progress),
                      const SizedBox(height: 16),
                      Text(_message),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
