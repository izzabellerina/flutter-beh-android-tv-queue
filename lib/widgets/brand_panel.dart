import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_android_tv_queue/helper/format_date.dart';
import 'package:flutter_android_tv_queue/theme/app_theme.dart';

/// แผงซ้ายของหน้า login — โลโก้, ชื่อระบบ, นาฬิกา
class BrandPanel extends StatelessWidget {
  const BrandPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = TvColors.of(context);
    final onPanel = colors.onBrandPanel;

    return Container(
      decoration: BoxDecoration(
        color: colors.brandPanel,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.fromLTRB(40, 36, 40, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Image.asset('assets/logo/logo.png', height: 56),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BEH',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: onPanel,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      'Bangkok Eye Hospital',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: onPanel.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            'ระบบเรียกคิว',
            style: theme.textTheme.headlineMedium?.copyWith(color: onPanel),
          ),
          Text(
            'จอแสดงคิวห้องตรวจ',
            style: theme.textTheme.titleMedium?.copyWith(
              color: onPanel.withValues(alpha: 0.75),
              fontWeight: FontWeight.w400,
            ),
          ),
          const Spacer(),
          _Clock(color: onPanel),
        ],
      ),
    );
  }
}

class _Clock extends StatefulWidget {
  final Color color;

  const _Clock({required this.color});

  @override
  State<_Clock> createState() => _ClockState();
}

class _ClockState extends State<_Clock> {
  late DateTime _now = DateTime.now();
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _now = DateTime.now()),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          FormatDate.time(_now),
          style: theme.textTheme.displaySmall?.copyWith(
            color: widget.color,
            height: 1.1,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          FormatDate.thaiFullDate(_now),
          style: theme.textTheme.titleMedium?.copyWith(
            color: widget.color.withValues(alpha: 0.75),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
