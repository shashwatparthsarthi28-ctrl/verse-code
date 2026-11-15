import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/theme.dart';
import '../services/models.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final l = await app.backend.getNotifications();
      if (mounted) setState(() => _list = l);
      await app.backend.markNotificationsRead();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return GxScaffold(
      appBar: AppBar(title: const Text('NOTIFICATIONS')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Gx.gold))
          : _list.isEmpty
              ? Center(child: Text('Nothing here yet.', style: Gx.label(size: 14)))
              : ListView(padding: const EdgeInsets.all(16), children: [
                  for (final n in _list)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        glow: !n.read,
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(n.read ? Icons.notifications_none : Icons.notifications_active, color: n.read ? Gx.muted : Gx.gold, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(n.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 3),
                              Text(n.body, style: const TextStyle(color: Gx.muted, fontSize: 13, height: 1.3)),
                              const SizedBox(height: 4),
                              Text(timeAgo(n.ts), style: Gx.label(size: 10.5)),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                ]),
    );
  }
}
