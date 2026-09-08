import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy for IELTS Test Prep',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Last Updated: September 1, 2026',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              'Introduction',
              'This Privacy Policy explains how Darasahub Holdings Limited ("we," "us," or "our") collects, uses, stores, and protects information when you use the IELTS Test Prep mobile application (the "Application"). By downloading, accessing, or using the Application, you agree to the practices described in this Privacy Policy.',
            ),
            _buildSection(
              context,
              '1. Information We Collect',
              'When you download and use the Application, we may collect certain information automatically, including:\n'
              '• Your device\'s Internet Protocol (IP) address.\n'
              '• Information about the pages or sections of the Application that you visit.\n'
              '• The date and time of your visits.\n'
              '• The amount of time you spend using the Application.\n'
              '• Information about your mobile device and operating system.\n'
              '• Other technical and usage information that helps us maintain and improve the Application.\n\n'
              'The Application does not collect precise location information from your mobile device.\n\n'
              'Information You Provide\n'
              'For certain features, you may be required to provide personally identifiable information. For example, when creating or signing into an account, we may collect your email address through Supabase Authentication. We collect only the information necessary to provide and improve the Application and its features.',
            ),
            _buildSection(
              context,
              '2. How We Use Your Information',
              'We may use the information we collect to:\n'
              '• Provide, maintain, and improve the Application.\n'
              '• Create and manage user accounts.\n'
              '• Provide access to IELTS preparation content and features.\n'
              '• Monitor application performance and usage.\n'
              '• Respond to user requests and support inquiries.\n'
              '• Send important service-related communications, such as account or security notifications.\n'
              '• Improve the quality, functionality, and user experience of the Application.\n'
              '• Communicate information about updates, features, or promotional offers where permitted by applicable law.\n\n'
              'We do not sell your personal information to third parties.',
            ),
            _buildSection(
              context,
              '3. Third-Party Services',
              'The Application uses certain third-party services to provide authentication, application functionality, analytics, hosting, or other services. These third-party service providers may process information in accordance with their own privacy policies. The third-party services currently used by the Application may include:\n'
              '• Google Play Services\n'
              '• Supabase\n\n'
              'You should review the privacy policies of these third-party providers to understand how they collect and process information. Where possible, we use aggregated or anonymized information to help us understand how the Application is used and to improve our services.',
            ),
            _buildSection(
              context,
              '4. Data Retention',
              'We retain information you provide for as long as reasonably necessary to provide the Application and its services, comply with applicable legal obligations, resolve disputes, and enforce our agreements.\n\n'
              'If you would like us to delete personal information associated with your account, you may contact us using the contact information provided below. We will review and process your request within a reasonable period, subject to any legal or legitimate business requirements that may require us to retain certain information.',
            ),
            _buildSection(
              context,
              '5. Children\'s Privacy',
              'The Application is not directed toward children under the age of 13. We do not knowingly collect personally identifiable information from children under 13 years of age. If we become aware that a child under 13 has provided us with personal information without appropriate parental or guardian consent, we will take reasonable steps to delete that information from our systems. If you are a parent or guardian and believe that your child has provided personal information to us, please contact us using the contact information provided below.',
            ),
            _buildSection(
              context,
              '6. Data Security',
              'We take reasonable measures to protect the information we collect and maintain against unauthorized access, disclosure, alteration, or destruction. These measures may include physical, electronic, and procedural safeguards. However, no method of electronic storage or transmission over the Internet can be guaranteed to be completely secure.',
            ),
            _buildSection(
              context,
              '7. Changes to This Privacy Policy',
              'We may update this Privacy Policy from time to time to reflect changes to the Application, our practices, legal requirements, or other relevant circumstances. When we make changes, we will update the "Last Updated" date at the top of this Privacy Policy. We encourage you to review this Privacy Policy periodically to stay informed about how we handle your information. Your continued use of the Application after changes to this Privacy Policy are posted constitutes your acknowledgment of the updated policy.',
            ),
            _buildSection(
              context,
              '8. Your Consent',
              'By using the Application, you consent to the collection, use, and processing of your information as described in this Privacy Policy. Where required by applicable law, we will obtain additional consent for specific types of data processing.',
            ),
            _buildSection(
              context,
              '9. Contact Us',
              'If you have questions, concerns, or requests regarding this Privacy Policy or the way we handle your information, please contact us at:\n\n'
              'Darasahub Holdings Limited\n'
              'Email: ruttohkip4@gmail.com or masomo@darasahub.com',
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.grey[300] 
                  : Colors.grey[800],
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
