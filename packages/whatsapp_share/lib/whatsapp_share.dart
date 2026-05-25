import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

enum Package {
  whatsapp,
  businessWhatsapp,
}

class WhatsappShare {
  static Future<bool?> isInstalled({required Package package}) async {
    try {
      return await canLaunchUrl(_schemeUri(package));
    } catch (_) {
      return false;
    }
  }

  static Future<void> shareFile({
    required String phone,
    required List<String> filePath,
    required Package package,
    String? text,
  }) async {
    final files = filePath
        .where((path) => path.trim().isNotEmpty)
        .map((path) => XFile(path))
        .toList();

    if (files.isEmpty) {
      final message = text?.trim();
      if (message != null && message.isNotEmpty) {
        await Share.share(message);
      }
      return;
    }

    final message = text?.trim();
    await Share.shareXFiles(
      files,
      text: message != null && message.isNotEmpty ? message : null,
    );
  }

  static Uri _schemeUri(Package package) {
    final scheme = package == Package.businessWhatsapp
        ? 'whatsapp-business://send?phone=1'
        : 'whatsapp://send?phone=1';
    return Uri.parse(scheme);
  }
}
