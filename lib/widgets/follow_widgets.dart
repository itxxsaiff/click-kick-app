import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/follow_service.dart';
import '../theme/app_colors.dart';

/// Round profile picture with a person-icon fallback.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.photoUrl,
    this.size = 48,
    this.borderColor,
  });

  final String photoUrl;
  final double size;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.cardSoft,
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: 2),
      ),
      child: photoUrl.isEmpty
          ? Icon(
              Icons.person_rounded,
              color: AppColors.hotPink,
              size: size * 0.55,
            )
          : Image.network(
              photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Icon(
                Icons.person_rounded,
                color: AppColors.hotPink,
                size: size * 0.55,
              ),
            ),
    );
  }
}

/// Follow / Following pill for [targetUserId]. Its state is driven by the live
/// `follows` document, so it stays correct wherever it is shown. Renders
/// nothing for the signed-in user's own account.
class FollowButton extends StatefulWidget {
  const FollowButton({
    super.key,
    required this.targetUserId,
    this.onChanged,
    this.onLoginRequired,
    this.width = 104,
    this.height = 36,
  });

  final String targetUserId;

  /// Called after a successful follow / unfollow, with the new state.
  final ValueChanged<bool>? onChanged;

  /// Called instead of the default "please login" message when signed out.
  final VoidCallback? onLoginRequired;
  final double width;
  final double height;

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  final _service = FollowService();
  bool _busy = false;

  Future<void> _toggle(bool isFollowing) async {
    if (_busy) return;
    if (_service.currentUserId == null) {
      if (widget.onLoginRequired != null) {
        widget.onLoginRequired!();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Please login to follow.'))),
      );
      return;
    }
    final failMsg = context.tr('Could not update follow. Please try again.');
    setState(() => _busy = true);
    try {
      if (isFollowing) {
        await _service.unfollow(widget.targetUserId);
      } else {
        await _service.follow(widget.targetUserId);
      }
      widget.onChanged?.call(!isFollowing);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failMsg)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = _service.currentUserId;
    if (me != null && me == widget.targetUserId) return const SizedBox.shrink();

    return StreamBuilder<bool>(
      stream: _service.isFollowingStream(widget.targetUserId),
      builder: (context, snapshot) {
        final isFollowing = snapshot.data ?? false;
        final label = isFollowing
            ? context.tr('Following')
            : context.tr('Follow');
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: isFollowing
              ? OutlinedButton(
                  onPressed: _busy ? null : () => _toggle(true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textLight,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                )
              : DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: [AppColors.hotPink, Color(0xFFD81FB8)],
                    ),
                  ),
                  child: ElevatedButton(
                    onPressed: _busy ? null : () => _toggle(false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
