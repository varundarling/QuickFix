// lib/presentation/widgets/base_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:quickfix/core/services/ad_service.dart';

class BaseScreen extends StatefulWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final VoidCallback? onScreenEnter;

  const BaseScreen({
    super.key,
    this.appBar,
    required this.body,
    this.onScreenEnter,
  });

  @override
  State<BaseScreen> createState() => _BaseScreenState();
}

class _BaseScreenState extends State<BaseScreen> {
  Timer? _interstitialTimer;

  @override
  void initState() {
    super.initState();
    // Preload banner once
    widget.onScreenEnter?.call();
    _interstitialTimer = Timer(const Duration(minutes: 7), () {
      AdService.instance.showInterstitial();
    });
  }

  @override
  void dispose() {
    _interstitialTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.appBar,
      body: SafeArea(
        child: Column(children: [Expanded(child: widget.body)]),
      ),
    );
  }
}
