import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ArabicPdfFonts {
  ArabicPdfFonts({
    required this.regular,
    required this.bold,
  })  : latin = pw.Font.helvetica(),
        latinBold = pw.Font.helveticaBold();

  final pw.Font regular;
  final pw.Font bold;
  final pw.Font latin;
  final pw.Font latinBold;
}

Future<ArabicPdfFonts> loadArabicPdfFonts() async {
  final regularData = await rootBundle.load(
    'assets/fonts/NotoNaskhArabic-Regular.ttf',
  );
  final boldData = await rootBundle.load(
    'assets/fonts/NotoNaskhArabic-Bold.ttf',
  );

  return ArabicPdfFonts(
    regular: pw.Font.ttf(ByteData.sublistView(regularData)),
    bold: pw.Font.ttf(ByteData.sublistView(boldData)),
  );
}

pw.ThemeData arabicPdfTheme(ArabicPdfFonts fonts) => pw.ThemeData.withFont(
      base: fonts.regular,
      bold: fonts.bold,
    );

pw.TextStyle arabicPdfTextStyle(
  ArabicPdfFonts fonts, {
  double fontSize = 10,
  bool bold = false,
  PdfColor? color,
}) =>
    pw.TextStyle(
      font: bold ? fonts.bold : fonts.regular,
      fontBold: fonts.bold,
      fontFallback: [fonts.latin, fonts.latinBold],
      fontSize: fontSize,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: color,
      lineSpacing: 1.5,
    );

pw.Widget arabicPdfText(
  String text,
  ArabicPdfFonts fonts, {
  double fontSize = 10,
  bool bold = false,
  PdfColor? color,
  pw.TextAlign textAlign = pw.TextAlign.right,
}) =>
    pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Text(
        cleanPdfText(text),
        textDirection: pw.TextDirection.rtl,
        textAlign: textAlign,
        style: arabicPdfTextStyle(
          fonts,
          fontSize: fontSize,
          bold: bold,
          color: color,
        ),
      ),
    );

String cleanPdfText(Object? value) {
  if (value == null) return '';

  var text = value
      .toString()
      .replaceAll('\u00A0', ' ')
      .replaceAll('↔', ' - ')
      .replaceAll('→', ' - ')
      .replaceAll('←', ' - ')
      .replaceAll('✓', 'نعم')
      .replaceAll('✔', 'نعم')
      .replaceAll('✗', 'لا')
      .replaceAll('✘', 'لا')
      .replaceAll('•', '-')
      .replaceAll('—', '-')
      .replaceAll('–', '-')
      .replaceAll('…', '...');

  text = text.replaceAll(
    RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]'),
    ' ',
  );
  text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
  text = text.replaceAll(RegExp(r' *\n *'), '\n');
  return text.trim();
}
