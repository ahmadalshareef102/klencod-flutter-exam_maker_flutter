import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'models.dart';

enum Kind { student, key, omr }

class PdfBuilder {
  static String _n(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  static Future<Uint8List> build(Exam e, Kind kind) async {
    final reg = pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Bold.ttf'));
    final doc = pw.Document();
    final people = (e.students.isEmpty || kind == Kind.key) ? [Student('', '', '')] : e.students;
    for (final s in people) {
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: reg, bold: bold),
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(26),
        build: (c) => kind == Kind.omr ? _omr(e, s) : _exam(e, s, kind == Kind.key),
      ));
    }
    return doc.save();
  }

  static pw.Widget _head(Exam e, Student s, String title) {
    final left = [
      'الصف: ${e.grade}', 'المادة: ${e.subject}', 'التاريخ: ${e.date}',
      'الزمن: ${e.duration}', 'الفترة: ${e.period}'
    ];
    return pw.Column(children: [
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('اسم الطالب: ${s.name.isEmpty ? '.' * 45 : s.name}'),
        pw.Text('رقم الجلوس: [ ${s.seat.isEmpty ? '.' * 10 : s.seat} ]'),
      ]),
      pw.SizedBox(height: 6),
      pw.Container(
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 1.6)),
        padding: const pw.EdgeInsets.all(6),
        child: pw.Column(children: [
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(
                flex: 4,
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: e.rightLines.split('\n').map((l) => pw.Text(l, style: const pw.TextStyle(fontSize: 9))).toList())),
            pw.Expanded(
                flex: 2,
                child: pw.Column(children: [
                  pw.Text('بسم الله الرحمن الرحيم', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  if (s.seat.isNotEmpty)
                    pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 4),
                        child: pw.BarcodeWidget(
                            barcode: pw.Barcode.qrCode(), data: '${e.id}|${s.seat}|${s.secret}', width: 48, height: 48)),
                ])),
            pw.Expanded(
                flex: 3,
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: left.map((l) => pw.Text(l, style: const pw.TextStyle(fontSize: 9))).toList())),
          ]),
          pw.SizedBox(height: 6),
          pw.Container(
              width: double.infinity,
              color: PdfColors.grey200,
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              alignment: pw.Alignment.center,
              child: pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
        ]),
      ),
      pw.SizedBox(height: 10),
    ]);
  }

  static List<pw.Widget> _exam(Exam e, Student s, bool key) {
    final title = key ? '${e.title} (نموذج الإجابة وتوزيع الدرجات)' : e.title;
    final rows = <pw.TableRow>[
      pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.grey200), children: [
        _cell(pw.Text('السؤال', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), center: true),
        _cell(pw.Text('أجب عن جميع الأسئلة الآتية', style: pw.TextStyle(color: PdfColors.red800, fontWeight: pw.FontWeight.bold)), center: true),
        _cell(pw.Text('الدرجة', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), center: true),
      ])
    ];
    for (var i = 0; i < e.qs.length; i++) {
      final q = e.qs[i];
      final lines = q.body.split('\n').where((l) => l.trim().isNotEmpty).toList();
      pw.Widget body;
      if (q.twoCols && lines.length > 1) {
        final h = (lines.length / 2).ceil();
        pw.Widget col(List<String> l) => pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: l.map((t) => pw.Padding(padding: const pw.EdgeInsets.only(bottom: 3), child: pw.Text(t))).toList()));
        body = pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [col(lines.sublist(0, h)), col(lines.sublist(h))]);
      } else {
        body = pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: lines.map((t) => pw.Padding(padding: const pw.EdgeInsets.only(bottom: 3), child: pw.Text(t))).toList());
      }
      rows.add(pw.TableRow(children: [
        _cell(pw.Text('السؤال ${i + 1}'), center: true),
        _cell(pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          if (q.prompt.isNotEmpty) pw.Text(q.prompt, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          body,
          if (key && q.answer.trim().isNotEmpty)
            pw.Container(
                margin: const pw.EdgeInsets.only(top: 6),
                padding: const pw.EdgeInsets.all(5),
                width: double.infinity,
                decoration: pw.BoxDecoration(color: PdfColors.blue50, border: pw.Border.all(color: PdfColors.blue700, width: .8)),
                child: pw.Text('الإجابة النموذجية: ${q.answer}', style: const pw.TextStyle(color: PdfColors.blue900))),
        ])),
        _cell(pw.Text('${_n(q.marks)} د'), center: true),
      ]));
    }
    return [
      _head(e, s, title),
      pw.Table(
        border: pw.TableBorder.all(width: .8),
        columnWidths: {0: const pw.FixedColumnWidth(62), 1: const pw.FlexColumnWidth(), 2: const pw.FixedColumnWidth(48)},
        children: rows,
      ),
      pw.SizedBox(height: 14),
      pw.Center(child: pw.Text(key ? 'المجموع: ${_n(e.total)} د' : e.closing, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
      pw.SizedBox(height: 6),
      pw.Text(key ? 'المصحح / المراجع: ......................' : e.teacher),
    ];
  }

  static pw.Widget _cell(pw.Widget child, {bool center = false}) => pw.Padding(
      padding: const pw.EdgeInsets.all(5), child: center ? pw.Center(child: child) : child);

  static List<pw.Widget> _omr(Exam e, Student s) {
    const letters = ['أ', 'ب', 'ج', 'د'];
    pw.Widget bubble(String l) => pw.Container(
        margin: const pw.EdgeInsets.symmetric(horizontal: 4),
        width: 20, height: 20, alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(shape: pw.BoxShape.circle, border: pw.Border.all(width: .9)),
        child: pw.Text(l, style: const pw.TextStyle(fontSize: 9)));
    final rows = List.generate(
        e.omrCount,
        (i) => pw.Container(
            width: 230, margin: const pw.EdgeInsets.only(bottom: 7),
            child: pw.Row(children: [
              pw.SizedBox(width: 28, child: pw.Text('${i + 1}')),
              ...letters.map(bubble),
            ])));
    return [
      _head(e, s, '${e.title} - ورقة الإجابة (OMR)'),
      pw.Text('ظلّل الدائرة المناسبة بقلم أسود بالكامل، ولا تشطب أو تظلّل أكثر من دائرة في السؤال.',
          style: const pw.TextStyle(fontSize: 9)),
      pw.SizedBox(height: 8),
      pw.Wrap(spacing: 20, children: rows),
    ];
  }
}
