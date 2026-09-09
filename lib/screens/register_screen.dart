import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_colors.dart';
import '../core/supabase_services.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const AssetImage _bannerAsset = AssetImage('assets/abuela.jpeg');

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  late final ImageProvider _bannerImage = const ResizeImage(_bannerAsset, width: 1080);

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _acceptTerms = true;
  DateTime? _birthDate;
  bool _didPrecacheBanner = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecacheBanner) return;
    _didPrecacheBanner = true;
    precacheImage(_bannerImage, context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    if (_isLoading) return;

    FocusScope.of(context).unfocus();

    final fullName = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (fullName.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showMessage('Completa todos los campos');
      return;
    }

    if (password != confirmPassword) {
      _showMessage('Las contraseñas no coinciden');
      return;
    }

    if (_birthDate == null) {
      _showMessage('Selecciona tu fecha de nacimiento');
      return;
    }

    if (!_acceptTerms) {
      _showMessage('Debes aceptar los términos y condiciones');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await SupabaseServices.signUpPaciente(
        email: email,
        password: password,
        fullName: fullName,
        birthDate: _birthDate!,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } on AuthException catch (error) {
      _showMessage(error.message);
    } on PostgrestException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F7),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTopBanner(),
                      Transform.translate(
                        offset: const Offset(0, -24),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 14,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildSocialRow(),
                              const SizedBox(height: 12),
                              _buildSeparator('O regístrate con correo'),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _nameController,
                                decoration: _fieldDecoration(
                                  label: 'Nombre completo',
                                  hint: 'Ejemplo: María López',
                                  prefix: Icons.person_outline,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: _fieldDecoration(
                                  label: 'Correo electrónico',
                                  hint: 'ejemplo@gmail.com',
                                  prefix: Icons.mail_outline,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: _fieldDecoration(
                                  label: 'Contraseña',
                                  hint: '************',
                                  prefix: Icons.lock_outline,
                                  suffix: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: const Color(0xFF7D8B94),
                                    ),
                                    onPressed: () {
                                      setState(() => _obscurePassword = !_obscurePassword);
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirmPassword,
                                decoration: _fieldDecoration(
                                  label: 'Confirmar contraseña',
                                  hint: '************',
                                  prefix: Icons.verified_user_outlined,
                                  suffix: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: const Color(0xFF7D8B94),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscureConfirmPassword = !_obscureConfirmPassword;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              InkWell(
                                onTap: _isLoading ? null : _pickBirthDate,
                                borderRadius: BorderRadius.circular(12),
                                child: InputDecorator(
                                  decoration: _fieldDecoration(
                                    label: 'Fecha de nacimiento',
                                    hint: 'Seleccionar fecha',
                                    prefix: Icons.cake_outlined,
                                  ),
                                  child: Text(
                                    _birthDate == null ? 'Seleccionar fecha' : _formatDate(_birthDate!),
                                    style: TextStyle(
                                      color: _birthDate == null
                                          ? const Color(0xFFA4B1B8)
                                          : AppColors.prussianBlue,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Checkbox(
                                      value: _acceptTerms,
                                      activeColor: const Color(0xFF1E6B67),
                                      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      side: BorderSide(
                                        color: Colors.black.withValues(alpha: 0.22),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      onChanged: _isLoading
                                          ? null
                                          : (value) {
                                              setState(() {
                                                _acceptTerms = value ?? false;
                                              });
                                            },
                                    ),
                                  ),
                                  const Expanded(
                                    child: Text.rich(
                                      TextSpan(
                                        text: 'Estoy de acuerdo con ',
                                        style: TextStyle(
                                          color: Color(0xFF60717A),
                                          fontSize: 13,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: 'Términos y condiciones',
                                            style: TextStyle(
                                              color: Color(0xFFF59E0B),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      softWrap: true,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                height: 52,
                                child: FilledButton(
                                  onPressed: _isLoading ? null : _handleContinue,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E6B67),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Registrarme',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    '¿Ya tienes cuenta? ',
                                    style: TextStyle(color: Color(0xFF60717A)),
                                  ),
                                  GestureDetector(
                                    onTap: () => Navigator.of(context).pushReplacementNamed('/login'),
                                    child: const Text(
                                      'Iniciar sesión',
                                      style: TextStyle(
                                        color: Color(0xFFF59E0B),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBanner() {
    return RepaintBoundary(
      child: SizedBox(
        height: 250,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(34),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image(
                    image: _bannerImage,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.low,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF0E5D59).withValues(alpha: 0.58),
                          const Color(0xFF0A4A47).withValues(alpha: 0.82),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: -126,
              left: -88,
              child: Container(
                width: 250,
                height: 250,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFF2F5F7),
                ),
              ),
            ),
            const Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Crear cuenta',
                    style: TextStyle(
                      fontSize: 30,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Completa tus datos para comenzar\ntu seguimiento con CLINIK.',
                    style: TextStyle(
                      color: Color(0xFFDEEBF0),
                      fontSize: 13,
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: IconButton(
                onPressed: () => Navigator.maybePop(context),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.92),
                  foregroundColor: const Color(0xFF0F172A),
                  side: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
                ),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _socialButton(
          icon: Icons.apple,
          onTap: () => _showMessage('Registro con Apple no disponible por ahora.'),
        ),
        const SizedBox(width: 12),
        _socialButton(
          customChild: const Text(
            'G',
            style: TextStyle(
              color: Color(0xFFDB4437),
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          onTap: () => _showMessage('Registro con Google no disponible por ahora.'),
        ),
        const SizedBox(width: 12),
        _socialButton(
          icon: Icons.facebook,
          iconColor: const Color(0xFF1877F2),
          onTap: () => _showMessage('Registro con Facebook no disponible por ahora.'),
        ),
      ],
    );
  }

  Widget _socialButton({
    IconData? icon,
    Color iconColor = const Color(0xFF0F172A),
    Widget? customChild,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Ink(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
        ),
        child: Center(
          child: customChild ?? Icon(icon, color: iconColor, size: 20),
        ),
      ),
    );
  }

  Widget _buildSeparator(String text) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.black.withValues(alpha: 0.12))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: Color(0xFF8B99A1)),
          ),
        ),
        Expanded(child: Divider(color: Colors.black.withValues(alpha: 0.12))),
      ],
    );
  }
  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initialDate = _birthDate ?? DateTime(now.year - 30, now.month, now.day);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (pickedDate != null) {
      setState(() => _birthDate = pickedDate);
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString().padLeft(4, '0');
    return '$day/$month/$year';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData prefix,
    String? hint,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Color(0xFF6D7D86)),
      hintStyle: const TextStyle(color: Color(0xFFA4B1B8)),
      prefixIcon: Icon(prefix, size: 20, color: const Color(0xFF78909C)),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF7F9FB),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
    );
  }
}