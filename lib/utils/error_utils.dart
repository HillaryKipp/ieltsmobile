import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ErrorUtils {
  /// Converts any exception into a human-readable, friendly error message.
  static String getFriendlyMessage(dynamic error) {
    if (error == null) return 'An unknown error occurred.';

    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('invalid login credentials') || 
          msg.contains('invalid_credentials') ||
          msg.contains('invalid email or password')) {
        return 'Incorrect email or password. Please try again.';
      }
      if (msg.contains('user already registered') || 
          msg.contains('user_already_exists') ||
          msg.contains('already registered')) {
        return 'An account with this email already exists.';
      }
      if (msg.contains('email not confirmed') || 
          msg.contains('not_confirmed') || 
          msg.contains('email_not_confirmed')) {
        return 'Please confirm your email address before signing in. Check your inbox for the confirmation link or use "Resend confirmation email".';
      }
      if (msg.contains('password should be at least')) {
        return 'Password must be at least 6 characters.';
      }
      if (msg.contains('flow state not found') || 
          msg.contains('pkce') || 
          msg.contains('expired') ||
          msg.contains('invalid_grant') ||
          msg.contains('otp_expired')) {
        return 'Your verification link has expired or has already been used. Please request a new one.';
      }
      if (msg.contains('rate limit') || 
          msg.contains('over_email_send_rate_limit') || 
          msg.contains('too many requests')) {
        return 'Too many email requests sent. For security, please wait at least 60 seconds before trying again.';
      }
      return error.message;
    }

    if (error is PostgrestException) {
      final code = error.code ?? '';
      if (code == 'PGRST116') {
        return 'Requested item not found.';
      }
      if (code == '23505') {
        return 'This record already exists.';
      }
      if (code == '42501' || error.message.toLowerCase().contains('row-level security')) {
        return 'You do not have permission to perform this action.';
      }
      if (error.message.isNotEmpty) {
        return error.message;
      }
    }

    final errorStr = error.toString().toLowerCase();
    
    if (error is SocketException || 
        errorStr.contains('socketexception') ||
        errorStr.contains('failed host lookup') ||
        errorStr.contains('network is unreachable')) {
      return 'Unable to connect to the server. Please check your internet connection.';
    }

    if (error is TimeoutException || errorStr.contains('timeout')) {
      return 'The request timed out. Please check your connection and try again.';
    }

    if (errorStr.contains('connection reset') || 
        errorStr.contains('connection refused') ||
        errorStr.contains('handshake_exception')) {
      return 'A network error occurred. Please try again.';
    }

    final str = error.toString().replaceAll('Exception:', '').trim();
    return str.isNotEmpty ? str : 'An unexpected error occurred.';
  }

  /// Displays an error SnackBar with consistent, modern styling.
  static void showErrorSnackBar(BuildContext context, dynamic error, {String? prefix, VoidCallback? onRetry}) {
    if (!context.mounted) return;
    
    final message = getFriendlyMessage(error);
    final display = prefix != null ? '$prefix: $message' : message;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                display,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Displays a success SnackBar.
  static void showSuccessSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
