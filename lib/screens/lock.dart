import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../store.dart';
import '../theme.dart';

final _auth = LocalAuthentication();

Future<bool> canUseDeviceLock() async {
  try {
    return await _auth.isDeviceSupported();
  } catch (_) {
    return false;
  }
}

Future<bool> authenticate(String reason) async {
  try {
    return await _auth.authenticate(localizedReason: reason, persistAcrossBackgrounding: true);
  } catch (_) {
    return false;
  }
}

/// Covers [child] with a lock screen at launch and after 30s in the background.
class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  static const _grace = Duration(seconds: 30);

  late bool _locked;
  bool _authing = false;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locked = context.read<AppStore>().settings.lockEnabled;
    if (_locked) WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_authing) return;
    final store = context.read<AppStore>();
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final away = _pausedAt == null ? Duration.zero : DateTime.now().difference(_pausedAt!);
      _pausedAt = null;
      store.processRecurring();
      if (store.settings.lockEnabled && away > _grace && !_locked) {
        setState(() => _locked = true);
        _unlock();
      }
    }
  }

  Future<void> _unlock() async {
    if (_authing) return;
    _authing = true;
    final ok = await authenticate('Unlock Xpense');
    _authing = false;
    if (ok && mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        IgnorePointer(
          ignoring: !_locked,
          child: AnimatedOpacity(
            opacity: _locked ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            child: _LockScreen(onUnlock: _unlock),
          ),
        ),
      ],
    );
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({required this.onUnlock});

  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.cs.surface,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [context.cs.primary, context.cs.tertiary]),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Icon(Icons.lock_rounded, color: context.cs.onPrimary, size: 38),
              ),
              const SizedBox(height: 24),
              Text('Xpense is locked', style: context.tt.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Authenticate to view your finances',
                style: context.tt.bodyMedium?.copyWith(color: context.cs.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: onUnlock,
                icon: const Icon(Icons.fingerprint_rounded),
                label: const Text('Unlock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
