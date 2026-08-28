import 'package:flutter_test/flutter_test.dart';
import 'package:jubicare_mmu/services/symptom_catalog.dart';

void main() {
  test('user dictation probe', () {
    const text =
        'Sir, हमने counselor को भी बताया था कि मेरे पेट में बहुत दर्द होता है '
        'और मुझे बहुत घबराहट भी लगती है. बहुत बेचैनी सी रहती है.';
    print('MAIN: ${SymptomCatalog.match(text)}');
    print('sar-dard: ${SymptomCatalog.match('सर दर्द हो रहा है')}');
    print('kamar-leg: ${SymptomCatalog.match('कमर में दर्द है और पैरों में दर्द होता है')}');
    print('fever-cough: ${SymptomCatalog.match('बुखार है और खांसी भी')}');
  });
}
