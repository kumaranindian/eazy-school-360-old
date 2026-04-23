import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/services/tenant_provisioning_service.dart';

/// Non-dismissible modal that consumes a [Stream] of [ProvisioningEvent]s
/// and renders each step's live status. Once the stream completes, a
/// "Continue" button appears and resolves the dialog.
///
/// Shown immediately after a successful school signup so the admin can see
/// that their tenant is being bootstrapped (seed docs, indexes, rules, …)
/// before being sent to the waiting-activation screen.
class ProvisioningProgressDialog extends StatefulWidget {
  final Stream<ProvisioningEvent> stream;
  final String schoolName;
  final VoidCallback onFinished;

  const ProvisioningProgressDialog({
    super.key,
    required this.stream,
    required this.schoolName,
    required this.onFinished,
  });

  /// Helper that blocks the UI, runs the provided stream, and only returns
  /// when the user taps Continue (or Retry, once implemented). Returns
  /// `true` if all steps succeeded (done/skipped), `false` if any failed.
  static Future<bool> show({
    required BuildContext context,
    required Stream<ProvisioningEvent> stream,
    required String schoolName,
  }) async {
    bool allOk = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ProvisioningProgressDialog(
        stream: stream.map((e) {
          if (e.status == ProvisioningStatus.failed) allOk = false;
          return e;
        }),
        schoolName: schoolName,
        onFinished: () => Navigator.of(ctx).pop(),
      ),
    );
    return allOk;
  }

  @override
  State<ProvisioningProgressDialog> createState() =>
      _ProvisioningProgressDialogState();
}

class _ProvisioningProgressDialogState
    extends State<ProvisioningProgressDialog> {
  // Dark theme tokens (match login/signup/dashboard).
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);
  static const Color _errorRed = Color(0xFFEF4444);
  static const Color _warnAmber = Color(0xFFFFB020);

  final Map<String, ProvisioningEvent> _events = {};
  final List<String> _order = [];
  StreamSubscription<ProvisioningEvent>? _sub;
  bool _finished = false;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _sub = widget.stream.listen(
      (e) {
        setState(() {
          if (!_events.containsKey(e.stepId)) _order.add(e.stepId);
          _events[e.stepId] = e;
          _total = e.total;
        });
      },
      onDone: () {
        if (mounted) setState(() => _finished = true);
      },
      onError: (_) {
        if (mounted) setState(() => _finished = true);
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  int get _doneCount => _events.values
      .where((e) =>
          e.status == ProvisioningStatus.done ||
          e.status == ProvisioningStatus.skipped)
      .length;

  int get _failedCount => _events.values
      .where((e) => e.status == ProvisioningStatus.failed)
      .length;

  double get _progress => _total == 0 ? 0 : _doneCount / _total;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _cardDark,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _borderColor),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildProgressBar(),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: _buildStepTiles(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _accentBlue.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.rocket_launch_rounded,
              color: _accentBlue, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Setting up your school',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.schoolName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _total == 0 ? null : _progress,
            minHeight: 6,
            backgroundColor: _bgDark,
            valueColor: AlwaysStoppedAnimation<Color>(
                _failedCount > 0 && _finished ? _errorRed : _accentBlue),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _total == 0
                  ? 'Preparing…'
                  : '$_doneCount of $_total steps complete',
              style:
                  const TextStyle(color: _textSecondary, fontSize: 11),
            ),
            if (_failedCount > 0)
              Text(
                '$_failedCount failed',
                style:
                    const TextStyle(color: _errorRed, fontSize: 11),
              ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildStepTiles() {
    if (_order.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(_accentBlue),
              ),
            ),
          ),
        ),
      ];
    }
    return _order.map((id) {
      final e = _events[id]!;
      return _stepTile(e);
    }).toList();
  }

  Widget _stepTile(ProvisioningEvent e) {
    final (icon, color, label) = switch (e.status) {
      ProvisioningStatus.running => (
        _spinnerIcon(),
        _accentBlue,
        'Running',
      ),
      ProvisioningStatus.done => (
        const Icon(Icons.check_circle_rounded,
            color: _accentBlue, size: 20),
        _accentBlue,
        'Done',
      ),
      ProvisioningStatus.skipped => (
        const Icon(Icons.fast_forward_rounded,
            color: _warnAmber, size: 20),
        _warnAmber,
        'Skipped',
      ),
      ProvisioningStatus.failed => (
        const Icon(Icons.error_rounded,
            color: _errorRed, size: 20),
        _errorRed,
        'Failed',
      ),
      ProvisioningStatus.pending => (
        const Icon(Icons.radio_button_unchecked_rounded,
            color: _textSecondary, size: 20),
        _textSecondary,
        'Pending',
      ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _bgDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 22, height: 22, child: Center(child: icon)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.title,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (e.message != null && e.message!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    e.message!,
                    style: TextStyle(
                        color: color, fontSize: 11, height: 1.3),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _spinnerIcon() => const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(_accentBlue),
        ),
      );

  Widget _buildFooter() {
    if (!_finished) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'Please wait while we configure your tenant…',
          textAlign: TextAlign.center,
          style: TextStyle(color: _textSecondary, fontSize: 12),
        ),
      );
    }
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: widget.onFinished,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: const Text(
          'Continue',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
