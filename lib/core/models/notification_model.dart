/// Notification data model — mirrors the MongoDB Notification schema
class NotificationModel {
  final String id;
  final String recipientId;
  final String type;
  final String? referenceId;
  final String message;
  final bool isRead;
  final DateTime? createdAt;

  NotificationModel({
    required this.id,
    required this.recipientId,
    required this.type,
    this.referenceId,
    required this.message,
    this.isRead = false,
    this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      recipientId: json['recipient_id']?.toString() ?? '',
      type: json['type'] ?? '',
      referenceId: json['reference_id']?.toString(),
      message: json['message'] ?? '',
      isRead: json['is_read'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])?.toLocal()
          : null,
    );
  }
}
