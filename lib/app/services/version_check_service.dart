import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class VersionCheckService {
  static bool _shown = false;

  static Future<void> check(BuildContext context) async {
    if (_shown) return;
    _shown = true;

    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;

      final res = await http.get(
        Uri.parse("http://YOUR_SERVER/api/app/version"),
      );

      if (res.statusCode != 200) return;

      final data = json.decode(res.body);

      if (data["latest_version"] != currentVersion) {
        _showUpdateDialog(
          context,
          data["latest_version"],
          data["message"],
          data["download_url"],
        );
      }
    } catch (_) {
      // Silent fail – no crash
    }
  }

  static void _showUpdateDialog(
    BuildContext context,
    String version,
    String message,
    String? downloadUrl,
  ) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        title: const Text("Update Available"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Version $version is available."),
            const SizedBox(height: 8),
            Text(message),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Later"),
          ),
          if (downloadUrl != null)
            ElevatedButton(
              onPressed: () async {
                final uri = Uri.parse(downloadUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: const Text("Download"),
            ),
        ],
      ),
    );
  }
}
