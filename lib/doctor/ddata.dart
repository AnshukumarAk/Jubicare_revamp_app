import '../counsellor/cdata.dart';

/// Doctor clinical knowledge base (ported from doctor.html DISEASE_DB):
/// per-disease symptom weights, tests, suggested Rx, red flags, first-line.
class DRx {
  final String name, days, interval;
  final int qty;
  const DRx(this.name, this.days, this.interval, this.qty);
}

class DPlan {
  final Map<String, int> symptoms;
  final List<String> tests;
  final List<DRx> rx;
  final List<String> redFlags;
  final String firstLine;
  const DPlan({required this.symptoms, required this.tests, required this.rx, required this.redFlags, required this.firstLine});
}

const Map<String, DPlan> kDoctorDb = {
  'Dengue Fever': DPlan(
    symptoms: {'Fever':3,'Headache':2,'Retro-orbital pain':3,'Rash':2,'Joint pain':2,'Platelet drop':3,'Nausea':1,'Vomiting':1,'Body ache':2,'Fatigue':1},
    tests: ['CBC with Platelet count','NS1 Antigen','Dengue IgM/IgG'],
    rx: [DRx('Paracetamol 500mg','5','TDS',15), DRx('ORS Sachets','5','TDS',15), DRx('Domperidone 10mg','3','BD',6)],
    redFlags: ['Platelet <20,000','Persistent vomiting','Mucosal bleeding'],
    firstLine: 'Supportive care. Paracetamol for fever. Avoid NSAIDs.'),
  'Malaria': DPlan(
    symptoms: {'Fever':3,'Chills':3,'Sweating':3,'Headache':2,'Body ache':2,'Nausea':1,'Fatigue':2,'Jaundice':2},
    tests: ['Malaria Smear','RDT','CBC'],
    rx: [DRx('ACT (Artesunate+Lumefantrine)','3','BD',6), DRx('Paracetamol 500mg','3','TDS',9), DRx('Primaquine 15mg','14','OD',14)],
    redFlags: ['Altered consciousness','Severe anaemia','Respiratory distress'],
    firstLine: 'ACT first-line. Primaquine for P.vivax.'),
  'Typhoid': DPlan(
    symptoms: {'Fever':3,'Headache':2,'Abdominal pain':3,'Diarrhoea':2,'Loss of appetite':2,'Fatigue':2,'Nausea':1,'Body ache':1},
    tests: ['Widal Test','Blood Culture','CBC'],
    rx: [DRx('Azithromycin 500mg','7','OD',7), DRx('Paracetamol 500mg','5','TDS',15), DRx('ORS Sachets','5','TDS',15)],
    redFlags: ['GI perforation','Persistent high fever >7 days'],
    firstLine: 'Azithromycin first-line. Adequate hydration.'),
  'Viral Fever': DPlan(
    symptoms: {'Fever':3,'Headache':2,'Body ache':2,'Fatigue':2,'Runny nose':1,'Sore throat':1,'Cough':1,'Chills':1,'Weakness':1},
    tests: ['CBC','CRP'],
    rx: [DRx('Paracetamol 500mg','3','TDS',9), DRx('Cetirizine 10mg','3','OD',3), DRx('ORS Sachets','3','BD',6)],
    redFlags: ['Fever >5 days','Rash development','Platelet drop'],
    firstLine: 'Symptomatic. Paracetamol, rest, fluids.'),
  'URTI': DPlan(
    symptoms: {'Cough':3,'Sore throat':3,'Runny nose':3,'Fever':2,'Headache':1,'Body ache':1,'Fatigue':1},
    tests: ['Throat swab','CBC'],
    rx: [DRx('Cetirizine 10mg','5','OD',5), DRx('Paracetamol 500mg','3','TDS',9), DRx('Ambroxol 30mg','5','BD',10)],
    redFlags: ['Stridor','Unable to swallow','Neck stiffness'],
    firstLine: 'Antihistamine, warm fluids, steam inhalation.'),
  'Pneumonia': DPlan(
    symptoms: {'Fever':3,'Cough':3,'Shortness of breath':3,'Chest pain':2,'Fatigue':2,'Chills':2,'Wheezing':1},
    tests: ['Chest X-ray','CBC','Sputum culture'],
    rx: [DRx('Amoxicillin 500mg','7','TDS',21), DRx('Paracetamol 500mg','5','TDS',15)],
    redFlags: ['SpO2 <92%','Resp rate >30','Confusion'],
    firstLine: 'Amoxicillin first-line.'),
  'Gastroenteritis': DPlan(
    symptoms: {'Diarrhoea':3,'Vomiting':3,'Abdominal pain':2,'Nausea':2,'Fever':1,'Dehydration':3},
    tests: ['Stool exam','CBC','Electrolytes'],
    rx: [DRx('ORS Sachets','5','TDS',15), DRx('Zinc 20mg','14','OD',14), DRx('Ondansetron 4mg','3','BD',6)],
    redFlags: ['Severe dehydration','Bloody diarrhoea'],
    firstLine: 'ORS and zinc. Ondansetron for vomiting.'),
  'Chikungunya': DPlan(
    symptoms: {'Fever':3,'Joint pain':3,'Rash':2,'Headache':2,'Fatigue':2,'Body ache':2,'Swelling':2},
    tests: ['Chikungunya IgM','CBC'],
    rx: [DRx('Paracetamol 500mg','5','TDS',15), DRx('ORS Sachets','5','BD',10)],
    redFlags: ['Hemorrhagic signs','Encephalitis'],
    firstLine: 'Supportive care. Paracetamol.'),
  'UTI': DPlan(
    symptoms: {'Burning micturition':3,'Frequent urination':3,'Lower abdominal pain':2,'Fever':2,'Blood in urine':2},
    tests: ['Urine R/E','Urine Culture','CBC'],
    rx: [DRx('Nitrofurantoin 100mg','5','BD',10), DRx('Paracetamol 500mg','3','TDS',9)],
    redFlags: ['High fever with flank pain','Persistent haematuria'],
    firstLine: 'Nitrofurantoin first-line. Hydration.'),
  'Hypertension': DPlan(
    symptoms: {'Headache':2,'Dizziness':2,'Chest pain':1,'Palpitations':2,'Shortness of breath':1,'Fatigue':1},
    tests: ['BP Monitoring','ECG','Lipid Profile'],
    rx: [DRx('Amlodipine 5mg','30','OD',30), DRx('Telmisartan 40mg','30','OD',30)],
    redFlags: ['BP >180/120','Chest pain','Visual changes'],
    firstLine: 'Amlodipine or Telmisartan. Lifestyle modification.'),
  'Diabetes Type 2': DPlan(
    symptoms: {'Frequent urination':2,'Fatigue':2,'Weight loss':2,'Weakness':1,'Numbness':2},
    tests: ['Fasting Blood Sugar','HbA1c','Renal Profile'],
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

const List<String> kFrequencies = ['OD','BD','TDS','QID','SOS','HS'];
const List<String> kDurations = ['3','5','7','10 Days','14','30'];

/// Score likely conditions from chosen symptoms + block geo prior.
List<ScoredDisease> scoreDoctor(List<String> symptoms, String? block) {
  final geo = kGeoDb[block] ?? kGeoDb['Gajraula']!;
  final res = <ScoredDisease>[];
  kDoctorDb.forEach((name, plan) {
    var sc = 0, mx = 0;
    for (final s in symptoms) {
      sc += plan.symptoms[s] ?? 0;
    }
    for (final v in plan.symptoms.values) {
      mx += v;
    }
    var pct = mx > 0 ? (sc / mx * 100).round() : 0;
    if (geo.diseases.any((d) => d.name == name)) pct = (pct + 15).clamp(0, 98);
    if (pct >= 10) res.add(ScoredDisease(name, pct, pct >= 60 ? 'h' : (pct >= 35 ? 'm' : 'l')));
  });
  res.sort((a, b) => b.pct.compareTo(a.pct));
  return res.take(6).toList();
}
