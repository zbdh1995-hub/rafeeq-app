import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class FirebaseSyncService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// فحص وجود تحديث جديد للتطبيق من Firestore
  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      // جلب معلومات الإصدار الحالي للتطبيق المثبت
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 1;

      // قراءة بيانات آخر إصدار من مجموعة app_config -> وثيقة version
      final doc = await _db.collection('app_config').doc('version').get();
      if (!doc.exists || doc.data() == null) return;

      final data = doc.data()!;
      final int latestBuildNumber = data['build_number'] ?? 1;
      final String latestVersionName = data['version_name'] ?? '1.0.0';
      final String apkUrl = data['apk_url'] ?? '';
      final String releaseNotes = data['notes'] ?? 'تحسينات في الأداء وإصلاح بعض الأخطاء.';
      final bool forceUpdate = data['force_update'] ?? false;

      // إذا كان الإصدار المرفوع على فايربيس أحدث من إصدار الموبايل
      if (latestBuildNumber > currentBuildNumber && apkUrl.isNotEmpty) {
        if (!context.mounted) return;
        _showUpdateDialog(
          context,
          versionName: latestVersionName,
          notes: releaseNotes,
          apkUrl: apkUrl,
          isForced: forceUpdate,
        );
      }
    } catch (e) {
      debugPrint('Update check error: $e');
    }
  }

  static void _showUpdateDialog(
    BuildContext context, {
    required String versionName,
    required String notes,
    required String apkUrl,
    required bool isForced,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !isForced,
      builder: (ctx) => PopScope(
        canPop: !isForced,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.system_update, color: Colors.teal),
                const SizedBox(width: 8),
                Text('تحديث جديد متاح ($versionName)'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ما الجديد في هذا الإصدار:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(notes),
              ],
            ),
            actions: [
              if (!isForced)
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('لاحقاً'),
                ),
              ElevatedButton.icon(
                onPressed: () async {
                  final uri = Uri.parse(apkUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.download),
                label: const Text('تحديث الآن'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}