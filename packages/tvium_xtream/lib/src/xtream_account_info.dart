enum XtreamAccountStatus { active, disabled, expired, banned, unknown }

final class XtreamAccountInfo {
  const XtreamAccountInfo({
    required this.status,
    required this.isTrial,
    required this.activeConnections,
    required this.maximumConnections,
    required this.expiresAt,
    required this.timezone,
  });

  final XtreamAccountStatus status;
  final bool isTrial;
  final int? activeConnections;
  final int? maximumConnections;
  final DateTime? expiresAt;
  final String? timezone;
}
