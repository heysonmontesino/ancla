import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CrisisFooter extends StatelessWidget {
  const CrisisFooter({super.key});

  Future<void> _makeCall() async {
    final Uri url = Uri.parse('tel:106');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.red.shade50.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(color: Colors.red.shade100, width: 0.5),
        ),
      ),
      child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '¿Te sientes en crisis?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Estamos para apoyarte. Habla con un profesional.',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _makeCall,
              icon: const Icon(Icons.phone, size: 16),
              label: const Text('Llamar 106'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
      ),
    );
  }
}
