import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/app_colors.dart';

class MedicalHistoryScreen extends StatefulWidget {
  final String curp;
  final String nss;

  const MedicalHistoryScreen({
    super.key,
    required this.curp,
    required this.nss,
  });

  @override
  State<MedicalHistoryScreen> createState() => _MedicalHistoryScreenState();
}

class _MedicalHistoryScreenState extends State<MedicalHistoryScreen> {
  bool _isExporting = false;

  Future<void> _generateAndSaveDocument() async {
    if (_isExporting) {
      return;
    }

    setState(() => _isExporting = true);

    try {
      final pdf = await _buildPdfDocument();
      final bytes = await pdf.save();
      final fileName = 'historial_medico_maria_lopez.pdf';
      await Printing.sharePdf(bytes: bytes, filename: fileName);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Documento generado. Puedes guardarlo o compartirlo desde el panel del sistema.'),
        ),
      );
    } on MissingPluginException catch (error) {
      debugPrint('Plugin faltante al generar historial medico: $error');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reinicia la app completamente para activar la exportacion del documento.'),
        ),
      );
    } catch (error) {
      debugPrint('Error al generar historial medico: $error');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo generar el historial médico.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<pw.Document> _buildPdfDocument() async {
    final baseFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();
    final document = pw.Document();
    final generatedAt = DateTime.now();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: baseFont,
          bold: boldFont,
        ),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('F2FBFA'),
              borderRadius: pw.BorderRadius.circular(16),
              border: pw.Border.all(color: PdfColor.fromHex('D6EEEA')),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'CLINIK',
                  style: pw.TextStyle(
                    fontSize: 12,
                    font: boldFont,
                    color: PdfColor.fromHex('0D9488'),
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Historial medico del paciente',
                  style: pw.TextStyle(
                    fontSize: 22,
                    font: boldFont,
                    color: PdfColor.fromHex('0F172A'),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Generado el ${_formatDate(generatedAt)}',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          _buildPdfSection(
            title: 'Datos de identificacion',
            boldFont: boldFont,
            rows: [
              ['Nombre', 'Maria Lopez'],
              ['Edad', '58 anos'],
              ['CURP', widget.curp.isEmpty ? 'No registrado' : widget.curp],
              ['NSS', widget.nss.isEmpty ? 'No registrado' : widget.nss],
            ],
          ),
          pw.SizedBox(height: 16),
          _buildPdfSection(
            title: 'Informacion medica',
            boldFont: boldFont,
            rows: const [
              ['Diagnosticos', 'Diabetes tipo 2, Hipertension'],
              ['Medico tratante', 'Dr. Carlos Mendoza'],
              ['Centro de salud', 'Centro de Salud Morelia'],
              ['Medicamento actual', 'Metformina 850 mg'],
            ],
          ),
          pw.SizedBox(height: 16),
          _buildPdfSection(
            title: 'Lecturas y seguimiento',
            boldFont: boldFont,
            rows: const [
              ['Glucosa reciente', '105 mg/dL - Hoy 08:30'],
              ['Presion reciente', '120/80 mmHg - Hoy 08:35'],
              ['Nutricion', '89% de adherencia diaria'],
              ['Actividad', 'Caminata ligera registrada'],
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('FFF8E8'),
              borderRadius: pw.BorderRadius.circular(12),
              border: pw.Border.all(color: PdfColor.fromHex('F5D68A')),
            ),
            child: pw.Text(
              'Documento generado desde la app Clinik para consulta y seguimiento clinico. Este resumen no sustituye una valoracion medica profesional.',
              style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
            ),
          ),
        ],
      ),
    );

    return document;
  }

  pw.Widget _buildPdfSection({
    required String title,
    required pw.Font boldFont,
    required List<List<String>> rows,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(14),
        border: pw.Border.all(color: PdfColor.fromHex('E5E7EB')),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 14,
              font: boldFont,
              color: PdfColor.fromHex('0F172A'),
            ),
          ),
          pw.SizedBox(height: 10),
          ...rows.map(
            (row) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 120,
                    child: pw.Text(
                      row[0],
                      style: pw.TextStyle(
                        fontSize: 11,
                        font: boldFont,
                        color: PdfColor.fromHex('4B5563'),
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      row[1],
                      style: const pw.TextStyle(
                        fontSize: 11,
                        lineSpacing: 3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.prussianBlue),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Historial médico',
          style: TextStyle(
            color: AppColors.prussianBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(15, 23, 42, 0.05),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CLINIK',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                                letterSpacing: 1.2,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Resumen clínico del paciente',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.prussianBlue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Actualizado hoy',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF166534),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Divider(height: 1),
                    const SizedBox(height: 18),
                    const Text(
                      'Datos de identificación',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.prussianBlue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDataRow('Nombre', 'María López'),
                    _buildDataRow('Edad', '58 años'),
                    _buildDataRow('CURP', widget.curp.isEmpty ? 'No registrado' : widget.curp),
                    _buildDataRow('NSS', widget.nss.isEmpty ? 'No registrado' : widget.nss),
                    const SizedBox(height: 18),
                    const Text(
                      'Información médica',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.prussianBlue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDataRow('Diagnósticos', 'Diabetes tipo 2, Hipertensión'),
                    _buildDataRow('Médico tratante', 'Dr. Carlos Mendoza'),
                    _buildDataRow('Centro de salud', 'Centro de Salud Morelia'),
                    _buildDataRow('Medicamento actual', 'Metformina 850 mg'),
                    const SizedBox(height: 18),
                    const Text(
                      'Lecturas y seguimiento',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.prussianBlue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDataRow('Glucosa reciente', '105 mg/dL · Hoy 08:30'),
                    _buildDataRow('Presión reciente', '120/80 mmHg · Hoy 08:35'),
                    _buildDataRow('Nutrición', '89% de adherencia diaria'),
                    _buildDataRow('Actividad', 'Caminata ligera registrada'),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.aliceBlue.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Documento resumido para consulta rápida y seguimiento clínico. Puede usarse como base para una futura exportación en PDF.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.prussianBlue,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isExporting ? null : _generateAndSaveDocument,
                  icon: _isExporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(
                    _isExporting ? 'Generando...' : 'Generar documento',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useVerticalLayout = constraints.maxWidth < 340;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: useVerticalLayout
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.prussianBlue,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.prussianBlue,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}