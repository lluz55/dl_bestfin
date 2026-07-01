import 'dart:typed_data';
import 'package:bestfin/features/llm/domain/models/llm_metrics.dart';

enum ChatRole { user, assistant }

class ChatMessage {
  final int? id;
  final ChatRole role;
  final String content;
  final Uint8List? imageBytes;
  final DateTime createdAt;
  final LlmMetrics? metrics;
  final String? toolCall;
  final String? toolResult;
  final bool isToolRunning;
  final bool isPostToolStreaming;

  /// Chain-of-thought / reasoning content emitted by the model (reasoning_content field).
  final String? thinkingContent;

  const ChatMessage({
    this.id,
    required this.role,
    required this.content,
    this.imageBytes,
    required this.createdAt,
    this.metrics,
    this.toolCall,
    this.toolResult,
    this.isToolRunning = false,
    this.isPostToolStreaming = false,
    this.thinkingContent,
  });

  bool get isUser => role == ChatRole.user;
  bool get isAssistant => role == ChatRole.assistant;

  ChatMessage copyWith({
    String? content,
    LlmMetrics? metrics,
    String? toolCall,
    String? toolResult,
    bool? isToolRunning,
    bool? isPostToolStreaming,
    String? thinkingContent,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      imageBytes: imageBytes,
      createdAt: createdAt,
      metrics: metrics ?? this.metrics,
      toolCall: toolCall ?? this.toolCall,
      toolResult: toolResult ?? this.toolResult,
      isToolRunning: isToolRunning ?? this.isToolRunning,
      isPostToolStreaming: isPostToolStreaming ?? this.isPostToolStreaming,
      thinkingContent: thinkingContent ?? this.thinkingContent,
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
