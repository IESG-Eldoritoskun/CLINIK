import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_colors.dart';
import '../core/supabase_services.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const AssetImage _bannerAsset = AssetImage('assets/abuela.jpeg');

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  late final ImageProvider _bannerImage = const ResizeImage(_bannerAsset, width: 1080);
  bool _obscurePassword = true;
  bool _isLoading = false;
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;

    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Completa correo y contraseña');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await SupabaseServices.signIn(email: email, password: password);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacementNamed('/home');
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('No se pudo iniciar sesión. Intenta de nuevo.');
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTopBanner(),
                      Transform.translate(
                        offset: const Offset(0, -26),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
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
                              _buildSeparator('O inicia sesión con tu cuenta'),
                              const SizedBox(height: 12),
                              _buildBenefitsStrip(),
                              const SizedBox(height: 14),
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
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => _showMessage('Funcionalidad disponible pronto.'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFFF59E0B),
                                  ),
                                  child: const Text(
                                    '¿Olvidaste tu contraseña?',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                height: 52,
                                child: FilledButton(
                                  onPressed: _isLoading ? null : _handleLogin,
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
                                          'Iniciar sesión',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              _buildQuickStatusRow(),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    '¿No tienes una cuenta? ',
                                    style: TextStyle(color: Color(0xFF60717A)),
                                  ),
                                  GestureDetector(
                                    onTap: () => Navigator.of(context).pushNamed('/register'),
                                    child: const Text(
                                      'Regístrate',
                                      style: TextStyle(
                                        color: Color(0xFFF59E0B),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildSecurityNote(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
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
                          const Color(0xFF0E5D59).withValues(alpha: 0.62),
                          const Color(0xFF0A4A47).withValues(alpha: 0.82),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: -130,
              left: -90,
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
              left: 18,
              right: 18,
              bottom: 30,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¡Bienvenido de nuevo!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 31,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tu información de salud está lista para continuar.',
                    style: TextStyle(
                      color: Color(0xFFD9E5EA),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
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
          onTap: () => _showMessage('Inicio con Apple no disponible por ahora.'),
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
          onTap: () => _showMessage('Inicio con Google no disponible por ahora.'),
        ),
        const SizedBox(width: 12),
        _socialButton(
          icon: Icons.facebook,
          iconColor: const Color(0xFF1877F2),
          onTap: () => _showMessage('Inicio con Facebook no disponible por ahora.'),
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

  Widget _buildBenefitsStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F9F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _MiniFeature(icon: Icons.monitor_heart_outlined, label: 'Monitoreo'),
          _MiniFeature(icon: Icons.medication_outlined, label: 'Tratamientos'),
          _MiniFeature(icon: Icons.analytics_outlined, label: 'IA clinica'),
        ],
      ),
    );
  }

  Widget _buildQuickStatusRow() {
    return Row(
      children: const [
        Expanded(
          child: _InfoPill(
            icon: Icons.bolt,
            title: 'Ingreso rapido',
            subtitle: 'Menos de 10 segundos',
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _InfoPill(
            icon: Icons.verified_user_outlined,
            title: 'Cuenta segura',
            subtitle: 'Protección activa',
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF4D69B)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_moon_outlined, size: 18, color: Color(0xFFB7791F)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tus datos de salud se usan solo para seguimiento y atención dentro de CLINIK.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF8A5A14),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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

class _MiniFeature extends StatelessWidget {
  const _MiniFeature({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Color(0xFF1E6B67)),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF49616D),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF1E6B67)),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF294752),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF75909A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}