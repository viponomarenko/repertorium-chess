import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import 'san_text.dart';
import 'ui/ui.dart';

/// A comment under the board (D-109): a speech-bubble icon and the text in
/// full-strength ink, so it stands apart from the grey facts and hints
/// around it. Moves in it follow the notation setting.
class CommentText extends StatelessWidget {
  const CommentText(this.text, {super.key, this.color, this.maxLines, this.overflow});

  final String text;

  /// The ink, when the comment sits on a coloured card (training feedback);
  /// otherwise the strongest text colour.
  final Color? color;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? Theme.of(context).colorScheme.onSurface;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Level with the first line of text.
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xxs),
          child: Icon(AppIcons.comment, size: AppSizes.iconSm, color: ink),
        ),
        AppGap.h8,
        Expanded(
          child: MovesText(
            text,
            style: context.tt.comment.copyWith(color: ink),
            maxLines: maxLines,
            overflow: overflow,
          ),
        ),
      ],
    );
  }
}
