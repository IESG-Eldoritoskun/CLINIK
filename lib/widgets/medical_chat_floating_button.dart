import 'package:flutter/material.dart';

class MedicalChatFloatingButton extends StatelessWidget {
  const MedicalChatFloatingButton({super.key});

  void _openMedicalChat(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const DoctorChatSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => _openMedicalChat(context),
      backgroundColor: const Color(0xFF00685F),
      elevation: 6,
      icon: const Stack(
        children: [
          Icon(Icons.chat_bubble_outline, color: Colors.white, size: 26),
          Positioned(
            right: 0,
            top: 0,
            child: CircleAvatar(
              radius: 4,
              backgroundColor: Color(0xFF6FFBBE),
            ),
          ),
        ],
      ),
      label: const Text(
        'Dr. Mendoza',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}

class DoctorChatSheet extends StatefulWidget {
  const DoctorChatSheet({super.key});

  @override
  State<DoctorChatSheet> createState() => _DoctorChatSheetState();
}

class _DoctorChatSheetState extends State<DoctorChatSheet> {
  final TextEditingController _textController = TextEditingController();
  bool _isPlayingAudio = false;

  void _injectQuickResponse(String text) {
    setState(() {
      _textController.text = text;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Container(
      height: mediaQuery.size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFFFAF8FF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Scaffold(
          backgroundColor: const Color(0xFFFAF8FF),
          appBar: _buildHeader(context),
          body: Column(
            children: [
              _buildClinicalRecordBanner(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildDateDivider('Hoy, 7 de septiembre'),
                    const SizedBox(height: 12),
                    _buildDoctorMessage(
                      'Hola María, buenos días. He revisado tus lecturas de glucosa de los últimos 7 días y veo una excelente estabilidad en 105 mg/dL en ayuno. ¿Has tenido alguna molestia con la dosis de Metformina?',
                      '09:15',
                    ),
                    const SizedBox(height: 12),
                    _buildPatientMessage(
                      'Buenos días Dr. Mendoza. Me he sentido muy bien, tomé la dosis de la mañana con el desayuno sin inconvenientes. Muchas gracias por estar al pendiente.',
                      '09:18',
                    ),
                    const SizedBox(height: 12),
                    _buildDoctorPrescriptionCard(),
                    const SizedBox(height: 12),
                    _buildAudioNoteTile(),
                  ],
                ),
              ),
              _buildQuickResponses(),
              _buildBottomInputBar(mediaQuery),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildHeader(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      automaticallyImplyLeading: false,
      titleSpacing: 12,
      title: Row(
        children: [
          Stack(
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuAG6ePIktlPLkYnd5yvbYAszWhYcVy8LKE3HUVMM8jn5ga7vdBcFz2551fENMo6V_5gko858CTFa9yy5mGwVCTbvProVa1fcsCwU_nmOKZIBbQs3iZ_Tw0aTlRk5XKztyjTPRzgSseCMJklsNLd0LOIFLhNQNBHOPpbirOqFkOqtjL6vtGrsJFTq8H4kNbATNKoj2r-HJCI3t_b0uppWbaP88uO9MYnGKmede3t59BN5R3QpF7oKVwE',
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF006947),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Dr. Carlos Mendoza',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF131B2E),
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.verified, color: Color(0xFF00685F), size: 16),
                  ],
                ),
                Text(
                  'Medicina Familiar • Morelia',
                  style: TextStyle(fontSize: 11, color: Color(0xFF50616B)),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.videocam, color: Color(0xFF00685F)),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF131B2E)),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildClinicalRecordBanner() {
    return Container(
      color: const Color(0xFFD3E5F1).withOpacity(0.4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.folder_shared_outlined, color: Color(0xFF00685F), size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Expediente Clínico Sincronizado',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Última medición: Glucosa 105 mg/dL (Hoy 08:30)',
                  style: TextStyle(fontSize: 11, color: Color(0xFF384953)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateDivider(String label) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFEAEDFF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF50616B)),
        ),
      ),
    );
  }

Widget _buildDoctorMessage(String text, String time) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        // ❌ Antes: maxWidth: 280,
        // ✅ Ahora:
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF131B2E))),
            const SizedBox(height: 4),
            Text(
              '$time • Dr. Mendoza',
              style: const TextStyle(fontSize: 10, color: Color(0xFF50616B)),
            ),
          ],
        ),
      ),
    );
  }
Widget _buildPatientMessage(String text, String time) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        // ❌ Antes: maxWidth: 280,
        // ✅ Ahora:
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: Color(0xFF008378),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(text, style: const TextStyle(fontSize: 13, color: Colors.white)),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(time, style: const TextStyle(fontSize: 10, color: Colors.white70)),
                const SizedBox(width: 4),
                const Icon(Icons.done_all, color: Colors.white70, size: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorPrescriptionCard() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 290,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBCC9C6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.assignment_outlined, color: Color(0xFF00685F)),
                SizedBox(width: 8),
                Text(
                  'Plan de Manejo',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 16),
            const Text(
              'Continuamos con Metformina 500mg por las mañanas y Losartán 50mg a las 14:00. Próxima cita el 12 de septiembre.',
              style: TextStyle(fontSize: 12, color: Color(0xFF3D4947)),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.receipt_long, size: 16),
              label: const Text('Ver detalle de indicación'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD3E5F1),
                foregroundColor: const Color(0xFF384953),
                elevation: 0,
                minimumSize: const Size(double.infinity, 36),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioNoteTile() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            IconButton(
              icon: Icon(_isPlayingAudio ? Icons.pause_circle_filled : Icons.play_circle_fill),
              iconSize: 36,
              color: const Color(0xFF00685F),
              onPressed: () {
                setState(() {
                  _isPlayingAudio = !_isPlayingAudio;
                });
              },
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: 0.3, color: Color(0xFF00685F)),
                  SizedBox(height: 4),
                  Text('0:12 / 0:42 min', style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickResponses() {
    final options = ['👍 Todo en orden', '🩸 Nueva medición', '💊 Preguntar receta'];
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return ActionChip(
            label: Text(options[index], style: const TextStyle(fontSize: 12)),
            backgroundColor: Colors.white,
            onPressed: () => _injectQuickResponse(options[index]),
          );
        },
      ),
    );
  }

  Widget _buildBottomInputBar(MediaQueryData mediaQuery) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: mediaQuery.viewInsets.bottom + 12,
      ),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF00685F)),
            onPressed: () {},
          ),
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: 'Escribe tu consulta...',
                hintStyle: const TextStyle(fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: const Color(0xFFFAF8FF),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: const Color(0xFF00685F),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 18),
              onPressed: () {
                _textController.clear();
              },
            ),
          ),
        ],
      ),
    );
  }
}
