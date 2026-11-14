import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../data/auth_repository.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false; // shows success UI after email is sent

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ref
          .read(authRepositoryProvider)
          .sendPasswordResetEmail(_emailController.text.trim());

      // Show success state instead of navigating away
      setState(() => _emailSent = true);
    } on FirebaseAuthException catch (e) {
      _showError(getAuthErrorMessage(e.code));
    } catch (e) {
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    showErrorSnackBar(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: BrandBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _emailSent
                ? _buildSuccessView(theme)
                : _buildFormView(theme),
          ),
        ),
      ),
    );
  }

  // ── Form view (before sending email) ────────────────────────────────────────
  Widget _buildFormView(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),

        // Lock icon
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.lock_reset_rounded,
            color: AppColors.primary,
            size: 32,
          ),
        ),

        const SizedBox(height: 24),

        Text('Reset password', style: theme.textTheme.displayMedium),
        const SizedBox(height: 8),
        Text(
          "Enter your email and we'll send you a link to reset your password.",
          style: theme.textTheme.bodyMedium,
        ),

        const SizedBox(height: 36),

        Form(
          key: _formKey,
          child: TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _sendResetEmail(),
            decoration: const InputDecoration(
              hintText: 'Email address',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email';
              }
              if (!RegExp(
                r'^[\w.+-]+@([\w-]+\.)+[\w-]{2,}$',
              ).hasMatch(value.trim())) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
        ),

        const SizedBox(height: 24),

        ElevatedButton(
          onPressed: _isLoading ? null : _sendResetEmail,
          child: _isLoading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Send Reset Link'),
        ),
      ],
    );
  }

  // ── Success view (after email sent) ─────────────────────────────────────────
  Widget _buildSuccessView(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Animated success checkmark container
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            color: AppColors.success,
            size: 44,
          ),
        ),

        const SizedBox(height: 28),

        Text(
          'Check your email',
          style: theme.textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 12),

        Text(
          'We sent a password reset link to\n${_emailController.text.trim()}',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 40),

        ElevatedButton(
          onPressed: () => context.pop(),
          child: const Text('Back to Sign In'),
        ),

        const SizedBox(height: 16),

        // Allow resending
        TextButton(
          onPressed: () => setState(() => _emailSent = false),
          child: const Text("Didn't receive it? Try again"),
        ),
      ],
    );
  }
}
