import '../counsellor/cdata.dart';

/// Doctor clinical knowledge base (ported from doctor.html DISEASE_DB):
/// per-disease symptom weights, tests, suggested Rx, red flags, first-line.
class DRx {
  final String name, days, interval;
  final int qty;
  const DRx(this.name, this.days, this.interval, this.qty);
}

/// A test from the clinical database.
/// [sourceText] is the advisory's own phrasing (shown in the card).
/// [masterName] is the DB-master display name (used when Apply adds to
/// Investigations). Empty [masterName] → this test is skipped on Apply.
class DTest {
  final String sourceText;
  final String masterName;
  const DTest(this.sourceText, this.masterName);
  /// Convenience for the built-in fallback where both names are the same.
  const DTest.same(String name) : sourceText = name, masterName = name;
}

class DPlan {
  final Map<String, int> symptoms;
  final List<DTest> tests;
  final List<DRx> rx;
  final List<String> redFlags;
  final String firstLine;
  const DPlan({required this.symptoms, required this.tests, required this.rx, required this.redFlags, required this.firstLine});
}

const Map<String, DPlan> kDoctorDb = {
  'Dengue Fever': DPlan(
    symptoms: {'Fever':3,'Headache':2,'Retro-orbital pain':3,'Rash':2,'Joint pain':2,'Platelet drop':3,'Nausea':1,'Vomiting':1,'Body ache':2,'Fatigue':1},
    tests: [DTest.same('CBC with Platelet count'),DTest.same('NS1 Antigen'),DTest.same('Dengue IgM/IgG')],
    rx: [DRx('Paracetamol 500mg','5','TDS',15), DRx('ORS Sachets','5','TDS',15), DRx('Domperidone 10mg','3','BD',6)],
    redFlags: ['Platelet <20,000','Persistent vomiting','Mucosal bleeding'],
    firstLine: 'Supportive care. Paracetamol for fever. Avoid NSAIDs.'),
  'Malaria': DPlan(
    symptoms: {'Fever':3,'Chills':3,'Sweating':3,'Headache':2,'Body ache':2,'Nausea':1,'Fatigue':2,'Jaundice':2},
    tests: [DTest.same('Malaria Smear'),DTest.same('RDT'),DTest.same('CBC')],
    rx: [DRx('ACT (Artesunate+Lumefantrine)','3','BD',6), DRx('Paracetamol 500mg','3','TDS',9), DRx('Primaquine 15mg','14','OD',14)],
    redFlags: ['Altered consciousness','Severe anaemia','Respiratory distress'],
    firstLine: 'ACT first-line. Primaquine for P.vivax.'),
  'Typhoid': DPlan(
    symptoms: {'Fever':3,'Headache':2,'Abdominal pain':3,'Diarrhoea':2,'Loss of appetite':2,'Fatigue':2,'Nausea':1,'Body ache':1},
    tests: [DTest.same('Widal Test'),DTest.same('Blood Culture'),DTest.same('CBC')],
    rx: [DRx('Azithromycin 500mg','7','OD',7), DRx('Paracetamol 500mg','5','TDS',15), DRx('ORS Sachets','5','TDS',15)],
    redFlags: ['GI perforation','Persistent high fever >7 days'],
    firstLine: 'Azithromycin first-line. Adequate hydration.'),
  'Viral Fever': DPlan(
    symptoms: {'Fever':3,'Headache':2,'Body ache':2,'Fatigue':2,'Runny nose':1,'Sore throat':1,'Cough':1,'Chills':1,'Weakness':1},
    tests: [DTest.same('CBC'),DTest.same('CRP')],
    rx: [DRx('Paracetamol 500mg','3','TDS',9), DRx('Cetirizine 10mg','3','OD',3), DRx('ORS Sachets','3','BD',6)],
    redFlags: ['Fever >5 days','Rash development','Platelet drop'],
    firstLine: 'Symptomatic. Paracetamol, rest, fluids.'),
  'URTI': DPlan(
    symptoms: {'Cough':3,'Sore throat':3,'Runny nose':3,'Fever':2,'Headache':1,'Body ache':1,'Fatigue':1},
    tests: [DTest.same('Throat swab'),DTest.same('CBC')],
    rx: [DRx('Cetirizine 10mg','5','OD',5), DRx('Paracetamol 500mg','3','TDS',9), DRx('Ambroxol 30mg','5','BD',10)],
    redFlags: ['Stridor','Unable to swallow','Neck stiffness'],
    firstLine: 'Antihistamine, warm fluids, steam inhalation.'),
  'Pneumonia': DPlan(
    symptoms: {'Fever':3,'Cough':3,'Shortness of breath':3,'Chest pain':2,'Fatigue':2,'Chills':2,'Wheezing':1},
    tests: [DTest.same('Chest X-ray'),DTest.same('CBC'),DTest.same('Sputum culture')],
    rx: [DRx('Amoxicillin 500mg','7','TDS',21), DRx('Paracetamol 500mg','5','TDS',15)],
    redFlags: ['SpO2 <92%','Resp rate >30','Confusion'],
    firstLine: 'Amoxicillin first-line.'),
  'Gastroenteritis': DPlan(
    symptoms: {'Diarrhoea':3,'Vomiting':3,'Abdominal pain':2,'Nausea':2,'Fever':1,'Dehydration':3},
    tests: [DTest.same('Stool exam'),DTest.same('CBC'),DTest.same('Electrolytes')],
    rx: [DRx('ORS Sachets','5','TDS',15), DRx('Zinc 20mg','14','OD',14), DRx('Ondansetron 4mg','3','BD',6)],
    redFlags: ['Severe dehydration','Bloody diarrhoea'],
    firstLine: 'ORS and zinc. Ondansetron for vomiting.'),
  'Chikungunya': DPlan(
    symptoms: {'Fever':3,'Joint pain':3,'Rash':2,'Headache':2,'Fatigue':2,'Body ache':2,'Swelling':2},
    tests: [DTest.same('Chikungunya IgM'),DTest.same('CBC')],
    rx: [DRx('Paracetamol 500mg','5','TDS',15), DRx('ORS Sachets','5','BD',10)],
    redFlags: ['Hemorrhagic signs','Encephalitis'],
    firstLine: 'Supportive care. Paracetamol.'),
  'UTI': DPlan(
    symptoms: {'Burning micturition':3,'Frequent urination':3,'Lower abdominal pain':2,'Fever':2,'Blood in urine':2},
    tests: [DTest.same('Urine R/E'),DTest.same('Urine Culture'),DTest.same('CBC')],
    rx: [DRx('Nitrofurantoin 100mg','5','BD',10), DRx('Paracetamol 500mg','3','TDS',9)],
    redFlags: ['High fever with flank pain','Persistent haematuria'],
    firstLine: 'Nitrofurantoin first-line. Hydration.'),
  'Hypertension': DPlan(
    symptoms: {'Headache':2,'Dizziness':2,'Chest pain':1,'Palpitations':2,'Shortness of breath':1,'Fatigue':1},
    tests: [DTest.same('BP Monitoring'),DTest.same('ECG'),DTest.same('Lipid Profile')],
    rx: [DRx('Amlodipine 5mg','30','OD',30), DRx('Telmisartan 40mg','30','OD',30)],
    redFlags: ['BP >180/120','Chest pain','Visual changes'],
    firstLine: 'Amlodipine or Telmisartan. Lifestyle modification.'),
  'Diabetes Type 2': DPlan(
    symptoms: {'Frequent urination':2,'Fatigue':2,'Weight loss':2,'Weakness':1,'Numbness':2},
    tests: [DTest.same('Fasting Blood Sugar'),DTest.same('HbA1c'),DTest.same('Renal Profile')],
    rx: [DRx('Metformin 500mg','30','BD',60), DRx('Glimepiride 1mg','30','OD',30)],
    redFlags: ['Blood sugar >400','Ketoacidosis','Non-healing wounds'],
    firstLine: 'Metformin first-line. Lifestyle modification.'),
};

const List<String> kLabTests = ['CBC','Lipid Profile','Kidney Profile','Liver Profile','B.sugar','HB','ESR','Blood Group','Urine R/E','Dengue Test','Malaria Smear','ECG','X-Ray','NS1 Antigen','ANC Profile','Stool Test','Platelets Count','CRP','HbA1c'];

const List<String> kMedicines = ['T.Paracetamol 500','T.Paracetamol 650','T.Cetirizine 10mg','T.Calcium','T.Ciprofloxacin 500','T.Doxycycline 100','T.Ofloxacin 200','T.Metronidazole 400','T.Cefixime 200mg','Cap.Pantoprazole 40','T.Domperidone 10mg','T.Amlodipine 5mg','T.Metformin 500','T.B-Complex','T.IFA','T.Azithromycin 500','T.Amoxicillin 500','ORS Sachets','Syp.Amoxycillin','Syp.Cefixime','Syp.PCM','Syp.Cetirizine','E/d.Ciplox','Oint.Betadine','Cream Clotrimazole','Lotion Calamine','Tab.Telmisartan 40mg','Cap.Vitamin D3 60000 IU','Zinc 20mg','Nitrofurantoin 100mg','Ondansetron 4mg','Ambroxol 30mg'];

/// Medicine NAMES only (no strength/dosage) — dosage is typed by the doctor.
const List<String> kMedicineNames = [
  'Paracetamol','Ibuprofen','Diclofenac','Aceclofenac','Cetirizine','Levocetirizine',
  'Chlorpheniramine','Montelukast','Amoxicillin','Amoxicillin-Clavulanate','Azithromycin',
  'Cefixime','Ciprofloxacin','Ofloxacin','Doxycycline','Metronidazole','Albendazole',
  'ORS Sachets','Zinc','Pantoprazole','Omeprazole','Domperidone','Ondansetron',
  'Ambroxol','Dextromethorphan Syrup','Salbutamol Inhaler','Amlodipine','Telmisartan',
  'Metformin','Glimepiride','Ferrous Sulphate + Folic Acid','Vitamin C','Vitamin D3',
  'Multivitamin','Calcium','Nitrofurantoin','B-Complex','Betadine Gargle',
];

// 'HS' (hora somni — at bedtime) removed from the picker per user rule
// 2026-08-16. The value stays a valid frequency if a legacy row carries
// it — validation only rejects picks the doctor makes now.
const List<String> kFrequencies = ['OD','BD','TDS','QID','SOS'];
/// Dosage form options rendered right of the Dosage field in the
/// doctor's prescription row (user 2026-09-08). Kept short so a long
/// facility name never clips the picker. Backend has no dedicated
/// column — the value round-trips as a "<form> · " prefix on the
/// PrescriptionItem.dosage column (see RxItem.dosageForm).
const List<String> kDosageForms = ['Tab', 'Cap', 'Syp', 'Gel', 'Cream'];

/// Solid forms count as pieces (Tab / Cap) — a per-dose quantity makes
/// sense, so the auto-QTY box is shown. Syrup / Gel / Cream are
/// dispensed by volume or by tube, not by tablet count, so the QTY
/// field is hidden for those forms (user 2026-09-14).
bool dosageFormNeedsQty(String form) =>
    form.isEmpty || form == 'Tab' || form == 'Cap';
const String kDosageFormSep = ' · ';

/// Split a stored dosage string into (form, strength).
/// "Tab · 500 mg"       -> ("Tab", "500 mg")
/// "500 mg"             -> ("",    "500 mg")     ← old rows, no prefix
/// "SomethingElse · X"  -> ("",    "SomethingElse · X") ← unknown prefix kept as-is
/// The prefix must match one of [kDosageForms] exactly; otherwise the
/// whole string is treated as plain strength, so an older prescription
/// that already used " · " for its own purposes is not misread.
({String form, String strength}) parseDosage(String stored) {
  final ix = stored.indexOf(kDosageFormSep);
  if (ix <= 0) return (form: '', strength: stored);
  final head = stored.substring(0, ix).trim();
  if (!kDosageForms.contains(head)) return (form: '', strength: stored);
  return (form: head, strength: stored.substring(ix + kDosageFormSep.length).trim());
}
/// The unit a dosage form is measured in. Tab / Cap are counted in mg;
/// Syp / Gel / Cream are measured in ml.
String doseUnitFor(String form) => dosageFormNeedsQty(form) ? 'mg' : 'ml';

/// True when [strength] already carries its own unit, so appending one
/// would read "500 mg mg". Covers rows typed before the unit became
/// automatic, and master-derived strings like "100 mg".
final RegExp _kHasUnit = RegExp(r'(mg|ml|mcg|iu|g)', caseSensitive: false);

/// Render a bare strength with the unit its form implies.
/// ("500", "Tab")   -> "500 mg"
/// ("100", "Syp")   -> "100 ml"
/// ("500 mg", "Tab")-> "500 mg"   ← already carries a unit, left alone
/// ("", anything)   -> ""
///
/// The doctor and the pharmacist both type a bare number now — the form
/// dropdown decides the unit and every screen appends it from here, so
/// the unit is never stored and never has to be typed (user 2026-09-22
/// "if we dont take mg or ml we will show automatic mg ml where need").
String strengthWithUnit(String strength, String form) {
  final s = strength.trim();
  if (s.isEmpty) return '';
  if (_kHasUnit.hasMatch(s)) return s;
  return '$s ${doseUnitFor(form)}';
}

/// The inverse: the number on its own, for putting INTO the Dosage box.
/// "100 mg" -> "100";  "2.5 ml" -> "2.5";  "500" -> "500";  "" -> ""
///
/// Everything above renders a bare strength for DISPLAY. The box the doctor
/// types into is the other direction and had nothing doing it, so a strength
/// that arrived carrying its unit went straight in as text: a Frequently
/// Prescribed chip is built from past prescriptions and offers "Paracetamol ·
/// 100 mg", an advisory plan's splitMedicine() returns "100 mg", and older
/// rows were stored that way. The result read "100 mg" inside a box captioned
/// DOSAGE (MG) — which also refuses non-digits as you type, so the doctor had
/// to clear it before they could correct it (user 2026-09-26: "i choose tab,
/// in dosage why taking 100 mg").
///
/// Anything with no number in it is handed back untouched rather than
/// emptied, so a free-text strength is not silently thrown away.
String bareStrength(String strength) {
  final s = strength.trim();
  if (s.isEmpty) return '';
  return RegExp(r'\d+(?:\.\d+)?').firstMatch(s)?.group(0) ?? s;
}

/// Render a STORED dosage column ("Tab · 500" or a bare "500") for
/// display, keeping the form prefix and adding the implied unit:
/// "Tab · 500" -> "Tab · 500 mg";  "Cream · 20" -> "Cream · 20 ml".
String displayDosage(String stored) {
  final parsed = parseDosage(stored);
  final withUnit = strengthWithUnit(parsed.strength, parsed.form);
  if (withUnit.isEmpty) return stored.trim();
  return parsed.form.isEmpty ? withUnit : '${parsed.form}$kDosageFormSep$withUnit';
}

const List<String> kDurations = ['3','5','7','10 Days','14','30'];

/// Score likely conditions from chosen symptoms + block geo prior.
/// Advisory scoring (user spec 2026-08-14). Three signals per disease:
///  1. SELECTED symptoms — full weight (explicit clinical input).
///  2. OBSERVATION keywords — the doctor's dictated/typed observation is
///     scanned for the disease's symptom terms; matches score at HALF
///     weight (mentioned, but not formally selected). Terms already
///     selected aren't double-counted.
///  3. VILLAGE trend — diagnoses actually reported in THIS patient's
///     village (from the synced queue rows) boost proportionally, up to
///     +18 for the village's most common diagnosis. Falls back to the
///     static block prior only when no real village data is loaded.
/// Live clinical DB — starts as the small built-in [kDoctorDb] and is
/// swapped for the full 158-condition assets/kdoctordb.json by
/// DoctorDbLoader.load() (user 2026-08-22 "use this json for AI Clinical
/// Advisory card"). Keyed by both condition name and standardTerm.
Map<String, DPlan> doctorDb = kDoctorDb;

List<ScoredDisease> scoreDoctor(
  List<String> symptoms,
  String? block, {
  String observation = '',
  Map<String, int> villageDx = const {},
}) {
  final geo = kGeoDb[block] ?? kGeoDb['Gajraula']!;
  final obs = observation.toLowerCase();
  final maxVillage = villageDx.values.fold<int>(0, (m, v) => v > m ? v : m);
  final res = <ScoredDisease>[];
  doctorDb.forEach((name, plan) {
    var sc = 0.0;
    var mx = 0;
    for (final s in symptoms) {
      sc += plan.symptoms[s] ?? 0;
    }
    if (obs.trim().isNotEmpty) {
      plan.symptoms.forEach((term, w) {
        if (!symptoms.contains(term) && obs.contains(term.toLowerCase())) {
          sc += w * 0.5;
        }
      });
    }
    for (final v in plan.symptoms.values) {
      mx += v;
    }
    var pct = mx > 0 ? (sc / mx * 100).round() : 0;
    if (maxVillage > 0) {
      final seen = villageDx[name] ?? 0;
      if (seen > 0) pct = (pct + (18 * seen / maxVillage).round()).clamp(0, 98);
    } else if (geo.diseases.any((d) => d.name == name)) {
      pct = (pct + 15).clamp(0, 98);
    }
    if (pct >= 10) res.add(ScoredDisease(name, pct, pct >= 60 ? 'h' : (pct >= 35 ? 'm' : 'l')));
  });
  res.sort((a, b) => b.pct.compareTo(a.pct));
  return res.take(6).toList();
}
