import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_typography.dart';
import '../../core/app_state.dart';
import 'otp_verification_screen.dart';

/// Welcome back panel: Email | Mobile. One input (email or mobile), then OTP.
class EnterEmailMobileScreen extends StatefulWidget {
  const EnterEmailMobileScreen({super.key, this.initialModeEmail = true});

  final bool initialModeEmail;

  @override
  State<EnterEmailMobileScreen> createState() => _EnterEmailMobileScreenState();
}

class _EnterEmailMobileScreenState extends State<EnterEmailMobileScreen> {
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  late bool _isEmail; // true = Email, false = Mobile

  @override
  void initState() {
    super.initState();
    _isEmail = widget.initialModeEmail;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final value = _isEmail ? _emailController.text.trim() : _phoneController.text.trim();
    setState(() => _isLoading = true);
    context.read<AppState>().setUser(value);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const OtpVerificationScreen()),
      );
    });
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.backgroundCard,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primaryBlue.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
          color: AppColors.heading,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'Welcome back! 👋',
                      style: AppTypography.screenTitle(fontSize: 26),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your details to continue learning',
                      style: AppTypography.body(fontSize: 15, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    // Email | Mobile
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.backgroundCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _SegmentTab(
                              label: 'Email',
                              icon: Icons.email_rounded,
                              selected: _isEmail,
                              onTap: () => setState(() => _isEmail = true),
                            ),
                          ),
                          Expanded(
                            child: _SegmentTab(
                              label: 'Mobile',
                              icon: Icons.phone_android_rounded,
                              selected: !_isEmail,
                              onTap: () => setState(() => _isEmail = false),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_isEmail) ...[
                      Text('Email', style: AppTypography.cardTitle(fontSize: 14)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _inputDecoration('student@joyda.in'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Please enter email';
                          return null;
                        },
                      ),
                    ] else ...[
                      Text('Mobile number', style: AppTypography.cardTitle(fontSize: 14)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: _inputDecoration('e.g. 9876543210'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Please enter mobile number';
                          if (v.trim().length < 10) return 'Enter a valid 10-digit number';
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Continue',
                                    style: AppTypography.cardTitle(fontSize: 16).copyWith(color: Colors.white),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(Icons.arrow_forward_rounded, size: 20, color: Colors.white),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentTab extends StatelessWidget {
  const _SegmentTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryBlue.withValues(alpha: 0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: selected ? AppColors.primaryBlue : AppColors.bodyText),
              const SizedBox(width: 8),
              Text(
                label,
                style: (selected ? AppTypography.cardTitle(fontSize: 15) : AppTypography.body(fontSize: 15)).copyWith(
                  color: selected ? AppColors.primaryBlue : AppColors.bodyText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
