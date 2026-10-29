import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:strongbody_buyer/core/components/app_icon.dart';
import 'package:strongbody_buyer/core/constants/app_svg.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';

import '../../bloc/voice_request/voice_request_bloc.dart';

/// Hàng nút: tạm dừng / nói tiếp · ✓ hoàn tất · ↶ nói lại từ đầu.
class VoiceControls extends StatelessWidget {
  const VoiceControls({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      VoiceRequestBloc,
      VoiceRequestState,
      VoiceRequestStatus
    >(
      selector: (state) => state.status,
      builder: (context, status) {
        final bloc = context.read<VoiceRequestBloc>();
        final ready =
            status != VoiceRequestStatus.initializing &&
            status != VoiceRequestStatus.unavailable;
        final listening = status == VoiceRequestStatus.listening;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _OutlineCircleButton(
              icon: listening ? Icons.pause_rounded : Icons.play_arrow_rounded,
              tooltip: listening
                  ? LocaleKeys.voiceRequestPause.tr()
                  : LocaleKeys.voiceRequestResume.tr(),
              onTap: ready
                  ? () => bloc.add(const VoiceRequestPauseToggled())
                  : null,
            ),
            _DoneButton(
              pulsing: listening,
              onTap: ready
                  ? () => bloc.add(const VoiceRequestSubmitted())
                  : null,
            ),
            _OutlineCircleButton(
              icon: Icons.undo_rounded,
              tooltip: LocaleKeys.voiceRequestRestart.tr(),
              onTap: ready
                  ? () => bloc.add(const VoiceRequestRestarted())
                  : null,
            ),
          ],
        );
      },
    );
  }
}

class _OutlineCircleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _OutlineCircleButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: theme.surface(context),
        shape: CircleBorder(side: BorderSide(color: theme.border(context))),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: 56.r,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon,
                key: ValueKey(icon),
                size: 24.r,
                color: onTap == null
                    ? theme.textTertiary(context)
                    : theme.textPrimary(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Nút ✓ đỏ lớn; có quầng sáng lan toả khi đang nghe.
class _DoneButton extends StatefulWidget {
  final bool pulsing;
  final VoidCallback? onTap;

  const _DoneButton({required this.pulsing, this.onTap});

  @override
  State<_DoneButton> createState() => _DoneButtonState();
}

class _DoneButtonState extends State<_DoneButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _halo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    _syncHalo();
  }

  @override
  void didUpdateWidget(covariant _DoneButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pulsing != widget.pulsing) _syncHalo();
  }

  void _syncHalo() {
    if (widget.pulsing) {
      _halo.repeat();
    } else {
      _halo
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _halo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final red = theme.primary(context);
    final size = 80.r;
    return SizedBox.square(
      dimension: size * 1.4,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _halo,
            builder: (context, _) {
              if (!widget.pulsing) return const SizedBox.shrink();
              final t = Curves.easeOut.transform(_halo.value);
              return Container(
                width: size * (1 + 0.4 * t),
                height: size * (1 + 0.4 * t),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: red.withValues(alpha: 0.18 * (1 - t)),
                ),
              );
            },
          ),
          Material(
            color: red,
            shape: const CircleBorder(),
            elevation: 6,
            shadowColor: red.withValues(alpha: 0.45),
            child: InkWell(
              onTap: widget.onTap,
              customBorder: const CircleBorder(),
              child: SizedBox.square(
                dimension: size,
                child: Semantics(
                  label: LocaleKeys.voiceRequestDone.tr(),
                  child: AppIcon(AppSvg.check, size: 36.r, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
