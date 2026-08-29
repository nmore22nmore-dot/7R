import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../n_data.dart';
import 'home_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool isLogin = true;
  bool loading = false;
  bool obscurePassword = true;

  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ageController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (loading) return;

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      loading = true;
    });

    bool success = false;

    if (isLogin) {
      success = await data.loginWithPassword(
        emailAddress: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } else {
      final age = int.tryParse(
        _ageController.text.trim(),
      );

      if (age == null) {
        if (mounted) {
          setState(() {
            loading = false;
          });
        }

        _showError('يرجى إدخال العمر بشكل صحيح');
        return;
      }

      success = await data.signUp(
        newName: _nameController.text.trim(),
        newUsername: _usernameController.text.trim(),
        newEmail: _emailController.text.trim(),
        password: _passwordController.text,
        newAge: age,
      );
    }

    if (!mounted) return;

    setState(() {
      loading = false;
    });

    if (success) {
      final session = data.supabase.auth.currentSession;

      if (session == null) {
        if (!isLogin) {
          _showSuccess(
            'تم إنشاء الحساب بنجاح. '
            'إذا كان تأكيد البريد الإلكتروني مفعّلًا في Supabase، '
            'افتح بريدك الإلكتروني ثم سجّل الدخول.',
          );

          setState(() {
            isLogin = true;
          });

          _passwordController.clear();
          return;
        }

        _showError(
          'تمت العملية ولكن لا توجد جلسة تسجيل دخول.',
        );
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const HomePage(),
        ),
        (route) => false,
      );
    } else {
      _showError(
        data.errorMessage ?? 'حدث خطأ، حاول مرة أخرى',
      );
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textAlign: TextAlign.right,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _showSuccess(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textAlign: TextAlign.right,
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
  }

  void _switchMode() {
    if (loading) return;

    FocusScope.of(context).unfocus();

    _formKey.currentState?.reset();

    setState(() {
      isLogin = !isLogin;
      obscurePassword = true;
    });
  }

  Future<void> _resetPassword() async {
    if (loading) return;

    final email = _emailController.text.trim();

    if (email.isEmpty ||
        !email.contains('@') ||
        !email.contains('.')) {
      _showError(
        'أدخل بريدك الإلكتروني أولًا لاستعادة كلمة المرور.',
      );
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      await data.supabase.auth.resetPasswordForEmail(
        email,
      );

      if (!mounted) return;

      _showSuccess(
        'تم إرسال رابط استعادة كلمة المرور إلى بريدك الإلكتروني.',
      );
    } on AuthException catch (e) {
      if (!mounted) return;

      _showError(e.message);
    } catch (_) {
      if (!mounted) return;

      _showError(
        'تعذر إرسال رابط استعادة كلمة المرور.',
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07080D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'N',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              24,
              20,
              24,
              40,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 520,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 82,
                      height: 82,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(24),
                        gradient:
                            const LinearGradient(
                          colors: [
                            Color(0xFF00C8FF),
                            Color(0xFFFF287A),
                          ],
                        ),
                      ),
                      child: const Text(
                        'N',
                        style: TextStyle(
                          fontSize: 54,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      isLogin
                          ? 'تسجيل الدخول'
                          : 'إنشاء حساب جديد',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 29,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      isLogin
                          ? 'سجّل الدخول إلى حسابك في N'
                          : 'أنشئ حسابك وابدأ استخدام N',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 30),

                    if (!isLogin) ...[
                      _buildField(
                        controller: _nameController,
                        label: 'الاسم',
                        hint: 'أدخل اسمك',
                        icon: Icons.person_outline,
                        textInputAction:
                            TextInputAction.next,
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'أدخل الاسم';
                          }

                          if (value.trim().length < 2) {
                            return 'الاسم قصير جدًا';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      _buildField(
                        controller:
                            _usernameController,
                        label: 'اسم المستخدم',
                        hint: 'مثال: n_user',
                        icon: Icons.alternate_email,
                        textInputAction:
                            TextInputAction.next,
                        validator: (value) {
                          final username =
                              value?.trim() ?? '';

                          if (username.isEmpty) {
                            return 'أدخل اسم المستخدم';
                          }

                          if (username.length < 4) {
                            return 'اسم المستخدم يجب أن يكون 4 أحرف على الأقل';
                          }

                          if (username.contains(' ')) {
                            return 'لا يمكن أن يحتوي اسم المستخدم على مسافات';
                          }

                          if (username.contains('@')) {
                            return 'لا تكتب @ داخل اسم المستخدم';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 16),
                    ],

                    _buildField(
                      controller: _emailController,
                      label: 'البريد الإلكتروني',
                      hint: 'example@email.com',
                      icon: Icons.email_outlined,
                      keyboardType:
                          TextInputType.emailAddress,
                      textInputAction:
                          TextInputAction.next,
                      validator: (value) {
                        final email =
                            value?.trim() ?? '';

                        if (email.isEmpty) {
                          return 'أدخل البريد الإلكتروني';
                        }

                        if (!email.contains('@') ||
                            !email.contains('.')) {
                          return 'أدخل بريدًا إلكترونيًا صحيحًا';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    _buildField(
                      controller:
                          _passwordController,
                      label: 'كلمة المرور',
                      hint: '6 أحرف على الأقل',
                      icon: Icons.lock_outline,
                      obscureText:
                          obscurePassword,
                      textInputAction: isLogin
                          ? TextInputAction.done
                          : TextInputAction.next,
                      suffixIcon: IconButton(
                        onPressed: loading
                            ? null
                            : () {
                                setState(() {
                                  obscurePassword =
                                      !obscurePassword;
                                });
                              },
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                      onSubmitted: (_) {
                        if (isLogin) {
                          _submit();
                        }
                      },
                      validator: (value) {
                        final password =
                            value ?? '';

                        if (password.isEmpty) {
                          return 'أدخل كلمة المرور';
                        }

                        if (password.length < 6) {
                          return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                        }

                        return null;
                      },
                    ),

                    if (!isLogin) ...[
                      const SizedBox(height: 16),

                      _buildField(
                        controller: _ageController,
                        label: 'العمر',
                        hint: 'مثال: 25',
                        icon: Icons.cake_outlined,
                        keyboardType:
                            TextInputType.number,
                        textInputAction:
                            TextInputAction.done,
                        validator: (value) {
                          final age = int.tryParse(
                            value?.trim() ?? '',
                          );

                          if (age == null) {
                            return 'أدخل عمرك';
                          }

                          if (age < 13) {
                            return 'يجب أن يكون العمر 13 سنة فأكثر';
                          }

                          if (age > 120) {
                            return 'أدخل عمرًا صحيحًا';
                          }

                          return null;
                        },
                        onSubmitted: (_) {
                          _submit();
                        },
                      ),

                      const SizedBox(height: 10),

                      const Text(
                        'سيتم استخدام العمر لتطبيق قيود المحتوى المناسبة، '
                        'ومحتوى +21 متاح فقط لمن أعمارهم 21 سنة فأكثر.',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),

                    SizedBox(
                      height: 56,
                      child: FilledButton(
                        onPressed:
                            loading ? null : _submit,
                        child: loading
                            ? const SizedBox(
                                width: 25,
                                height: 25,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                isLogin
                                    ? 'تسجيل الدخول'
                                    : 'إنشاء الحساب',
                                style:
                                    const TextStyle(
                                  fontSize: 17,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Text(
                          isLogin
                              ? 'ليس لديك حساب؟'
                              : 'لديك حساب بالفعل؟',
                          style: const TextStyle(
                            color: Colors.white60,
                          ),
                        ),
                        TextButton(
                          onPressed:
                              loading ? null : _switchMode,
                          child: Text(
                            isLogin
                                ? 'إنشاء حساب'
                                : 'تسجيل الدخول',
                            style: const TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (isLogin) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed:
                            loading ? null : _resetPassword,
                        child: const Text(
                          'نسيت كلمة المرور؟',
                        ),
                      ),
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

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    void Function(String)? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      style: const TextStyle(
        color: Colors.white,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFF11131B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFF00C8FF),
            width: 1.2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Colors.redAccent,
          ),
        ),
        focusedErrorBorder:
            OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Colors.redAccent,
          ),
        ),
      ),
    );
  }
}
