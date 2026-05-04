import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:jerry_app/core/network/api_client.dart';
import 'package:jerry_app/core/theme/app_colors.dart';
import 'package:jerry_app/features/auth/otp_screen.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key, this.initialRole, this.initialMethod});
  final String? initialRole;
  final String? initialMethod;

  static const routePath = '/signup';
  static const routeName = 'signup';

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  String _role     = 'USER';
  String _fullName = '';

  final _emailCtrl     = TextEditingController();
  final _passwordCtrl  = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  String _language     = 'English';
  String _city         = '';
  String _state        = '';
  bool   _agreedTerms  = false;
  bool   _loading      = false;
  bool   _pwVisible    = false;

  static const _languages = [
    'English', 'Hindi', 'Punjabi', 'Tamil', 'Bengali',
    'Marathi', 'Telugu', 'Gujarati', 'Kannada', 'Malayalam', 'Odia', 'Urdu',
  ];

  @override
  void initState() {
    super.initState();
    _role = widget.initialRole ?? 'USER';
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    final fullName = _fullName.trim();
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (fullName.isEmpty || email.isEmpty || password.isEmpty) {
      _snack('Please fill in all required fields.'); return;
    }
    if (password != _confirmPwCtrl.text) { _snack('Passwords do not match.'); return; }
    if (!_agreedTerms) { _snack('Please agree to the terms to continue.'); return; }

    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/auth/signup', data: {
        'role':              _role,
        'email':             email,
        'password':          password,
        'fullName':          fullName,
        'preferredLanguage': _language,
        if (_city.isNotEmpty)  'city':  _city,
        if (_state.isNotEmpty) 'state': _state,
      });

      if (!mounted) return;
      context.push(OtpScreen.routePath,
          extra: OtpArgs(
            email:    email,
            role:     _role,
            fullName: fullName,
            language: _language,
            city:     _city,
            state:    _state,
          ));
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['message'] ?? e.message ?? 'Signup failed';
      _snack('$msg');
    } catch (e) {
      if (!mounted) return;
      _snack('$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text('Create account',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          // Role toggle
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              _RoleTab(label: 'I need legal help', icon: LucideIcons.user,
                  selected: _role == 'USER', onTap: () => setState(() => _role = 'USER')),
              _RoleTab(label: 'I am a lawyer', icon: LucideIcons.scale,
                  selected: _role == 'LAWYER', onTap: () => setState(() => _role = 'LAWYER')),
            ]),
          ),
          const SizedBox(height: 16),
          _AppField(hint: 'Adv. Meera Kapoor', label: 'Full name',
              keyboardType: TextInputType.name, onChanged: (v) => _fullName = v),
          const SizedBox(height: 14),
          _AppField(controller: _emailCtrl, hint: 'meera@example.com',
              keyboardType: TextInputType.emailAddress, label: 'Email'),
          const SizedBox(height: 14),
          _AppField(
            controller: _passwordCtrl,
            hint: '8+ chars, uppercase, number, symbol',
            obscureText: !_pwVisible,
            label: 'Password',
            suffix: IconButton(
              icon: Icon(_pwVisible ? LucideIcons.eyeOff : LucideIcons.eye,
                  size: 18, color: AppColors.secondary),
              onPressed: () => setState(() => _pwVisible = !_pwVisible),
            ),
          ),
          const SizedBox(height: 14),
          _AppField(controller: _confirmPwCtrl, hint: 'Re-enter password',
              obscureText: true, label: 'Confirm password'),
          const SizedBox(height: 14),
          _DropField<String>(
            value: _language, items: _languages,
            label: (l) => l,
            onChanged: (l) => setState(() => _language = l),
            fieldLabel: 'Preferred language',
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _AppField(hint: 'Mumbai', label: 'City',
                onChanged: (v) => _city = v)),
            const SizedBox(width: 12),
            Expanded(child: _AppField(hint: 'Maharashtra', label: 'State',
                onChanged: (v) => _state = v)),
          ]),
          const SizedBox(height: 20),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Checkbox(
              value: _agreedTerms,
              onChanged: (v) => setState(() => _agreedTerms = v ?? false),
              activeColor: AppColors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 8),
            Expanded(child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('I agree to the Terms of Service and Privacy Policy.',
                  style: tt.bodySmall?.copyWith(color: AppColors.secondary, height: 1.4)),
            )),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _signup,
              child: Text(_loading ? 'Sending OTP…' : 'Send OTP to Email'),
            ),
          ),
          const SizedBox(height: 24),
          Center(child: GestureDetector(
            onTap: () => context.go('/login'),
            child: RichText(text: TextSpan(
              style: tt.bodySmall?.copyWith(color: AppColors.secondary),
              children: [
                const TextSpan(text: 'Already have an account? '),
                const TextSpan(text: 'Sign in',
                    style: TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w700)),
              ],
            )),
          )),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _AppField extends StatelessWidget {
  const _AppField({this.controller, this.hint, this.label, this.keyboardType, this.obscureText = false, this.suffix, this.onChanged});
  final TextEditingController? controller;
  final String? hint;
  final String? label;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (label != null) ...[
        Text(label!, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3, color: AppColors.secondary)),
        const SizedBox(height: 6),
      ],
      TextField(
        controller: controller, keyboardType: keyboardType,
        obscureText: obscureText, onChanged: onChanged,
        style: const TextStyle(fontSize: 15, color: AppColors.onSurface),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.outline, fontSize: 14),
          filled: true, fillColor: AppColors.surfaceContainerLowest,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border:        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outlineVariant)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outlineVariant)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.onSurface, width: 1.5)),
          suffixIcon: suffix,
        ),
      ),
    ]);
  }
}

class _DropField<T> extends StatelessWidget {
  const _DropField({required this.value, required this.items, required this.label, required this.onChanged, required this.fieldLabel});
  final T value;
  final List<T> items;
  final String Function(T) label;
  final ValueChanged<T> onChanged;
  final String fieldLabel;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(fieldLabel, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3, color: AppColors.secondary)),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.outlineVariant)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value, isExpanded: true,
            icon: const Icon(LucideIcons.chevronsUpDown, size: 16, color: AppColors.secondary),
            style: const TextStyle(fontSize: 15, color: AppColors.onSurface),
            onChanged: (v) { if (v != null) onChanged(v); },
            items: items.map((i) => DropdownMenuItem(value: i, child: Text(label(i)))).toList(),
          ),
        ),
      ),
    ]);
  }
}

class _RoleTab extends StatelessWidget {
  const _RoleTab({required this.label, required this.icon, required this.selected, required this.onTap});
  final String label; final IconData icon; final bool selected; final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceContainerLowest : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected ? [BoxShadow(color: AppColors.onSurface.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))] : null,
        ),
        child: Column(children: [
          Icon(icon, size: 20, color: selected ? AppColors.onSurface : AppColors.secondary),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? AppColors.onSurface : AppColors.secondary)),
        ]),
      ),
    ));
  }
}
