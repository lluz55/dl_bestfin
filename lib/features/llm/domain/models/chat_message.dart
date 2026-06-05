import 'dart:typed_data';
import 'package:bestfin/features/llm/domain/models/llm_metrics.dart';

enum ChatRole { user, assistant }

class ToolCallRecord {
  final String description;
  final String toolName;
  final bool isRunning;
  final String? result;

  const ToolCallRecord({
    required this.description,
    required this.toolName,
    this.isRunning = false,
    this.result,
  });

  ToolCallRecord copyWith({
    String? description,
    String? toolName,
    bool? isRunning,
    String? result,
  }) => ToolCallRecord(
    description: description ?? this.description,
    toolName: toolName ?? this.toolName,
    isRunning: isRunning ?? this.isRunning,
    result: result ?? this.result,
  );
}

class ChatMessage {
  final int? id;
  final ChatRole role;
  final String content;
  final Uint8List? imageBytes;
  final DateTime createdAt;
  final LlmMetrics? metrics;
  final List<ToolCallRecord> toolCalls;
  final bool isPostToolStreaming;
  /// Chain-of-thought / reasoning content emitted by the model (reasoning_content field).
  final String? thinkingContent;
  /// Active skill ID routed to for this message (e.g. 'gastos', 'metas').
  final String? activeSkill;
  /// True while the router is classifying the message (before a skill is selected).
  final bool isRouting;

  const ChatMessage({
    this.id,
    required this.role,
    required this.content,
    this.imageBytes,
    required this.createdAt,
    this.metrics,
    this.toolCalls = const [],
    this.isPostToolStreaming = false,
    this.thinkingContent,
    this.activeSkill,
    this.isRouting = false,
  });

  bool get isUser => role == ChatRole.user;
  bool get isAssistant => role == ChatRole.assistant;
  bool get isToolRunning => toolCalls.any((t) => t.isRunning);
  bool get hasToolCalls => toolCalls.isNotEmpty;

  ChatMessage copyWith({
    String? content,
    LlmMetrics? metrics,
    List<ToolCallRecord>? toolCalls,
    bool? isPostToolStreaming,
    String? thinkingContent,
    String? activeSkill,
    bool? isRouting,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      imageBytes: imageBytes,
      createdAt: createdAt,
      metrics: metrics ?? this.metrics,
      toolCalls: toolCalls ?? this.toolCalls,
      isPostToolStreaming: isPostToolStreaming ?? this.isPostToolStreaming,
      thinkingContent: thinkingContent ?? this.thinkingContent,
      activeSkill: activeSkill ?? this.activeSkill,
      isRouting: isRouting ?? this.isRouting,
    );
  }

  factory ChatMessage.user(String content, {Uint8List? imageBytes}) {
    return ChatMessage(
      role: ChatRole.user,
      content: content,
      imageBytes: imageBytes,
      createdAt: DateTime.now(),
    );
  }

  factory ChatMessage.assistant(String content) {
    return ChatMessage(
      role: ChatRole.assistant,
      content: content,
      createdAt: DateTime.now(),
    );
  }
}
