import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PillToast {
  static void show(BuildContext context, String message, {bool isError = false}) {
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.hideCurrentSnackBar();
    
    scaffold.showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
        content: Container(
          decoration: BoxDecoration(
            color: isError 
              ? Colors.red[900]!.withValues(alpha: 0.90)
              : const Color(0xFF080C11).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: isError 
                ? Colors.redAccent.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isError) ...[
                Icon(Icons.warning_amber_rounded, color: Colors.white.withValues(alpha: 0.9), size: 18),
                const SizedBox(width: 12),
              ],
              Flexible(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.instrumentSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.95),
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
