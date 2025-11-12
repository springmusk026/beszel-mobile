import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.onSuccess});

  final VoidCallback? onSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;
  int _mode = 0; // 0: login, 1: forgot password, 2: OTP request, 3: OTP input
  String? _otpId;
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  final _auth = AuthService();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.login(_emailController.text.trim(), _passwordController.text);
      widget.onSuccess?.call();
    } catch (e) {
      setState(() {
        _error = 'Login failed. Please check your credentials.';
      });
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
      setState(() => _error = 'Please enter your email address');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.requestPasswordReset(_emailController.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset link sent to ${_emailController.text.trim()}')),
      );
      setState(() => _mode = 0);
    } catch (e) {
      setState(() => _error = 'Failed to send password reset email');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _requestOTP() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your email address');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final otpId = await _auth.requestOTP(_emailController.text.trim());
      if (!mounted) return;
      setState(() {
        _otpId = otpId;
        _mode = 3;
      });
    } catch (e) {
      setState(() => _error = 'Failed to request OTP');
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
        setState(() {
          _error = 'Invalid OTP. Please try again.';
          _otpControllers.forEach((c) => c.clear());
          _otpFocusNodes[0].requestFocus();
        });
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
    for (var c in _otpControllers) c.dispose();
    for (var f in _otpFocusNodes) f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_mode == 1 ? 'Reset Password' : _mode == 2 || _mode == 3 ? 'OTP Login' : 'Beszel Login'),
        leading: _mode != 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _mode = 0;
                  _error = null;
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
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_mode == 0) ...[
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => (v == null || v.isEmpty) ? 'Email is required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock),
                        ),
                        obscureText: true,
                        validator: (v) => (v == null || v.isEmpty) ? 'Password is required' : null,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 16),
                      if (_error != null) ...[
                        Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                        const SizedBox(height: 8),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          child: _loading ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ) : const Text('Login'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () => setState(() => _mode = 1),
                            child: const Text('Forgot Password?'),
                          ),
                          const Text('|'),
                          TextButton(
                            onPressed: () => setState(() => _mode = 2),
                            child: const Text('Login with OTP'),
                          ),
                        ],
                      ),const SizedBox(height: 8),  // Add this
TextButton.icon(                // Add this
  onPressed: () => Navigator.pushNamed(context, '/settings/server'),
  icon: const Icon(Icons.settings),
  label: const Text('Server Settings'),
),  
                    ] else if (_mode == 1) ...[
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => (v == null || v.isEmpty) ? 'Email is required' : null,
                      ),
                      const SizedBox(height: 16),
                      if (_error != null) ...[
                        Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                        const SizedBox(height: 8),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _requestPasswordReset,
                          child: _loading ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ) : const Text('Send Reset Link'),
                        ),
                      ),
                    ] else if (_mode == 2) ...[
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => (v == null || v.isEmpty) ? 'Email is required' : null,
                      ),
                      const SizedBox(height: 16),
                      if (_error != null) ...[
                        Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                        const SizedBox(height: 8),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _requestOTP,
                          child: _loading ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ) : const Text('Request OTP'),
                        ),
                      ),
                    ] else if (_mode == 3) ...[
                      const Text('Enter the 6-digit code sent to your email', textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(6, (i) => SizedBox(
                          width: 45,
                          child: TextField(
                            controller: _otpControllers[i],
                            focusNode: _otpFocusNodes[i],
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            maxLength: 1,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(
                              counterText: '',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) => _onOtpChanged(i, v),
                          ),
                        )),
                      ),
                      const SizedBox(height: 16),
                      if (_error != null) ...[
                        Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                        const SizedBox(height: 8),
                      ],
                      if (_loading) const CircularProgressIndicator(),
                    ],
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


