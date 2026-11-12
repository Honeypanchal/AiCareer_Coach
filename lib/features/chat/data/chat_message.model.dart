// ─── Chat Message Model ────────────────────────────────────────────────────────
// Represents a single message in the conversation.
// We keep this simple — no freezed/json_serializable needed for this small model.
class ChatMessage {
  final String text;
  final bool isUser; // true = sent by user, false = sent by AI
  final DateTime timestamp;
  final bool isError; // true if this message represents an error state

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.isError = false,
  }) : timestamp = timestamp ?? DateTime.now();

  // ── Convert to Firestore document ───────────────────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'isError': isError,
    };
  }

  // ── Create from Firestore document ──────────────────────────────────────────
  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      text: map['text'] as String,
      isUser: map['isUser'] as bool,
      timestamp: DateTime.parse(map['timestamp'] as String),
      isError: map['isError'] as bool? ?? false,
    );
  }

  // ── Format time for display (e.g. "10:30 AM") ───────────────────────────────
  String get formattedTime {
    final hour = timestamp.hour % 12 == 0 ? 12 : timestamp.hour % 12;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = timestamp.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}
