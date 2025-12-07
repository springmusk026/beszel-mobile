import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../animations/app_curves.dart';
import '../animations/app_durations.dart';
import '../services/auth_service.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.onSuccess});

  final VoidCallback? onSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;
  int _mode = 0; // 0: login, 1: forgot password, 2: OTP request, 3: OTP input
  String? _otpId;
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  final _auth = AuthService();

  // Animation controllers for error message
  late AnimationController _errorAnimationController;
  late Animation<double> _errorSlideAnimation;
  late Animation<double> _errorFadeAnimation;

  // Animation controller for submit button
  late AnimationController _buttonAnimationController;
  late Animation<double> _buttonScaleAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    // Error message animation (150ms slide-down)
    _errorAnimationController = AnimationController(
      vsync: this,
      duration: AppDurations.fast,
    );
    _errorSlideAnimation = Tween<double>(begin: -10.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _errorAnimationController,
        curve: AppCurves.enter,
      ),
    );
    _errorFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _errorAnimationController,
        curve: AppCurves.enter,
      ),
    );

    // Button scale animation (100ms scale-down)
    _buttonAnimationController = AnimationController(
      vsync: this,
      duration: AppDurations.instant,
    );
    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _buttonAnimationController,
        curve: AppCurves.standard,
      ),
    );
  }


  void _showError(String message) {
    setState(() {
      _error = message;
    });
    _errorAnimationController.forward(from: 0);
  }

  void _clearError() {
    _errorAnimationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _error = null;
        });
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
    });
    if (_error != null) _clearError();
    try {
      await _auth.login(
          _emailController.text.trim(), _passwordController.text);
      widget.onSuccess?.call();
    } catch (e) {
      _showError('Login failed. Please check your credentials.');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _requestPasswordReset() async {
    if (_emailController.text.trim().isEmpty) {
      _showError('Please enter your email address');
      return;
    }
    setState(() {
      _loading = true;
    });
    if (_error != null) _clearError();
    try {
      await _auth.requestPasswordReset(_emailController.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Password reset link sent to ${_emailController.text.trim()}')),
      );
      setState(() => _mode = 0);
    } catch (e) {
      _showError('Failed to send password reset email');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _requestOTP() async {
    if (_emailController.text.trim().isEmpty) {
      _showError('Please enter your email address');
      return;
    }
    setState(() {
      _loading = true;
    });
    if (_error != null) _clearError();
    try {
      final otpId = await _auth.requestOTP(_emailController.text.trim());
      if (!mounted) return;
      setState(() {
        _otpId = otpId;
        _mode = 3;
      });
    } catch (e) {
      _showError('Failed to request OTP');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _onOtpChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
    _checkOtpComplete();
  }

  Future<void> _checkOtpComplete() async {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length == 6 && _otpId != null) {
      setState(() => _loading = true);
      try {
        await _auth.authWithOTP(_otpId!, otp);
        widget.onSuccess?.call();
      } catch (e) {
        _showError('Invalid OTP. Please try again.');
        for (var c in _otpControllers) {
          c.clear();
        }
        _otpFocusNodes[0].requestFocus();
      } finally {
        if (mounted) {
          setState(() => _loading = false);
        }
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var f in _otpFocusNodes) {
      f.dispose();
    }
    _errorAnimationController.dispose();
    _buttonAnimationController.dispose();
    super.dispose();
  }


  /// Builds consistent InputDecoration for text fields
  InputDecoration _buildInputDecoration({
    required String labelText,
    required IconData prefixIcon,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: labelText,
      prefixIcon: Icon(prefixIcon),
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      border: OutlineInputBorder(
        borderRadius: AppRadius.mediumBorderRadius,
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.mediumBorderRadius,
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.mediumBorderRadius,
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.mediumBorderRadius,
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadius.mediumBorderRadius,
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
    );
  }

  /// Builds the animated error message widget
  Widget _buildErrorMessage() {
    if (_error == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _errorAnimationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _errorSlideAnimation.value),
          child: Opacity(
            opacity: _errorFadeAnimation.value,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppSpacing.md),
              margin: EdgeInsets.only(bottom: AppSpacing.sm),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                borderRadius: AppRadius.smallBorderRadius,
                border: Border.all(
                  color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                    size: 20,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds an animated submit button with scale-down micro-interaction
  Widget _buildAnimatedButton({
    required String label,
    required VoidCallback? onPressed,
    required bool isLoading,
  }) {
    return GestureDetector(
      onTapDown: (_) {
        if (!isLoading) _buttonAnimationController.forward();
      },
      onTapUp: (_) => _buttonAnimationController.reverse(),
      onTapCancel: () => _buttonAnimationController.reverse(),
      child: AnimatedBuilder(
        animation: _buttonScaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _buttonScaleAnimation.value,
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: isLoading ? null : onPressed,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.mediumBorderRadius,
                  ),
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                ),
                child: AnimatedSwitcher(
                  duration: AppDurations.fast,
                  child: isLoading
                      ? SizedBox(
                          key: const ValueKey('loading'),
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                              Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        )
                      : Text(
                          key: ValueKey(label),
                          label,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_mode == 1
            ? 'Reset Password'
            : _mode == 2 || _mode == 3
                ? 'OTP Login'
                : 'Beszel Login'),
        leading: _mode != 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _mode = 0;
                  if (_error != null) _clearError();
                  _otpId = null;
                }),
              )
            : null,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_mode == 0) _buildLoginForm(),
                    if (_mode == 1) _buildForgotPasswordForm(),
                    if (_mode == 2) _buildOtpRequestForm(),
                    if (_mode == 3) _buildOtpInputForm(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AnimatedFormField(
          child: TextFormField(
            controller: _emailController,
            decoration: _buildInputDecoration(
              labelText: 'Email',
              prefixIcon: Icons.email_outlined,
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (v) => (v == null || v.isEmpty) ? 'Email is required' : null,
            textInputAction: TextInputAction.next,
          ),
        ),
        SizedBox(height: AppSpacing.md),
        _AnimatedFormField(
          delay: const Duration(milliseconds: 50),
          child: TextFormField(
            controller: _passwordController,
            decoration: _buildInputDecoration(
              labelText: 'Password',
              prefixIcon: Icons.lock_outlined,
            ),
            obscureText: true,
            validator: (v) => (v == null || v.isEmpty) ? 'Password is required' : null,
            onFieldSubmitted: (_) => _submit(),
            textInputAction: TextInputAction.done,
          ),
        ),
        SizedBox(height: AppSpacing.lg),
        _buildErrorMessage(),
        _buildAnimatedButton(
          label: 'Login',
          onPressed: _submit,
          isLoading: _loading,
        ),
        SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => setState(() {
                _mode = 1;
                if (_error != null) _clearError();
              }),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
              child: const Text('Forgot Password?'),
            ),
            Text(
              '|',
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                _mode = 2;
                if (_error != null) _clearError();
              }),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
              child: const Text('Login with OTP'),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.sm),
        TextButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/settings/server'),
          icon: const Icon(Icons.settings_outlined, size: 20),
          label: const Text('Server Settings'),
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForgotPasswordForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AnimatedFormField(
          child: TextFormField(
            controller: _emailController,
            decoration: _buildInputDecoration(
              labelText: 'Email',
              prefixIcon: Icons.email_outlined,
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (v) => (v == null || v.isEmpty) ? 'Email is required' : null,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _requestPasswordReset(),
          ),
        ),
        SizedBox(height: AppSpacing.lg),
        _buildErrorMessage(),
        _buildAnimatedButton(
          label: 'Send Reset Link',
          onPressed: _requestPasswordReset,
          isLoading: _loading,
        ),
      ],
    );
  }

  Widget _buildOtpRequestForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AnimatedFormField(
          child: TextFormField(
            controller: _emailController,
            decoration: _buildInputDecoration(
              labelText: 'Email',
              prefixIcon: Icons.email_outlined,
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (v) => (v == null || v.isEmpty) ? 'Email is required' : null,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _requestOTP(),
          ),
        ),
        SizedBox(height: AppSpacing.lg),
        _buildErrorMessage(),
        _buildAnimatedButton(
          label: 'Request OTP',
          onPressed: _requestOTP,
          isLoading: _loading,
        ),
      ],
    );
  }


  Widget _buildOtpInputForm() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Enter the 6-digit code sent to your email',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        SizedBox(height: AppSpacing.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
            6,
            (i) => _AnimatedFormField(
              delay: Duration(milliseconds: 50 * i),
              child: SizedBox(
                width: 48,
                child: TextField(
                  controller: _otpControllers[i],
                  focusNode: _otpFocusNodes[i],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.mediumBorderRadius,
                      borderSide: BorderSide(color: scheme.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadius.mediumBorderRadius,
                      borderSide: BorderSide(color: scheme.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadius.mediumBorderRadius,
                      borderSide: BorderSide(color: scheme.primary, width: 2),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                  ),
                  onChanged: (v) => _onOtpChanged(i, v),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: AppSpacing.lg),
        _buildErrorMessage(),
        if (_loading)
          Padding(
            padding: EdgeInsets.only(top: AppSpacing.md),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(scheme.primary),
            ),
          ),
      ],
    );
  }
}

/// A widget that animates form fields with a fade and slide-up effect
class _AnimatedFormField extends StatefulWidget {
  const _AnimatedFormField({
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration delay;

  @override
  State<_AnimatedFormField> createState() => _AnimatedFormFieldState();
}

class _AnimatedFormFieldState extends State<_AnimatedFormField>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.normal,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AppCurves.enter),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: AppCurves.enter),
    );

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}
