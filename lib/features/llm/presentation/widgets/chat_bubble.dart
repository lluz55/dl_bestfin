import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bestfin/features/llm/domain/models/chat_message.dart';
import 'package:bestfin/features/llm/domain/models/llm_metrics.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isStreaming;
  final bool showDebug;

  const ChatBubble({
    super.key,
    required this.message,
    this.isStreaming = false,
    this.showDebug = false,
  });

  bool get _hasThinking =>
      message.thinkingContent != null && message.thinkingContent!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isUser = message.isUser;

    final bgColor = isUser ? cs.primary : cs.surfaceContainerHigh;
    final textColor = isUser ? cs.onPrimary : cs.onSurface;
    final alignment = isUser
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final borderRadius = isUser
        ? const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.8,
            ),
            child: GestureDetector(
              onLongPress: isUser || isStreaming
                  ? null
                  : () => _copyToClipboard(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: borderRadius,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.toolCall != null) ...[
                      if (message.isToolRunning)
                        _ToolRunningChip(
                          toolCall: message.toolCall!,
                          textColor: textColor,
                          cs: cs,
                          isUser: isUser,
                        )
                      else
                        _buildToolCallCard(context, cs, isUser),
                    ],
                    if (!message.isToolRunning) ...[
                      // Thinking/reasoning block shown in debug mode
                      if (showDebug && !isUser && _hasThinking)
                        _ThinkingBlock(
                          content: message.thinkingContent!,
                          isStreaming: isStreaming && message.content.isEmpty,
                          textColor: textColor,
                          cs: cs,
                        ),
                      if (message.toolCall != null &&
                          message.content.isNotEmpty)
                        const SizedBox(height: 8),
                      if (isStreaming &&
                          message.content.isEmpty &&
                          message.toolCall == null &&
                          !_hasThinking)
                        _ThinkingIndicator(
                          color: textColor,
                          label: message.isPostToolStreaming
                              ? 'Formulando resposta...'
                              : 'Pensando...',
                          icon: message.isPostToolStreaming
                              ? Icons.edit_rounded
                              : Icons.psychology_rounded,
                        )
                      else if (message.content.isNotEmpty)
                        Text(
                          message.content,
                          style: TextStyle(color: textColor, fontSize: 14),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (isStreaming && message.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SizedBox(
                width: 16,
                height: 4,
                child: LinearProgressIndicator(
                  backgroundColor: cs.surfaceContainerHigh,
                  color: cs.primary,
                ),
              ),
            ),
          if (showDebug && !isUser && !isStreaming && message.metrics != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _DebugMetricsRow(metrics: message.metrics!),
            ),
        ],
      ),
    );
  }

  String _buildCopyText() {
    final parts = <String>[];
    if (showDebug && message.toolResult != null) parts.add(message.toolResult!);
    if (message.content.isNotEmpty) parts.add(message.content);
    return parts.join('\n\n');
  }

  void _copyToClipboard(BuildContext context) {
    final text = _buildCopyText();
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copiado'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        width: 120,
      ),
    );
  }

  Widget _buildToolCallCard(BuildContext context, ColorScheme cs, bool isUser) {
    final onColor = isUser ? cs.onPrimary : cs.onSurface;
    final cardBg = isUser ? cs.primaryContainer : cs.surfaceContainerLowest;
    final borderCol = onColor.withValues(alpha: 0.12);

    final isCalc = message.toolCall!.contains('Calculando');
    final iconColor = isUser ? cs.onPrimaryContainer : cs.onSurfaceVariant;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isCalc ? Icons.calculate_outlined : Icons.table_rows_outlined,
                size: 13,
                color: iconColor,
              ),
              const SizedBox(width: 6),
              Text(
                isCalc ? 'Calculadora' : 'Banco de Dados',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            message.toolCall!,
            style: TextStyle(
              fontSize: 12,
              color: isUser ? cs.onPrimaryContainer : cs.onSurface,
            ),
          ),
          if (showDebug && message.toolResult != null) ...[
            const Divider(height: 8, thickness: 0.5),
            Text(
              message.toolResult!,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: isUser ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ThinkingBlock extends StatefulWidget {
  final String content;
  final bool isStreaming;
  final Color textColor;
  final ColorScheme cs;

  const _ThinkingBlock({
    required this.content,
    required this.isStreaming,
    required this.textColor,
    required this.cs,
  });

  @override
  State<_ThinkingBlock> createState() => _ThinkingBlockState();
}

class _ThinkingBlockState extends State<_ThinkingBlock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final tt = Theme.of(context).textTheme;
    final headerColor = cs.tertiary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: cs.tertiaryContainer.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.tertiary.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.psychology_outlined,
                      size: 14,
                      color: headerColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      widget.isStreaming ? 'Raciocínio…' : 'Ver raciocínio',
                      style: TextStyle(
                        fontSize: 12,
                        color: headerColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (widget.isStreaming)
                      SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: headerColor,
                        ),
                      )
                    else
                      Icon(
                        _expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 14,
                        color: headerColor,
                      ),
                  ],
                ),
              ),
            ),
            if (_expanded || widget.isStreaming) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: Text(
                  widget.content,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.7),
                    fontFamily: 'monospace',
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DebugMetricsRow extends StatelessWidget {
  final LlmMetrics metrics;

  const _DebugMetricsRow({required this.metrics});

  String _fmtMs(Duration d) {
    if (d.inMilliseconds < 1000) return '${d.inMilliseconds}ms';
    return '${(d.inMilliseconds / 1000).toStringAsFixed(1)}s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontSize: 13,
      fontFamily: 'monospace',
      color: cs.onSurfaceVariant,
    );

    final items = [
      ('timer', _fmtMs(metrics.totalTime), 'Total'),
      ('bolt', _fmtMs(metrics.timeToFirstToken), 'TTFT'),
      ('token', '${metrics.tokensGenerated}', 'tokens'),
      ('speed', '${metrics.tokensPerSecond.toStringAsFixed(1)} t/s', null),
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final (iconKey, value, label) in items)
          _MetricChip(
            icon: _icon(iconKey),
            value: value,
            label: label,
            style: style,
            cs: cs,
          ),
        _MetricChip(
          icon: Icons.memory_rounded,
          value: metrics.modelName,
          label: null,
          style: style.copyWith(overflow: TextOverflow.ellipsis),
          cs: cs,
          maxWidth: 180,
        ),
      ],
    );
  }

  IconData _icon(String key) => switch (key) {
    'timer' => Icons.timer_outlined,
    'bolt' => Icons.bolt_rounded,
    'token' => Icons.tag_rounded,
    'speed' => Icons.speed_rounded,
    _ => Icons.info_outline_rounded,
  };
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String? label;
  final TextStyle style;
  final ColorScheme cs;
  final double? maxWidth;

  const _MetricChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.style,
    required this.cs,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: maxWidth != null
          ? BoxConstraints(maxWidth: maxWidth!)
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: cs.onSurfaceVariant),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label != null ? '$value $label' : value,
              style: style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolRunningChip extends StatelessWidget {
  final String toolCall;
  final Color textColor;
  final ColorScheme cs;
  final bool isUser;

  const _ToolRunningChip({
    required this.toolCall,
    required this.textColor,
    required this.cs,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    final isCalc = toolCall.contains('Calculando');
    final icon = isCalc ? Icons.calculate_outlined : Icons.table_rows_outlined;
    final label = isCalc ? 'Calculando...' : 'Lendo dados...';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 13,
          height: 13,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: textColor),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 14, color: textColor),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}

class _ThinkingIndicator extends StatelessWidget {
  final Color color;
  final String label;
  final IconData icon;

  const _ThinkingIndicator({
    required this.color,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 6),
        _Dot(color: color, delay: 0),
        const SizedBox(width: 4),
        _Dot(color: color, delay: 200),
        const SizedBox(width: 4),
        _Dot(color: color, delay: 400),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.8),
            fontSize: 13,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatefulWidget {
  final Color color;
  final int delay;

  const _Dot({required this.color, required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
