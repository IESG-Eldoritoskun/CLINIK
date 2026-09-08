import 'package:clinik/widgets/medical_chat_floating_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_colors.dart';
import '../screens/medical_history_screen.dart';
import '../core/supabase_services.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Estado de los switches interactivos
  bool _notificationsEnabled = true;
  bool _medRemindersEnabled = true;
  bool _apptRemindersEnabled = true;
  bool _isSigningOut = false;
  final TextEditingController _curpController = TextEditingController();
  final TextEditingController _nssController = TextEditingController();

  @override
  void dispose() {
    _curpController.dispose();
    _nssController.dispose();
    super.dispose();
  }

  Future<void> _handleSignOut() async {
    setState(() => _isSigningOut = true);

    try {
      await SupabaseServices.signOut();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('No se pudo cerrar sesion. Intenta de nuevo.');
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: const MedicalChatFloatingButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HEADER PERFIL
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Mi perfil',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.prussianBlue,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications_none_outlined, size: 28),
                    onPressed: () => Navigator.pushNamed(context, '/medical-followup'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. CARD DE IDENTIDAD DEL PACIENTE
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Stack(
                          children: [
                            const CircleAvatar(
                              radius: 32,
                              backgroundImage: NetworkImage(
                                'https://images.unsplash.com/photo-1544005313-94ddf0286df2?q=80&w=200',
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: AppColors.stable,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'María López',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.prussianBlue,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.aliceBlue,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Paciente con Monitoreo Activo',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.sync, size: 14, color: AppColors.stable),
                        SizedBox(width: 6),
                        Text(
                          'Expediente digital sincronizado',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.stable,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 3. SECCIÓN: MI INFORMACIÓN MÉDICA
              const Text(
                'Mi información médica',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.prussianBlue,
                ),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
                ),
                child: Column(
                  children: [
                    // Edad
                    _buildInfoRow(
                      icon: Icons.cake_outlined,
                      title: 'Edad',
                      value: '58 años',
                    ),
                    const Divider(height: 20),

                    _buildMedicalInputField(
                      icon: Icons.badge_outlined,
                      label: 'CURP (México)',
                      controller: _curpController,
                      hintText: 'Ej. GODE561231HDFRRN09',
                      maxLength: 18,
                      keyboardType: TextInputType.text,
                      inputFormatters: [
                        UpperCaseTextFormatter(),
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildMedicalInputField(
                      icon: Icons.numbers,
                      label: 'NSS (México)',
                      controller: _nssController,
                      hintText: 'Ej. 12345678901',
                      maxLength: 11,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const Divider(height: 20),

                    // Diagnósticos
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.assignment_outlined, size: 20, color: AppColors.primary),
                            SizedBox(width: 12),
                            Text(
                              'Diagnósticos',
                              style: TextStyle(fontSize: 14, color: Colors.black87),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            _buildTag('Diabetes tipo 2'),
                            const SizedBox(width: 6),
                            _buildTag('Hipertensión'),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // Centro de Salud y Médico
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.local_hospital_outlined, size: 20, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Centro de Salud Morelia',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.prussianBlue,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Dr. Carlos Mendoza · Médico tratante',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MedicalHistoryScreen(
                                curp: _curpController.text.trim(),
                                nss: _nssController.text.trim(),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.description_outlined, size: 18),
                        label: const Text(
                          'Generar historial médico',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.prussianBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 4. SECCIÓN: PREFERENCIAS Y RECORDATORIOS
              const Text(
                'Preferencias y recordatorios',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.prussianBlue,
                ),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
                ),
                child: Column(
                  children: [
                    // Switch Notificaciones
                    Material(
                      color: Colors.transparent,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: AppColors.primary,
                        title: const Text(
                          'Notificaciones generales',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.prussianBlue),
                        ),
                        value: _notificationsEnabled,
                        onChanged: (val) => setState(() => _notificationsEnabled = val),
                      ),
                    ),
                    const Divider(height: 12),

                    // Switch Recordatorios de medicamentos
                    Material(
                      color: Colors.transparent,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: AppColors.primary,
                        title: const Text(
                          'Recordatorios de medicamentos',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.prussianBlue),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Wrap(
                            spacing: 6,
                            children: [
                              _buildTimeChip('08:00'),
                              _buildTimeChip('14:00'),
                              _buildTimeChip('20:00'),
                            ],
                          ),
                        ),
                        value: _medRemindersEnabled,
                        onChanged: (val) => setState(() => _medRemindersEnabled = val),
                      ),
                    ),
                    const Divider(height: 12),

                    // Switch Recordatorios de citas
                    Material(
                      color: Colors.transparent,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: AppColors.primary,
                        title: const Text(
                          'Recordatorios de citas médicas',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.prussianBlue),
                        ),
                        subtitle: const Text('Aviso 24 hrs antes', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        value: _apptRemindersEnabled,
                        onChanged: (val) => setState(() => _apptRemindersEnabled = val),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 5. SECCIÓN: SOPORTE Y SEGURIDAD
              const Text(
                'Soporte y seguridad',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.prussianBlue,
                ),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
                ),
                child: Column(
                  children: [
                    // Contacto de emergencia
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFE4E6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.phone_in_talk, color: AppColors.critical, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Contacto de emergencia',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.prussianBlue),
                                ),
                                SizedBox(height: 2),
                                Text('Hijo Carlos · (443) 123-4567', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.call, color: AppColors.primary),
                          onPressed: () {},
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // Privacidad
                    Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.lock_outline, color: AppColors.primary, size: 20),
                        title: const Text('Privacidad y protección de datos', style: TextStyle(fontSize: 14, color: Colors.black87)),
                        subtitle: const Text('Cumplimiento NOM e información protegida', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {},
                      ),
                    ),
                    const Divider(height: 12),

                    // Cambiar PIN
                    Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.fingerprint, color: AppColors.primary, size: 20),
                        title: const Text('Cambiar PIN / Acceso biométrico', style: TextStyle(fontSize: 14, color: Colors.black87)),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // 6. BOTÓN CERRAR SESIÓN
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.critical, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _isSigningOut ? null : _handleSignOut,
                  icon: const Icon(Icons.logout, color: AppColors.critical),
                  label: _isSigningOut
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.critical,
                          ),
                        )
                      : const Text(
                          'Cerrar sesión',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.critical),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // VERSIÓN
              const Center(
                child: Text(
                  'CLINIK v1.0.0 · Versión Hackathon 2026',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // Helpers internos
  Widget _buildInfoRow({required IconData icon, required String title, required String value}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(fontSize: 14, color: Colors.black87)),
          ],
        ),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.prussianBlue)),
      ],
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.aliceBlue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
      ),
    );
  }

  Widget _buildTimeChip(String time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        time,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.prussianBlue),
      ),
    );
  }

  Widget _buildMedicalInputField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required String hintText,
    required int maxLength,
    required TextInputType keyboardType,
    required List<TextInputFormatter> inputFormatters,
  }) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(maxLength),
                      ...inputFormatters,
                    ],
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.prussianBlue,
                    ),
                    decoration: InputDecoration(
                      hintText: hintText,
                      hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                      isDense: true,
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Colors.black.withValues(alpha: 0.08),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Colors.black.withValues(alpha: 0.08),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}