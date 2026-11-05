import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/constants.dart';
import '../services/auth_service.dart';
import 'privacy_screen.dart';
import '../widgets/nova/nova_button.dart';
import '../widgets/nova/nova_logo.dart';
import '../app/nova_colors.dart';
import '../app/nova_tokens.dart';
import '../app/nova_icons.dart';
import '../app/nova_typography.dart';

/// Sign-in and registration on one screen, with a button to switch modes.
/// Wide screens add a brand panel on the left (Studio design).
class SignInScreen extends StatefulWidget {
  const SignInScreen({
    super.key,
    required this.authService,
    this.startRegistering = false,
  });

  final AuthService authService;

  /// Opens on "Create your account" (from the welcome tour's button).
  final bool startRegistering;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  // false = sign in, true = create account.
  late bool _isRegistering = widget.startRegistering;
  bool _isBusy = false; // true while waiting for Firebase
  bool _hidePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isBusy = true);
    try {
      final email = _emailController.text;
      final password = _passwordController.text;
      if (_isRegistering) {
        await widget.authService.register(email: email, password: password);
      } else {
        await widget.authService.signIn(email: email, password: password);
      }
      // Lets the browser offer to save the login in its password manager.
      TextInput.finishAutofillContext();
      // No navigation needed: the AuthGate sees the new user and switches.
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _toggleMode() {
    setState(() {
      _isRegistering = !_isRegistering;
      _error = null;
      _confirmController.clear();
    });
  }

  Future<void> _showForgotPassword() async {
    final sent = await showDialog<bool>(
      context: context,
      builder: (_) => _ForgotPasswordDialog(
        authService: widget.authService,
        initialEmail: _emailController.text.trim(),
      ),
    );
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'If an account exists for that email, a reset link is on its way.',
          ),
        ),
      );
    }
  }

  /// At this width or wider: the brand panel on the left, the form on the
  /// right. Narrower: only the form, with the logo above it.
  static const double _twoPanels = 900;

  @override
  Widget build(BuildContext context) {
    final c = NovaColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final form = Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(NovaSpace.xl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: _buildForm(
                    context,
                    showLogo: constraints.maxWidth < _twoPanels,
                  ),
                ),
              ),
            );
            if (constraints.maxWidth < _twoPanels) return form;
            return Padding(
              padding: const EdgeInsets.all(NovaSpace.appPadding),
              child: Row(
                children: [
                  const Expanded(child: _BrandPanel()),
                  const SizedBox(width: NovaSpace.panelGap),
                  Expanded(child: form),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// A label above a field, read with it by screen readers (the field also
  /// has the same label).
  Widget _label(String text, {Widget? trailing}) {
    return Padding(
      // A trailing button brings its own 44 px of height, so less gap.
      padding: EdgeInsets.only(bottom: trailing == null ? NovaSpace.sm : 0),
      child: Row(
        children: [
          Expanded(
            child: ExcludeSemantics(
              child: Text(
                text,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: NovaColors.of(context).textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  /// A field with its label above it (no label inside the box).
  InputDecoration _fieldDecoration(
    String label,
    String hint, {
    Widget? suffix,
  }) {
    return InputDecoration(
      // For screen readers; the visible label is above the field.
      semanticCounterText: '',
      hintText: hint,
      suffixIcon: suffix,
      constraints: const BoxConstraints(minHeight: NovaSize.buttonLarge),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: NovaSpace.lg,
        vertical: NovaSpace.lg,
      ),
    );
  }

  Widget _buildForm(BuildContext context, {required bool showLogo}) {
    final theme = Theme.of(context);
    final c = NovaColors.of(context);
    final text = NovaText.of(context);
    final title = _isRegistering ? 'Create your account' : 'Welcome back';
    final subtitle = _isRegistering
        ? 'Your chats are saved to your account.'
        : 'Sign in to continue your chats.';

    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showLogo) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: NovaLogo(size: NovaSize.logoHero, hero: true),
              ),
              const SizedBox(height: NovaSpace.xl),
            ],
            Semantics(
              header: true,
              child: Text(title, style: theme.textTheme.headlineLarge),
            ),
            const SizedBox(height: NovaSpace.sm),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: c.textSecondary,
              ),
            ),
            const SizedBox(height: NovaSpace.xxl),
            _label('Email'),
            Semantics(
              label: 'Email',
              child: TextFormField(
                controller: _emailController,
                decoration: _fieldDecoration('Email', 'you@example.com'),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                enabled: !_isBusy,
                validator: validateEmail,
              ),
            ),
            const SizedBox(height: NovaSpace.lg + NovaSpace.xs),
            _label(
              'Password',
              trailing: _isRegistering
                  ? null
                  : TextButton(
                      onPressed: _isBusy ? null : _showForgotPassword,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: NovaSpace.xs,
                        ),
                        minimumSize: const Size(
                          NovaSize.minTouchTarget,
                          NovaSize.minTouchTarget,
                        ),
                        textStyle: text.small.copyWith(
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      child: const Text('Forgot password?'),
                    ),
            ),
            Semantics(
              label: 'Password',
              child: TextFormField(
                controller: _passwordController,
                decoration: _fieldDecoration(
                  'Password',
                  _isRegistering ? 'At least 8 characters' : 'Your password',
                  suffix: _showPasswordButton(),
                ),
                obscureText: _hidePassword,
                autofillHints: [
                  _isRegistering
                      ? AutofillHints.newPassword
                      : AutofillHints.password,
                ],
                textInputAction: _isRegistering
                    ? TextInputAction.next
                    : TextInputAction.done,
                onFieldSubmitted: (_) {
                  if (!_isRegistering) _submit();
                },
                enabled: !_isBusy,
                validator: (value) => _isRegistering
                    ? validateNewPassword(value)
                    : (value == null || value.isEmpty
                          ? 'Enter your password.'
                          : null),
              ),
            ),
            if (_isRegistering) ...[
              const SizedBox(height: NovaSpace.lg + NovaSpace.xs),
              _label('Confirm password'),
              Semantics(
                label: 'Confirm password',
                child: TextFormField(
                  controller: _confirmController,
                  decoration: _fieldDecoration(
                    'Confirm password',
                    'Type it again',
                    suffix: _showPasswordButton(),
                  ),
                  obscureText: _hidePassword,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  enabled: !_isBusy,
                  validator: (value) => value != _passwordController.text
                      ? 'Passwords don\'t match.'
                      : null,
                ),
              ),
            ],
            const SizedBox(height: NovaSpace.xl),
            if (_error != null) ...[
              // Text, not colour alone, says what went wrong.
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: text.small.copyWith(color: c.error),
                ),
              ),
              const SizedBox(height: NovaSpace.md),
            ],
            _isBusy
                ? const SizedBox(
                    height: NovaSize.buttonLarge,
                    child: Center(
                      child: SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : NovaButton(
                    label: _isRegistering ? 'Create account' : 'Sign in',
                    onPressed: _submit,
                    large: true,
                    expand: true,
                  ),
            const SizedBox(height: NovaSpace.lg),
            _OrDivider(
              label: _isRegistering
                  ? 'Already have an account?'
                  : 'New to ${AppConstants.appName}?',
            ),
            const SizedBox(height: NovaSpace.lg),
            NovaButton.secondary(
              label: _isRegistering ? 'Sign in instead' : 'Create an account',
              onPressed: _isBusy ? null : _toggleMode,
              large: true,
              expand: true,
            ),
            const SizedBox(height: NovaSpace.lg),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('How we use your data: ', style: text.caption),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PrivacyScreen(),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: NovaSpace.xs,
                    ),
                    minimumSize: const Size(
                      NovaSize.minTouchTarget,
                      NovaSize.minTouchTarget,
                    ),
                    textStyle: text.caption.copyWith(
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Privacy notice'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Show / hide password, on every password field.
  Widget _showPasswordButton() => IconButton(
    tooltip: _hidePassword ? 'Show password' : 'Hide password',
    icon: Icon(
      _hidePassword ? NovaIcons.showPassword : NovaIcons.hidePassword,
      size: NovaSize.icon,
    ),
    onPressed: () => setState(() => _hidePassword = !_hidePassword),
  );
}

/// A thin line with a short text in the middle ("New to Nova?").
class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = NovaColors.of(context);
    return Row(
      children: [
        Expanded(child: Divider(color: c.controlStrong)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: NovaSpace.md),
          child: Text(label, style: NovaText.of(context).caption),
        ),
        Expanded(child: Divider(color: c.controlStrong)),
      ],
    );
  }
}

/// The left panel on wide screens: logo, headline, a short description,
/// and three feature tiles. Decoration and information only.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = NovaColors.of(context);
    final text = NovaText.of(context);
    final headline = theme.textTheme.displayMedium;

    return ClipRRect(
      borderRadius: BorderRadius.circular(NovaRadius.panel),
      child: ColoredBox(
        color: c.panel,
        child: Padding(
          padding: const EdgeInsets.all(NovaSpace.xxl + NovaSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const NovaLogo(size: NovaSize.logoSidebar, hero: true),
                  const SizedBox(width: NovaSpace.sm + 2),
                  Semantics(
                    label: AppConstants.appName,
                    excludeSemantics: true,
                    child: Text(
                      AppConstants.appName.toLowerCase(),
                      style: text.logo,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Semantics(
                header: true,
                label: 'Think out loud. Learn faster.',
                excludeSemantics: true,
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Think out loud.\n'),
                      TextSpan(
                        text: 'Learn faster.',
                        style: TextStyle(color: c.accent),
                      ),
                    ],
                  ),
                  style: headline,
                ),
              ),
              const SizedBox(height: NovaSpace.xl),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Text(
                  'Your study partner for explanations, essays, PDFs and '
                  'projects, with every chat saved to your account.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: c.textSecondary,
                    height: 1.7,
                  ),
                ),
              ),
              const Spacer(),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _FeatureTile(
                        title: 'Projects',
                        body: 'Keep related chats and notes together.',
                        color: c.projectOrange,
                        tile: c.projectOrangeTile,
                      ),
                    ),
                    const SizedBox(width: NovaSpace.md),
                    Expanded(
                      child: _FeatureTile(
                        title: 'Memory',
                        body:
                            '${AppConstants.assistantName} remembers what '
                            'you choose to save.',
                        color: c.accent,
                        tile: c.accentTile,
                      ),
                    ),
                    const SizedBox(width: NovaSpace.md),
                    Expanded(
                      child: _FeatureTile(
                        title: 'Files',
                        body: 'Ask about photos and PDFs.',
                        color: c.projectTeal,
                        tile: c.projectTealTile,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.title,
    required this.body,
    required this.color,
    required this.tile,
  });

  final String title;
  final String body;
  final Color color;
  final Color tile;

  @override
  Widget build(BuildContext context) {
    final text = NovaText.of(context);
    return Container(
      padding: const EdgeInsets.all(NovaSpace.lg),
      decoration: BoxDecoration(
        color: tile,
        borderRadius: BorderRadius.circular(NovaRadius.suggestion),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: NovaSize.projectSquare + 4,
            height: NovaSize.projectSquare + 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(NovaRadius.xs),
            ),
          ),
          const SizedBox(height: NovaSpace.md),
          Text(title, style: text.cardTitle),
          const SizedBox(height: NovaSpace.xs + 2),
          Text(body, style: text.small),
        ],
      ),
    );
  }
}

/// Small dialog that asks for an email and sends a reset link.
class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({
    required this.authService,
    required this.initialEmail,
  });

  final AuthService authService;
  final String initialEmail;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _emailController = TextEditingController(
    text: widget.initialEmail,
  );
  bool _isBusy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await widget.authService.sendPasswordReset(email: _emailController.text);
      if (mounted) Navigator.of(context).pop(true);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset your password'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('We\'ll email you a link to choose a new password.'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              enabled: !_isBusy,
              validator: validateEmail,
              onFieldSubmitted: (_) => _send(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isBusy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isBusy ? null : _send,
          child: const Text('Send link'),
        ),
      ],
    );
  }
}

/// A light check that catches typos; Firebase does the real validation.
String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Enter your email.';
  final looksValid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  return looksValid ? null : 'That email address doesn\'t look right.';
}

/// Rules for a new password. Firebase only requires 6 characters; we ask
/// for 8 because longer passwords are much harder to guess.
String? validateNewPassword(String? value) {
  final password = value ?? '';
  if (password.length < 8) return 'Use at least 8 characters.';
  if (password.length > 128) return 'That password is too long.';
  return null;
}
