/// Counsellor module master data + symptom-AI tables (ported from the
/// JubiCare 2.0 counsellor HTML prototype).
library;

// ─── Geography (generated from "All location village list.xlsx") ───
// 18 states / 68 districts / 111 blocks / 3,488 villages
const List<String> kStates = [
  "Assam",
  "Bihar",
  "Daman & Diu",
  "Goa",
  "Gujarat",
  "Haryana",
  "Jharkhand",
  "Karnataka",
  "Madhya Pradesh",
  "Maharashtra",
  "Odisha",
  "Punjab",
  "Rajasthan",
  "Tamil Nadu",
  "Telangana",
  "Uttar Pradesh",
  "Uttarakhand",
  "West Bengal",
];

const Map<String, List<String>> kStateDistricts = {
  "Assam": ["Kamrup", "Kamrup Metro"],
  "Bihar": ["Patna"],
  "Daman & Diu": ["Daman"],
  "Goa": ["North Goa"],
  "Gujarat": ["Ahmedabad(BB)", "Ankleshwar", "Bharuch", "Vadodara"],
  "Haryana": ["Gurugram", "Gurugram New", "Gurugram(BB)", "Jhajjar", "Manesar", "Nihon India", "Nihon MMU", "Reliance Clinic", "Reliance MMU"],
  "Jharkhand": ["Ranchi(BB)"],
  "Karnataka": ["Bangalore catchment", "Bengaluru REC", "Chitradurga", "Mysore", "Mysore REC", "Panasonic BLR"],
  "Madhya Pradesh": ["Indore"],
  "Maharashtra": ["Isambe", "Mumbai", "Mumbai(BB)", "Nagpur", "Nira", "Panasonic PUNE", "Pune(BB)", "Ranjangaon Pune", "Rural Nagpur", "Wardha"],
  "Odisha": ["Sambalpur", "Sambalpur(BB)"],
  "Punjab": ["Chandigarh", "Mohali"],
  "Rajasthan": ["Chittaurgarh"],
  "Tamil Nadu": ["Chengalpattu", "Chennai Catchment"],
  "Telangana": ["Dothiguddem", "Hyderabad", "Hyderabad Catchment", "Ramalingapally"],
  "Uttar Pradesh": ["Amroha", "Amroha (Triveni)", "Bulandshahr", "Bulandshahr (Anamika)", "Gautam Buddha Nagar(BB)", "Gautam Budh Nagar", "Gautam Budh Nagar(sns)", "Kushinagar", "Lucknow - Vibhutikhand", "Moradabad", "Muzaffarnagar", "Rampur", "Saharanpur"],
  "Uttarakhand": ["Roorkee"],
  "West Bengal": ["Asansol", "Birbhum", "Darjeeling", "Howrah", "Kolkata", "Kolkata(BB)", "South Bengal"],
};

const Map<String, List<String>> kDistrictBlocks = {
  "Kamrup": ["Dimoria"],
  "Kamrup Metro": ["Guwahati City"],
  "Patna": ["Ashiana Nagar"],
  "Daman": ["Daman"],
  "North Goa": ["Bicholim"],
  "Ahmedabad(BB)": ["AHMEDABAD - Urban(BB)", "Ahmedabad(BB)"],
  "Ankleshwar": ["Ankleshwar"],
  "Bharuch": ["Bharuch", "Other", "Vagra"],
  "Vadodara": ["Other", "Savli"],
  "Gurugram": ["Gurgaon"],
  "Gurugram New": ["Bawal", "Pataudi", "Rewari", "gurugram", "tauru"],
  "Gurugram(BB)": ["Sector 15(Gurugram)"],
  "Jhajjar": ["Badli", "Jhajjar", "Other", "Salhawas"],
  "Manesar": ["Manesar"],
  "Nihon India": ["Dadri Toe"],
  "Nihon MMU": ["Nihon MMU"],
  "Reliance Clinic": ["Reliance Clinic"],
  "Reliance MMU": ["Badli", "Jhajjar"],
  "Ranchi(BB)": ["Ranchi(BB)"],
  "Bangalore catchment": ["Malleswaram"],
  "Bengaluru REC": ["Devanahalli", "Dodaballapur", "Hoskote"],
  "Chitradurga": ["Chitradurga"],
  "Mysore": ["HD Kote", "Hunsur", "KR Nagar", "Mysore taluk", "Nanjangud", "Other", "Peeriyapatna", "Saligrama", "Sarguru", "Tn pura"],
  "Mysore REC": ["Mysore REC"],
  "Panasonic BLR": ["Yelahanka"],
  "Indore": ["INDORE - RURAL", "INDORE - URBAN"],
  "Isambe": ["Isambe"],
  "Mumbai": ["Khalapur", "Palghar"],
  "Mumbai(BB)": ["Panvel(BB)"],
  "Nagpur": ["Nagpur"],
  "Nira": ["Baramati", "Khed", "Other", "Purandar"],
  "Panasonic PUNE": ["Pune Panasonic"],
  "Pune(BB)": ["Mumbai - Urban (Panvel)(BB)", "Pune - Rural(BB)", "Pune - Urban(BB)"],
  "Ranjangaon Pune": ["Ranjangaon Blok"],
  "Rural Nagpur": ["Butibori"],
  "Wardha": ["Seloo"],
  "Sambalpur": ["Bamra"],
  "Sambalpur(BB)": ["Sambalpur(BB)"],
  "Chandigarh": ["Ambala"],
  "Mohali": ["Mohali", "SAS Nagar"],
  "Chittaurgarh": ["Kapasan"],
  "Chengalpattu": ["Thiruporur"],
  "Chennai Catchment": ["Chennai Urban and Rural"],
  "Dothiguddem": ["Dothiguddem"],
  "Hyderabad": ["Balanagar", "Hyderabad", "Isambe", "Maula Ali", "Yousufguda"],
  "Hyderabad Catchment": ["Jubilee Hills"],
  "Ramalingapally": ["Ramalingampally"],
  "Amroha": ["Gajraula", "Hasanpur", "Other"],
  "Amroha (Triveni)": ["Tulsipur"],
  "Bulandshahr": ["Araniya"],
  "Bulandshahr (Anamika)": ["Anamika Sugar"],
  "Gautam Buddha Nagar(BB)": ["Noida Location"],
  "Gautam Budh Nagar": ["Dadri", "Dankaur"],
  "Gautam Budh Nagar(sns)": ["SNS Block"],
  "Kushinagar": ["Padrauna"],
  "Lucknow - Vibhutikhand": ["Vibhutikhand"],
  "Moradabad": ["Bhagatpur Tanda"],
  "Muzaffarnagar": ["KHATAULI"],
  "Rampur": ["Tanda"],
  "Saharanpur": ["Deoband", "Rampur", "Sarsawa"],
  "Roorkee": ["Roorkee"],
  "Asansol": ["Purulia"],
  "Birbhum": ["Bolpur"],
  "Darjeeling": ["Siliguri Town"],
  "Howrah": ["Domjur", "Kandua", "Panchla", "Pashchim Medinipur"],
  "Kolkata": ["Howrah"],
  "Kolkata(BB)": ["Mullick Bazar"],
  "South Bengal": ["South 24 Parganas"],
};

const Map<String, List<String>> kStateBlocks = {
  "Assam": ["Dimoria", "Guwahati City"],
  "Bihar": ["Ashiana Nagar"],
  "Daman & Diu": ["Daman"],
  "Goa": ["Bicholim"],
  "Gujarat": ["AHMEDABAD - Urban(BB)", "Ahmedabad(BB)", "Ankleshwar", "Bharuch", "Other", "Savli", "Vagra"],
  "Haryana": ["Badli", "Bawal", "Dadri Toe", "Gurgaon", "Jhajjar", "Manesar", "Nihon MMU", "Other", "Pataudi", "Reliance Clinic", "Rewari", "Salhawas", "Sector 15(Gurugram)", "gurugram", "tauru"],
  "Jharkhand": ["Ranchi(BB)"],
  "Karnataka": ["Chitradurga", "Devanahalli", "Dodaballapur", "HD Kote", "Hoskote", "Hunsur", "KR Nagar", "Malleswaram", "Mysore REC", "Mysore taluk", "Nanjangud", "Other", "Peeriyapatna", "Saligrama", "Sarguru", "Tn pura", "Yelahanka"],
  "Madhya Pradesh": ["INDORE - RURAL", "INDORE - URBAN"],
  "Maharashtra": ["Baramati", "Butibori", "Isambe", "Khalapur", "Khed", "Mumbai - Urban (Panvel)(BB)", "Nagpur", "Other", "Palghar", "Panvel(BB)", "Pune - Rural(BB)", "Pune - Urban(BB)", "Pune Panasonic", "Purandar", "Ranjangaon Blok", "Seloo"],
  "Odisha": ["Bamra", "Sambalpur(BB)"],
  "Punjab": ["Ambala", "Mohali", "SAS Nagar"],
  "Rajasthan": ["Kapasan"],
  "Tamil Nadu": ["Chennai Urban and Rural", "Thiruporur"],
  "Telangana": ["Balanagar", "Dothiguddem", "Hyderabad", "Isambe", "Jubilee Hills", "Maula Ali", "Ramalingampally", "Yousufguda"],
  "Uttar Pradesh": ["Anamika Sugar", "Araniya", "Bhagatpur Tanda", "Dadri", "Dankaur", "Deoband", "Gajraula", "Hasanpur", "KHATAULI", "Noida Location", "Other", "Padrauna", "Rampur", "SNS Block", "Sarsawa", "Tanda", "Tulsipur", "Vibhutikhand"],
  "Uttarakhand": ["Roorkee"],
  "West Bengal": ["Bolpur", "Domjur", "Howrah", "Kandua", "Mullick Bazar", "Panchla", "Pashchim Medinipur", "Purulia", "Siliguri Town", "South 24 Parganas"],
};

const Map<String, List<String>> kBlockVillages = {
  "Dimoria": ["Amara Pathar", "Barua Bari Gaon", "Batakuchi Nc", "Bijini Ghat", "Damora Pathar", "Dhangiri Gaon", "Digaru", "Gomoria Gaon", "Kapalkata", "Mitanu Pathar", "Patirkuchi", "Samota", "Sonapur Ghat", "Sultanpur", "Tegharia", "Teteliguri Pathar"],
  "Guwahati City": ["9th Mile", "Bashistha Lakhara", "Beltola", "Bharalumukh Slum Pocket", "Boragaon Garbage Belt Settlements", "Fatasil Ambari Basti", "Goriaguli", "Hahara", "Hatigaon Slum Cluster", "Hatimura", "Jalukbari", "Kamarkuchi", "Khanapara Lotakata", "Khetri", "Lalungoan Garchuk", "Lokhra Char Area", "Maligaon Railway Colony Adjacent Slums", "Medikuchi", "Pamohi Maligaon", "Pandu", "Pandu Riverside Settlements", "Patharkuchi", "Sonapur", "Sundernagar", "Survey Char", "West Jalukbari Basti"],
  "Ashiana Nagar": ["Ashiana Nagar"],
  "Daman": ["Atiawad", "Bhimpore", "Dabhel", "Daman", "Dunetha", "Ghelwad", "Somnath", "Varkund"],
  "Bicholim": ["Ameshiwada Amona", "Amona", "Bandarwada Amona", "Barniwada Navelim", "Betalwada", "Betki- Khandola", "Dakulmaina Navelim", "Dhabdhba", "Durikwada Navelim", "Fanaswadi Navelim", "Gaonkarwada", "Ghoogremaina", "Khumbharwada", "Lamgao", "Mastiwada Navelim", "Navelim", "Pilgao", "Pimplewada Amona", "Sarmanas", "Sirigao", "Tariwada Amona", "Tikhajan", "Upper Durikwada", "Virdi"],
  "AHMEDABAD - Urban(BB)": ["Motera"],
  "Ahmedabad(BB)": ["Chandkheda"],
  "Ankleshwar": ["Amritpura", "Ankleshwar", "Boidra", "Kasiya", "Kharchi", "Mandva", "Motali", "Mulad", "Nana Sanja", "Naugama", "Samor", "Uchali"],
  "Bharuch": ["Cholad", "Dayadara", "Derol", "Kalla", "Kelod", "Kothi", "Other", "Sarnar", "Talsa", "Vachhnad", "Vahalu", "Vasi"],
  "Other": ["Other"],
  "Vagra": ["Aankot", "Argama", "Bhersam", "Juned", "Kelod", "Kothi", "Other", "Rahad", "Saladara", "Talsa", "Vacchnad", "Vilayat", "Vorasamni"],
  "Savli": ["Amirpura", "Chorpura", "Gagandiya", "Gothada 1", "Gothada 2", "Gothda 3", "Javla", "Juna Samlaya", "Karchia", "Khanderavpura", "Lasundra", "Manoharpura", "Manorpura", "Nani Bhadol", "Other", "Pasva", "Pratap Nagar", "Radhanpura", "Radhanpura 2", "Samantpura", "Sherpura", "Subhelav", "Test Unnao", "Vankaner", "Vemar"],
  "Gurgaon": ["Adampur", "Gopalpur", "Kho", "Kidoli", "Pathreri", "Pehladpur", "Skh Plant Kharkhoda", "Skh Plant M1", "Skh Plant M2", "Skh Plant M3", "Skh Plant Mm", "Skh Technology"],
  "Bawal": ["Jhabua", "Khijuri", "Patuhera"],
  "Pataudi": ["Bhaganki", "Khor", "Lokra", "Lokri", "Mau"],
  "Rewari": ["Bhatsana", "Maheshwari", "Tatarpur Khalsa"],
  "gurugram": ["Bhaganki", "Kalwari"],
  "tauru": ["Hassanpur", "Jourasi"],
  "Sector 15(Gurugram)": ["Jharsa", "Kadarpur", "Khandsa"],
  "Badli": ["Fatehpur", "Munimpur", "Nimana", "Other", "Sondhi", "Yakubpur"],
  "Jhajjar": ["Bid Dadri", "Canteen Labour 7", "Dadri Toye", "Jahidpur", "Jhangirpur", "Kaloi", "Kheri Jatt", "Kutani", "Naurangpur", "Navodayâ School", "Other", "Ramgarh Dhani", "Surha", "Untlodha"],
  "Salhawas": ["Chandol", "Dhakla", "Other", "Subana"],
  "Manesar": ["Aliyar", "Bilaspur Kailan", "Bilaspur Khurd", "Dhana", "Jhundsarai", "Kharkhoda", "Kho", "Manesar", "Pathreri", "Skh M3", "Skh Plant"],
  "Dadri Toe": ["Bid Dadri", "Chandol", "Dadri Toye", "Dhakla", "Fatehpur", "Jahidpur", "Kaloi", "Kukdola", "Kutani", "Munimpur", "Nangla", "Naurangpur", "Nimana", "Other", "Ramgarh Dhani", "Sondhi", "Subana", "Untlodha", "Yakubpur"],
  "Nihon MMU": ["Bhupania", "Ghubana", "Goela Kalan", "Harinagar", "Khera Khurrampur", "Kheri Jatt", "Khungai", "Khurrampur", "Majri", "Nayanganpur", "Nihon Mmu", "Silana", "Silani", "Sucha (Naudunga)", "Uthloda", "Zhaidpur"],
  "Reliance Clinic": ["Reliance Clinic"],
  "Ranchi(BB)": ["Bero (Fringe Villages)", "Bukru", "Hesal", "Jaratoli", "Kanke (Rural)", "Lapung", "Nagri", "Namkum (Rural Pockets)", "Patratoli", "Pithoria", "Silli Border Villages"],
  "Malleswaram": ["Basavanagudi", "Basaveshwaranagar", "Cunningham Road", "Hebbal", "Indiranagar", "Jayanagar", "Koramangala", "Mahalakshmi Layout", "Malleshpalya", "Malleswaram West", "Rajajinagar", "Rajiv Gandhi Nagar", "Richmond Town", "Sadashivanagar", "Sampige Road", "Seshadripuram", "Shivajinagar", "Vidyaranayaapura", "Yeshwanthpur"],
  "Devanahalli": ["Abachikkanahalli", "Agalakote", "Akkalenahalli Mallena - Halli", "Alurdoddanahalli", "Anighatta", "Anneswara", "Aradeshahalli", "Arasanahalli Peddanahalli", "Arasinakunte", "Aruvanahalli", "Attibele", "Avathi", "Bachahalli", "Baladimmanahalli", "Balepura", "Bammanahalli", "Bandaramanahalli", "Bannimangala", "Bediganahalli", "Beerasandra", "Bettakote", "Bettakote Amanikere", "Bettenahalli", "Bhatramarenahalli", "Bidalapura", "Bidalapura Amanikere", "Bidalur", "Bijjawara", "Binnamangala", "Bommawara", "Boodihal", "Boovanahalli", "Budigere", "Bullahalli", "Byadarahalli", "Bychapura", "Byradenahalli", "Byrappanahalli", "Byrapura", "Chandenahalli", "Channahalli", "Channarayapatna", "Chapparadahalli", "Cheemachanahalli", "Chikka Thattamangala", "Chikkachimanahalli", "Chikkagollahalli", "Chikkanahalli", "Chikkannanahosahalli", "Chikkasanne", "Chikkenahalli", "Chikkobanahalli", "Chinnakempanahalli", "Chinnappanayakana Hosur", "Chowdenahalli", "Dandiganahalli", "Dasarahalli", "Devaganahalli", "Devanayakanahalli", "Devenahalli", "Dharmapura", "Dodda Thattamangala", "Doddacheemanahalli", "Doddagollahalli", "Doddakurubarahalli", "Doddamuddenahalli", "Doddappanahalli", "Doddasagarahalli", "Doddasanne", "Dyavarahalli", "Gaddadanagenahalli", "Gangamuthanahalli", "Gangavara Chowdappana Halli", "Gejjaguppe", "Gobbarakunte", "Gokare", "Gollahalli", "Gonur", "Gopasandra", "Gudla Muddenahalli", "Guduvanahalli", "Handrahalli", "Haralur", "Haralur Nagenahalli", "Harohalli", "Hegganahalli", "Hiriganahalli", "Holerahalli", "Hosahalli", "Hosahudya", "Hyadala", "Ibasapura", "Ilathore", "Indrasanahalli", "Irigenahalli", "Jalige", "Jogahalli", "Jonnahalli", "Juttanahalli", "Kaggalahalli", "Kamenahalli", "Kannamangala", "Karahalli", "Kempalingapura", "Kempathimmanahalli", "Kodagurki", "Koira", "Kommasandra", "Konaginabele", "Kondenahalli", "Koramangala", "Kottigethimmanahalli", "Kundana", "Kurubarakunte", "Lakshmipura", "Lalagondanahalli", "Lingadeeragollahalli", "Maligenahalli", "Mallenahalli", "Mallepura", "Mandibele", "Mangondanahalli", "Maragondanahalli", "Mattabaralu", "Mayasandra", "Meesaganahalli", "Moodiganahalli"],
  "Dodaballapur": ["Adinarayana Hosahalli", "Alappanahalli", "Aloor", "Amani Palanakere", "Ankonahalli", "Aralumallige", "Arehalliguddadahalli", "Bairapura", "Baiyappanahalli", "Bankenahalli", "Bannamangala", "Beera Sandra", "Bhaktarahalli", "Binuvanahalli", "Bisuvinahalli", "Bommanahalli", "Bommasandra", "Byradena Halli", "Chikka Tumakuru", "Chinkampanna Halli", "Darga Jogahalli", "Dargajogihalli", "Dargapura", "Duddnahalli", "Ellupura", "Galipoje", "Ganga Chandra", "Guddadahalli", "Gummanahalli", "Gundungere", "Hanabe", "Hasanaghatta", "Honnaghata", "Hoonagatta", "Hosahudya", "Jakkasandra", "Jaligere", "Jinkebachchahalli", "Juttanahalli", "Jyotipura", "K G Govindapura", "K G Kuntanahalli", "Kadalappanahalli", "Karenahalli", "Kasavanahalli", "Kasuvinahally", "Keshtur", "Kesturu", "Khasbag", "Kodigehalli", "Kogina Halli", "Kolipura", "Koluru", "Koluru Planteshan", "Kurubarahalli", "Laxmi Devipura", "Madagondanahalli", "Majara Hosahalli", "Makali", "Mandibyadarahalli", "Mandibydrana Halli", "Maralenahalli", "Menasi", "Moprahalli", "Muttur", "Mutturu", "Nagadenahalli", "Nagasandra", "Nagdenahalli", "Nagsandra", "Neralaghatta", "Obadenahalli", "Obbadenahalli", "Palana Jogahalli", "Raghunathapura", "Raghunathpura", "Sasalu", "Shivapura-Amanikere", "Shreenivasapura", "Siddenaykanahalli", "Sonappanahalli", "Sonnenahalli", "Sunagatta", "Suttahalli", "Talagavara", "Tammaganahalli", "Tammashettahalli", "Thalaga Vara", "Tigalebagayti", "Tippapura", "Vaddarahalli", "Varadanahalli", "Vardanahalli", "Veerabadhranapalya", "Veerapura", "Yellupura"],
  "Hoskote": ["Ajagondanahalli", "Alagondanahalli", "Amanidoddakere", "Ambaleepura", "Anugondanahalli", "Appajipura", "Appasandra", "Aralemakanahalli Be", "Arehalli", "Baguru", "Bairahalli", "Banahalli Be", "Banarahalli", "Basabattanahalli", "Belamangala", "Bellikere", "Bhaktagondanahalli Be", "Bhaktarahalli", "Bhodanahosahalli", "Bisanahalli", "Bommanabande", "Byalahalli", "Chandrapura Be", "Channapura", "Cheemandahalli", "Chikkagattiganabbe", "Chikkahulluru", "Chikkanallala", "Chikkanallurahalli", "Chikkataggali", "Chokkahalli", "Cholappanahalli", "D Hosahalli", "Dabbagunte", "Dasaratimmanahalli", "Devalapura", "Devanagondi", "Devaragollahalli", "Devashettihalli", "Doddadasarahalli", "Doddadenahalli", "Doddadunnasandra", "Doddahulluru", "Doddanallala Be", "Doddataggali", "Ganagalu", "Ganagaluru", "Gonakanahalli", "Govindapura", "Guguttahalli", "Gullakayipura", "Gunduru", "Halavasinakayipura", "Handenahalli", "Haraluru", "Harohalli", "Hemmandahalli", "Honachanahalli", "Hosakote", "Hulluru Amanikerela", "Hunasehalli", "Injanahalli", "Jadigenahalli", "Jinnagara", "Kacharakanahalli", "Kalkunteagrahara", "Kallahalli", "Kamarasanahalli", "Kaneekallu", "Kannurahalli", "Karibeeranahosahalli", "Kattigenahalli", "Khajihosahalli", "Kodihalli", "Koraluru", "Koturu", "Kumbalahalli", "Kurubaragollahalli", "Lakkondahalli", "Lingadheeramallasandra", "Makanahalli", "Mallasandra", "Mallimakanapura", "Maragondanahalli", "Marangere", "Medahalli", "Medimallasandra", "Mugabala", "Mugabala Hosahalli", "Mutkuru", "Mutsandra", "Muttukadahalli", "Naduvatti", "Naganaykanakote", "Narayanakere", "Nidaghatta", "Obalapura", "Orohalli", "Paramanahalli", "Pettanahalli", "Pillagumpe", "Pujenagrahara", "Sametanahalli", "Sarkara Guttaganahalli", "Shankaneepura", "Shivanapura", "Siddanapura", "Somlapura", "Sompura", "Sonnadenahalli", "Taggalihosahalli", "Tarabahalli", "Tattanuru", "Timmandahalli", "Timmapura", "Tindlu", "Tiratahalli", "Tirumalashettihalli", "Tiruvaranga", "Ummalu", "Upparahalli", "Vabasandra", "Vadigehalli", "Vagata", "Vijayapura Be", "Yadagondanahalli", "Yalachamanahalli", "Yalachanaykanapura"],
  "Chitradurga": ["Alagatta", "B.N. Halli", "Bommanahalli", "Chikkenahalli", "Haliyuru", "Hirekandwadi", "Kadaleguddu", "Kagalagere", "Konanuru", "Malappanahatti", "Manangi", "Medikeripura", "Megalahalli", "Muttugaduru", "Siddapura", "Sirigere Siddapura", "Thanigehalli", "V.Palya"],
  "HD Kote": ["Annayappana Shed", "Annur", "Annuruhadi", "Basavanagiri 'A'", "Basavanagiri 'B'", "Belaganahalli", "Belthuru A Colony", "Belthuru B Colony", "Bharathipura", "Bheemanahalli", "Bheemanahalli Hadi", "Bochikatte", "Bomblapura", "Bomblapura Hadi", "Br Kattehadi", "Budanur Hadi", "Budanuru", "Bukthalemala", "Chaikkakalegowdana Pura Hadi", "Chakahalli", "Chakkodanahalli", "Chikkakalegowdanapura", "Chikkerehadi", "Devalapura Colony", "Devarajanagar", "G.G. Colony", "G.M. Halli Hadi", "Ganeshpura", "Ganished", "Goolikatte", "Gowndrushed", "Hakkipikki Shed", "Honnemaradahalla", "Hosahallihadi", "Hosatoravalli", "Indiranagar", "Itna Colony", "K Yadathorehadi", "K. Edatorepalya", "K. Yadatore", "K.G. Hundi", "Kadahampapura", "Kailasapura", "Kunteri Hadi", "Lakshmipura", "Mahadeshwara Colony", "Mahadevapura", "Majjanakuppehadi", "Mastigudihadi", "Metikuppe Hadi", "Muruganahalli", "Muskere", "Muskerehadi", "N.N. Halli", "Nanajayana Colony", "Nn Halli Palya", "Padukoti", "Rajegowdanahundi", "Rajegowdanahundihadi", "Savvemala", "Shanthipura", "Shareef Colony", "Sollapura C Hadi", "Sonahalli", "Sonahalli Hadi", "Sunnakallu Manti", "Tiger Block", "Udbur Colony", "Vaddaragudi", "Vishwakarma Colony", "Yalehundi"],
  "Hunsur": ["Ankanahalli", "Annarayapura", "Bannikuppe", "Benkipura", "Bilikere", "Bolanahalli", "Chikkabeedanahalli", "Chikkadanahalli", "Chilkunda", "Cholanahalli", "Dallalu Koppalu", "Dasthikola", "Devarahalli", "Doddabeeachanahalli", "Eradasi Koppalu", "G Nagara", "Gohalli", "Hagaranahalli", "Handanahalli", "Hareenahalli", "Hosuru", "Jeenahalli", "Kalegowdanakoppalu", "Kebbekoppalu", "Kolagatta (Gnagara)", "Kuppe", "Madugirikoppalu", "Mallinathapura", "Manuganahalli", "Maradur", "Maralayanakoppalu", "Mudalakoppalu", "Nanjappanakoppalu", "Rampura / Haradanahalli", "Rayanahalli", "Sabbanahalli", "Shankalli", "Tenkalakoppalu", "Tulasikopplu", "Yalachawadi"],
  "KR Nagar": ["Adaguru", "Araker", "Arjunahalli", "Badakanakoppalu", "Balur Koppalu", "Baluru Koppalu", "Bandahalli", "Basavanapura", "Basavapatna", "Basavarajapura", "Batiganahalli", "Bherya", "Bommenahalli", "Chandagaalu", "Chikkabherya", "Chowkahalli", "D.V. Gudi", "Doddakoppalu", "Doddekoppalu", "Doranahalli", "Galigekere", "Halagegowdanakoppalu", "Hampapura", "Hanasoge", "Hangarabayanahalli", "Haramballi", "Haramballi Koppalu", "Hosaagrahara", "Hosahalli", "K Badavane", "Kakanahalli", "Kalyanapura", "Kanchinakere", "Katnalu", "Kaval Hosuru", "Koluru", "Kumbarakoppalu", "Lalanahalli", "M.G.Halli", "Manchanahally", "Mulepetlu", "Nadappanahalli", "Sugganahalli", "Vaddarahalli", "Yaremanuganahalli"],
  "Mysore taluk": ["Anaghanahalli", "B.G.Hundi", "Badagalahundi", "Ballahalli", "Baradanapura", "Beerihundi", "Bogadi", "Byathanahalli", "D.H.Hundi", "D.M.G.Halli", "D.Salundi", "Daripura", "Dasanakoppalu", "Devagalli", "Dhanagalli", "Doddahundi", "Doora", "Galagarahundi", "Ganagarahundi", "Gohalli", "Goorur", "Gopalapura", "Halekesare", "Hanchya", "Jattihundi", "Jayapura", "K Salundi", "K.Hemmanahalli", "K.M.Hundi", "K.N.Hundi", "K.R.Mill", "Kadakola", "Kalisiddanahundi", "Kallalavadi", "Kamanakere", "Kattehundi", "Kellahalli", "Kenchalagudu", "Kerehundi", "Kergalli", "Koppaluru", "Kottehundi", "Kumarabeedu", "Lingabudipaly", "Madagahalli", "Madahalli", "Mahadevapura", "Manikyapura", "Maraiahnahundi", "Maratikyathanahalli", "Marballi", "Marballikoppalu", "Mavinahalli", "Muganahundi", "Mulluru", "Muniswaminagara", "Murudagalli", "Nagarthnahalli", "Nanjarajanahundi", "Nuggehalli", "Parasayanahundi", "Ramanahundi", "Rammanahalli", "S.N.Halli", "Sahukarahundi", "Sathagalli", "Shrirampura", "T.Katuru", "Tibbaiahnahundi", "Yadehalli"],
  "Nanjangud": ["Aallaiahnapura", "Adharsha School", "Akala", "Ankusharayanapura", "Avathalapura", "B.R.Pura", "Badanavalu", "Basapura", "Basavattige", "Belagunda", "Biligere", "Bilugali", "Byalaru", "Chamlapuradahundi", "Chiikahomma Mole", "Chikkahimma", "Chikkakavalande", "Chunchanahalli", "Dasanuru", "Debur", "Devanuru", "Doddahomma", "Gattavadi", "Geekahalli Hundy", "Geekhahalli", "Hampapura", "Handuvinahalli", "Hanumanapura", "Hariharapura", "Haropura", "Ibjala", "Igli", "Jeemarahalli", "Kadaburu", "Kakkarehatti", "Kallahalli", "Kalmalli", "Kanakanagara", "Kanenuru", "Kappasoge", "Karemole", "Kathwadipura", "Kathwadypura", "Katuru", "Konanapura", "Konanuru", "Korehundy", "Kupparavalli", "Marallipura", "Motha", "Nallithalapura", "Nanjanahalli", "Nerale", "Other", "P.Maralli", "Palya", "Sujathapuram", "Thoravalli", "Thoravallo Mole", "Varahalli"],
  "Peeriyapatna": ["Anivalu", "Attigodu", "B G Koppalu", "Balekatte", "Barse", "Barse Koppalu", "Basavanagara", "Besanakuppe", "Bettadathunga", "Bhuvanahalli", "Btm Koppalu", "Chikkahonuru", "Chikkahossur", "Chikkamalai", "Chikkegowdanakoppalu", "D G Koppalu", "Depoora", "Doddahonnur", "Doddahossur", "Gg Koppalu", "Giruguru", "Guddenahalli", "Harinahally", "Heremalali", "Joganahalli", "K Hosahalli", "Kaggalikoppalu", "Kallikoppalu", "Kg Koppalu", "Kogiluru", "Konasuru", "Koppa", "Kowlanahally", "Kudukuru", "Kudukuru Koppalu", "M Akoppalu", "M Hosahalli", "M M Koppalu", "M Mari Gowdanakoppalu", "M Mata", "M Matada Koppalu", "Maradiyuru", "Mardoor", "Mardoor Gate", "Maruru", "Meluru", "Naganhalli", "Naganhalli Palya", "Navilkodi", "P Basavanahalli", "Salukoppalu", "Sangashettihally", "T G Koppalu"],
  "Saligrama": ["Abburu", "Ankanahalli", "Balluru", "Bandahalli", "Basavanapura", "Basavaraja Pura", "Battiganahalli", "Bettahalli", "Bylapura", "Chikkabheriya", "Chikkahanasoge", "Chikkanayakanahalli", "Dadadahalli", "Dammanahalli", "Doddakoppalu", "Elladahalli", "Gayanahally", "Gummanahally", "Hadya", "Hanasoge", "Haradanahally", "Harambahalli", "Harambahalli Koppalu", "Hebsuru", "Honnenahally", "Hosagrahara", "Kaggala", "Kalammanakoppalu", "Kallimuddanahalli", "Karathalu", "Karpurahalli", "Katnalu", "Kedaga", "Koluru", "Kulume Hosuru", "Kurubahalli", "Lakkikuppe", "Madapura", "Maluganahalli", "Mandiganahalli", "Mavanuru", "Mudalabeedu", "Munduru", "Nadappanahalli", "Pashupathi", "Rampura", "Saligrama A", "Saligrama B", "Salukoppalu", "Saraguru", "Senabina Kuppe", "Shambravalli", "Sheegavalu", "Somanahalli", "Subbegowdana Kopplau", "Thandre", "Thandre Ankanahalli", "Y.M.Halli"],
  "Sarguru": ["Agatturu", "Anagatti", "Anagattihadi", "Ankanathapura", "Ankanathapurahadi", "Bidarahalli", "Bidarahallihundi", "Chamegowdanahundi", "Chennipura", "Dammunakatte", "Dammunakattehadi", "Gaddehalla", "Gonathakalundi", "Hegganuru", "Hoovinakola", "Hosakeresunda", "Hosamalahadi", "Hunaganahalli", "Hunasehalli", "Hunasekuppe", "Hunasekuppehadi", "Itna", "Jiyara", "Kalegowdanhundi", "Kandegala", "Karapurahadi", "Kerehadi", "Kottegala", "Kunnapatana", "Lakshmipurahadi", "Lanke", "Machanayakanahalli", "Machhare", "Maladahadi", "Manchahalli", "Manchegowdanahallihadi", "Manuganahalli", "Marnahadi", "Mosaralla", "Nadhinathapura", "Niluvagilu", "Pakshinota", "Penjalli", "Penjallihadi", "Pura", "Puradakatte", "Ramenahalli", "Ramenahallihadi", "Sagare A", "Sagare B", "Saraswathipuram", "Sargur A-Ward-4", "Sargur B Ward 5,6,7,8", "Sargur C Ward 2,3", "Sargur D Ward 2,4", "Sattigehundi", "Seeguruhadi", "Shanthipura", "Sheeranahundi", "Taraka", "Teranimunti", "Thelugumasalli", "Thumbasoge", "Udburuhadi", "Uyyamballi"],
  "Tn pura": ["Ambedkar Mohala", "Ankanahalli", "Aravattege Koppalu", "Atthahalli", "B.Bettahalli", "Basavanahalli", "Bevinahalli", "Bhugathagahalli", "Bidanahalli", "Bismila Nagara", "Bolegowdanahundi", "Bommanahalli", "Budhahalli", "Chamalapura", "Chamanahali", "Chamanahali Koppalu", "Chidaravalli", "Chikkakalkuni", "Chimili", "D.M.Gudu", "Dasegowdanahalli", "Dayiramohala", "Doddangadibeedi", "Gadijogihundi", "Ganiganahalli", "Ganigeri", "Gudadakoppalu", "Hanumanalu", "Hegguru", "Horakeri", "Hosa Thirumakudalu", "Hosahalli", "Hosakoppalu", "K.G.Koppalu", "K.K.Halli", "K.K.S.F", "Kallipura", "Kanchanahalli", "Kannanayakanahalli", "Karihurallikoppalu", "Katte Koppalu", "Kempanapura", "Kodagahalli", "Kolatthuru", "Kutthanahalli", "M.K.Halli", "M.M.Road", "Madigahalli", "Makanahalli", "Maliyuru", "Maregowdanahalli", "Megala Koppalu", "Mudukapura", "Muslim Street", "Nagalagere", "Nanjapura", "Neregyathanahalli", "Nugahalli Koppalu", "Parivarada Beedi", "Ramegowdanapura", "S.Doddapura", "Santhemela", "Seehalli", "Senapathahalli", "Sigodipura", "Subhas Nagara", "Therina Beedi", "Thyagaraja Mohala", "Tolgate"],
  "Mysore REC": ["Adaguru", "Adahalli", "Adarsha School", "Adharsha School Debur", "Adibettahalli", "Ahalya", "Akki Kuppe", "Akkuru", "Akkurudoddhi", "Alaganchy", "Alaganchypura", "Alanahalli", "Algodu", "Anagalli", "Ankanahali Koppalu", "Ankanahalli", "Arakerekoppalu", "Arasinakere", "Arjunahalli", "Athiguppe", "Ayyanavarahundi", "Bachahalli", "Badagalahundy", "Badakanakoppalu", "Badhanvalu", "Ballur", "Balur Koppalu", "Bannallihundi", "Banni Kuppe", "Banooru", "Baradanapura", "Basalapura", "Basavanapura", "Basavarajapura", "Basavattige", "Beeranahally", "Belagundha", "Belale", "Belathur", "Benakanahalli", "Betta Halli", "Bhogayyanahundi", "Bhuthanahalli", "Bidagalu", "Bidaragudu", "Biligere", "Bilikere", "Booditittu", "Bopanahalli", "Byadarahally", "Byalaru", "Byalaruhundy", "Cg Hundi", "Chakkuru", "Chamahalli", "Chamalapura", "Chamanahallihundy", "Chandagaalu", "Chandahalli", "Chandravady", "Chattanahalli", "Chattanahalli Palya", "Cheeranhally", "Chennabasavayyanahundi", "Chennipura", "Chikakanya", "Chikka Bherya", "Chikkabeachanahalli", "Chikkagowdana Hundy", "Chikkakereyuru", "Chikkamagali", "Chikkanandi", "Chikkanayakanahalli", "Chikkankanahalli", "Chikkavalandhe", "Chikknandi", "Chinnadagudihundi", "Chinnamballi", "Chottanahalli", "Chowdalli", "Chowhalli", "Chowkahalli", "Chowth", "Chowtha", "Chunchanahalli", "Dadadahalli", "Dakalehundy", "Dandikere", "Daripura", "Dasanooru", "Debur", "Depegowdanapura", "Devalapura", "Deviramanahallihundy", "Deviramanhalli", "Dharma\\Yyanahundi", "Dhevarasanahalli", "Dhoddahomma", "Doddabeachanahalli", "Doddabylalu", "Doddakanya", "Doddakaturu", "Doddakavalande", "Doddakoppalu", "Doddamaragowdanahalli", "Doddanahundi", "Doddapura", "Doddegowdana Koppalu", "Doora", "Dornahalli", "Duggali", "Echgundla", "G Basavanahalli", "G.Basanahalli", "Gagenahalli", "Galigekere", "Gattavadipura", "Gatvady", "Geekahalli", "Geekahallihundy", "Gejjagalli", "Gejjaganahalli", "Goddanapura", "Goluru", "Gonahalli", "Gonthaganahundi", "Gopalapura", "Gowdrahundy", "Gujjappanahundi", "Gujjegowdanapura", "Gujjigowdanapura", "Gumchanahalli", "Gummanahalli", "H Kongalli", "H Megadahalli", "H.Kongali", "Habatoor Koppalu", "Habbanakuppe", "Hadaganahally", "Hadjana", "Hadya", "Hadya H", "Hagaranahalli", "Halambooru", "Halamburumanty", "Halasuru", "Halathur", "Halebidu", "Halebokalli", "Halepura", "Halladhakere", "Hallidhiddi", "Hallikerehundi", "Hampapura", "Hanchipura", "Handanahalli", "Handuvinahalli", "Haniyamballi", "Hanni Kuppe", "Hanumanapura", "Haradana Halli", "Harathale", "Harilapura", "Hariyur", "Harohalli", "Haropura", "Hathwalu", "Hd Madapura", "Hd Nerale", "Hebbalu", "Hebbaya", "Heggadahalli", "Hegganur", "Hejjige", "Hemmige", "Hirenandi", "Hiriyuru", "Holehundi", "Honnenahally", "Horalavadi Hosuru", "Horalvady", "Hosabokalli", "Hosahalli", "Hosaheggudilu", "Hosahemmigi", "Hosahundy", "Hosapura", "Hosayyanavarhundi", "Hosuru", "Hosurundi", "Hs Halepura", "Hulikura", "Hulimavu", "Hullahalli", "Hullenahalli", "Hunasekuppe", "Hunsnalli", "Hunsuru", "Huralikyathanahalli", "Huskuru", "Hyakanuru", "Hyrige", "Immavu", "Jadagana Koppalu", "Jakkahalli", "Jalahalli", "Javanikuppe", "Jinnahalli", "Kaadanahalli", "Kadaburu", "Kadajatti", "Kaggere", "Kagundi", "Kahalli", "Kalale", "Kale Gowdana Koppalu", "Kalegowdanahundi", "Kaliyuru", "Kalkere", "Kallahalli", "Kalmalli", "Kamahalli", "Kamanahalli", "Kamaravalli", "Kanakanagara", "Kanchinakere", "Kanchmalli", "Kandegala", "Kanenooru", "Kannahalli", "Kannahalli Mole", "Kapsoge", "Karalapura", "Karehundy", "Karepura", "Karigala", "Karuhatti", "Karya", "Kasvinahalli", "Katnalu", "Kattepura", "Kebbe Koppalu", "Kedaga", "Kellahalli", "Kembalu", "Kempegowdana Hundy", "Kendanakoppalu", "Kerehundy", "Ketalli", "Kiragasuru", "Kiragundha", "Kiralu", "Kiranalli", "Kochanahalli", "Kodinarasipura", "Kogilavadi", "Kohala", "Kolagala", "Kollegowdanahalli", "Konanuru", "Konthayyanahundi", "Koodanahalli", "Korehundy", "Kothegala", "Kotthegala", "Kr Puram", "Krishnapura", "Kudlapura", "Kudluru", "Kugaluru", "Kullakkanahundi", "Kulya", "Kumbarahalli", "Kumbrahallimata", "Kunigal", "Kuntanbelattur", "Kupparavali", "Kurahatty", "Kuruba Hally", "Kuruburu", "Lakki Kuppe", "Lakki Kuppe Koppalu", "Lakshmanapura", "Lakshmanpura", "Lalanahalli", "Lanke", "Laxmipura", "M Basavanapura", "M Kannenahalli", "M Kongaalli", "M. Mulluru", "M.Megadahalli", "Maadhanahalli", "Maavinahalli", "Machabayanahalli", "Madahalli", "Madapura", "Madarahalli", "Madhapura", "Magali", "Magudilu", "Mahadevi Colony", "Makanahalli", "Makanahundy", "Makanapura", "Malangi", "Malara Colony", "Malaradahundy", "Malkundy", "Mallahalli", "Malugana Halli", "Manchanahally", "Mandakalli", "Mangipacchanahundi", "Mannehundy", "Manti Koppalu", "Manuganahalli", "Maradipura", "Maraduru", "Maragowdanahalli", "Maraluru", "Maranapura", "Marase", "Marasettihalli", "Marballi", "Marballihundy", "Marigowdanahundy", "Marulaianna Koppalu", "Masge", "Matakere", "Mavinahalli", "Mellahalli", "Melur", "Melure", "Moodala Koppalu", "Moodalabeedu", "Motha", "Mudala Koppalu", "Muddanahalli", "Mudhahalli", "Mudiguppe", "Mulluru", "Munudur", "Muthur", "Mysore Rec", "Nagarathahalli", "Nanjangud Town", "Naviluru", "Nayakanahundi", "Nellithapura", "Neralakuppe", "Nerele", "Nerelehundi", "Nilasoge", "Niluvagilu", "P Maralli", "Pailwan Colony", "Palya", "Pillahalli", "Poonadahalli", "Pura", "Puttegowdana Hundi", "Ramenahalli", "Rampura", "Rayana Hally", "Rayanahundy", "Sajjehundy", "Saligrama", "Salu Koppalu", "Salundi", "Saraguru", "Sathyagala", "Savve", "Sd/Vtc Nanjangud", "Seegahalli", "Seehalli", "Shambudevanapura", "Shanu Bhoganahalli", "Shettalli", "Shiramahalli", "Shiramalli", "Shravanana Hally", "Siddhainahundy", "Sindhuvalli", "Sindhuvallipura", "Someshwarapura", "Sonahalli", "Sujjaluru", "Sundavalu", "Sunkalmanti", "Surahalli", "T Katuru", "T N Hunsuru", "Tandrekoppalu", "Tatanahalli", "Tenkalakoppalu", "Thandre", "Thardhale", "Thelaginakuppe", "Thimakapura", "Thippuru", "Thoravalli", "Thoremaavu", "Thukadimadaina Hundy", "Thumbasoge", "Thumnerale", "Uppinahalli", "Uyi Gowdanahalli", "Valagere", "Varahalli", "Varakodu", "Vatalu", "Veeradevanapura", "Veeregowdanahundi", "Venkategowdanakopplu", "Yaladahally", "Yalamatturu", "Yaraganahalli", "Yechagalli", "Yelachagere", "Yelamathur", "Yeragalli"],
  "Yelahanka": ["Arebannimangala", "Attur", "B.K Palya", "Bandikodegehalli", "Batrumarenahalli", "Baylanahalli", "Chowdeshwari Ward", "Golahalli", "Gopalapura", "Hunachuru", "Huvinayakanahalli", "Jakkur", "Kaderapanahalli", "Kondenahalli", "Mahadevakodigehalli", "Manchappanahalli", "Maralakunte", "Misganhalli", "Mylanahalli", "Singhalli", "Thanisandra", "Vidyaranyapura", "Yediyur", "Yelanka New Town"],
  "INDORE - RURAL": ["Ambamolya", "Ankya", "Jamli", "Panchderiya", "Tillore"],
  "INDORE - URBAN": ["Bangarda Chhota", "Bank", "Palda", "Piplya Kumar", "Rau"],
  "Isambe": ["Isambe"],
  "Khalapur": ["Asare", "Dharni", "Dharni Wadi", "Wadi"],
  "Palghar": ["Ambiwali", "Asroti", "Asuedi", "Dandwadi", "Isambe", "Isambe Wadi", "Kasatarwadi", "Kokari", "Kopri", "Lohop", "Lohop Wadi", "Lop", "Madap", "Majgaonvadi", "Mazgaon", "Nadode", "Nadodevadi", "Ningdoli", "Pali Khurd", "Paud", "Paud Wadi", "Sarang", "Saud And Baudhawadi", "Talawali", "Tupgaon", "Vadgaon", "Varad", "Vasai", "Wadgaon Vadi", "Wanawali", "Waras"],
  "Panvel(BB)": ["Antop Hill", "Chembur Mahul Gav", "Chita Camp", "Dadar East", "Dadar West", "Dharavi 90 Ft Road", "Govandi", "Kalamboli", "Maharashtra Nagar", "Mahim", "Mahim Fort", "Matunga Labour Camp", "Pant Nagar", "Rajiv Gandhi Nagar", "Shanti Nagar", "Sidharth Nagar", "Sion East", "Sion Koliwada", "Sion West", "Worli Koliwada"],
  "Nagpur": ["Bharkas", "Bhimnagar", "Bothali", "Butibori", "Deoli", "Deoli Grampanchaytâ Chowk", "Gandhi Khapari", "Gondwana", "Gondwana Shivaji Chowk", "Gondwana Ward No. 1", "Gondwana Ward No. 2", "Gosawi Nagar", "Kinhi", "Kirmiti", "Kolar", "Mandawa", "Mohgaon", "Parsodi", "Pipri", "Pohi", "Satgaon", "Shirur New", "Shirur Old", "Takalghat", "Tembhari", "Waranga", "Wateghat Shankar Nagar"],
  "Baramati": ["Ashram School", "Dombale Wasti", "Farm Society", "Gadadarwadi", "Ghumat Wasti", "Jagtapvasti & Patharvasti", "Khandobachiwadi", "Kuranvasti", "Laxminagar", "Mirewadi", "Navlevasti", "Nevasevasti", "Nimbut", "Other", "Padegaon", "Padegaon Farm Society", "Peer Society", "Pharandenagar", "Pharndenagar", "Raikar Wasti", "Tarathi", "Tarti Mala", "Vavare Wasti"],
  "Khed": ["Bharate Wadi", "Bhote Wadi", "Chandus", "Chimte Wadi", "Deshmukh", "Dhamane", "Dhamangaon", "Dhuvoli Wanjale", "Ganeshwadi", "Gargotewadi", "Kadlak Wadi", "Karvande Wadi", "Kiwale", "Kohinde", "Kudekar Vasti", "Nayfad", "Saburdi", "Sakurdi", "Shendurli", "Shirgaon Mandoshi", "Talavade", "Tardewadi", "Vadachiwadi", "Vajvane", "Vashire"],
  "Purandar": ["Nira", "Other", "Ward No. 06/ Nira"],
  "Pune Panasonic": ["Anjani Nagar", "Arebannimangala", "Attur", "Bhilarewadi", "Byatarayanapura", "Chowdeshwari", "Dattanagar", "Doddabommasandra", "Gokulnagar", "Hanumannagar", "Horamavu", "Jakkur", "Jambhulwadi", "Kampegowda Ward", "Khopadenagar", "Kondhpur Patha", "Mahadevakodigehalli", "Mylanahalli", "Pune Panasonic", "Rm Nagar", "Santosh Nagar", "Shantinagar", "Singnahalli", "Thanisandra", "Velu Gaon", "Vetal Bhuva Chouk", "Vidyaranyapura", "Yelahanka Satellite Town"],
  "Mumbai - Urban (Panvel)(BB)": ["Panvel Ward 1"],
  "Pune - Rural(BB)": ["Bhekrai Nagar", "Handewadi", "Mahammad Wadi", "Mancharwadi Phata", "Nande", "Phursungi", "Sarode Nagar", "Sasane Nagar", "Sayyad Nagar", "Undri", "Uruli Devachi", "Vadaki", "Vasant Nagar"],
  "Pune - Urban(BB)": ["Hadapsar"],
  "Ranjangaon Blok": ["Dhokasangvi", "Malthan", "Nimgao Bhogi", "Paritwadi", "Pimpri Dumala", "Ranjangaon", "Ranjangaon Village", "Skh Smc", "Sone Sangavi", "Sonesangvi", "Takalkarwadi", "Warude"],
  "Butibori": ["Ajangaon", "Bibi", "Chowki", "Dhokurda", "Ghoreghatak", "Kanholibara Cluster", "Saoli"],
  "Seloo": ["Akoli", "Amgaon", "Arvi Lahan", "Bhansuli", "Bhimnagar", "Bramhni", "Chimnazari", "Degma", "Dhanoli", "Gandhi Khapri", "Ghodadeo", "Gondapur", "Heti", "Jaipur", "Jamni", "Juwadi", "Kanhapur", "Khadka", "Khadki", "Khairi", "Kinhi", "Kukdi", "Lakhmapur", "Mahsala", "Mathni", "Matkazari", "Menkhat", "Morchapur", "Nanbardi", "Pardhi Beda1", "Pardhi Beda2", "Pipaldhara", "Ramna", "Sawali", "Sukli Bai", "Sukli Station", "Tamaswada", "Wadad", "Wadgaon Kala", "Wadgaon Khurd"],
  "Bamra": ["Babuniktimal", "Govindpuri", "Kestopur", "Khanpur", "Rampur"],
  "Sambalpur(BB)": ["Charmal", "Dhankauda", "Ghungapali", "Hatibari", "Jamankira", "Jujumura", "Kisinda", "Kukudapali", "Laida", "Maneswar", "Rengali"],
  "Ambala": ["Adho Majra", "Ahema", "Akout", "Amipur", "Anandpur", "Asarpur", "Babaheri", "Bahal", "Baknaur", "Balana", "Bara", "Barouli", "Batrohan", "Bedsan", "Bego Majra", "Bhanpur Nakatpur", "Bhanri", "Bhunni", "Bhurangpur", "Bosarkalan", "Budhapur", "Chapad", "Chaura", "Dakala", "Dhudhad", "Fatehpur", "Jahlan", "Jhandi", "Jogipur", "Kartarpur", "Kheri Gujran", "Lalina", "Main", "Naina Kaut", "Noorkhedia", "Rajgarh", "Sher Majra", "Sular", "Wazirpur"],
  "Mohali": ["Adarsh Colony", "Atawa", "Balongi", "Bar Majra", "Bhanri", "Jfl Phase 1 Industrial Area", "Khokha Market/Mohali Village", "Palsora", "Shahi Majra"],
  "SAS Nagar": ["Balongi", "Barmajra And Colonies", "Chajju Majra", "Daun", "Desu Majra", "Dhanas", "Jujhar Nagar", "Khokha Market", "Madanpur", "Maloya", "Naya Gaon", "Palsora", "Peeda", "Raipur", "Ramgarh", "Shahi Majra", "Shahpur", "Taga"],
  "Kapasan": ["Bagga Kheda", "Banakiya Kala", "Banakiya Khurd", "Bhawarkiya", "Chapari", "Chatarpura", "Chittorgarh", "Dolji Ka Kheda", "Gopal Pura", "Jhopadiya", "Jitiya", "Kakariya", "Kalyanpura", "Kathodiya", "Kodiya Khedi", "Langach", "Laxmipura", "Mata Ji Ka Kheda", "Moda Kheda", "Narela", "Nariya", "Pandoli Station", "Plnt", "Ramakheda", "Ren Ka Kheda", "Saropa", "Singhpur", "Sirodi", "Sisodio Ka Sawata", "Surajpura", "Test Dighwara"],
  "Thiruporur": ["Alathur", "Athigamanallur", "Echoor", "Ecr", "Edayarkuppam", "Illalur", "Kuzihipathandalam", "Madayathur", "Manamathy", "Paiyanur", "Pandithamedu", "Porunthavakkam", "Puliyure", "Sembakkam", "Sreedhavahur", "Thandalam", "Thiruporur"],
  "Chennai Urban and Rural": ["Besant Nagar", "Guindy", "Kottivakkam", "Neelankarai", "Palavakkam", "Perungudi", "Saidapet", "Taramani", "Thiruvanmiyur", "Velachery"],
  "Dothiguddem": ["Anthammagudem", "Bheemanpalle", "Chinnakondur", "Dharmojigudem", "Dothigudem", "Dothigudem (Unit Village)", "Guvambhavi", "Jiblakpalle", "Kanumukula", "Lakkaram", "Masid Gudem", "Other", "Pedda Kondur", "Pochampally", "Pochampally (Municipal Council)", "Sirrila", "Yellagiri", "Yellambhavi"],
  "Balanagar": ["Allapur", "Gayathrinagar", "Hanuman Nagar", "Motinagar", "Parvath Nagar", "Pragathi Nagar", "Radha Krishna Nagar", "Raj Nagar", "Rama Krishna Nagar", "Ramarao Nagar", "Saradhinagar"],
  "Hyderabad": ["Bharath Nagar", "Housing Board Kailashgiri Area", "Iala Office", "Mallapur Area Ashok Nagar Basti", "Mallapur Area Ntr Nagar", "Nacharam Area Baba", "Rtc Colony", "Shirdi Sai Baba Temple Premises"],
  "Maula Ali": ["Ambedkar Nagar", "Bjr Nagar", "Dammiguda", "Gandhi Nagar", "Hb Colony", "Malikarjuna Nagar", "Moula Ali Floor Hotel", "Moula Ali Gandhi Nagar", "Nadamuri Nagar", "Old Kapra", "Sai Nagar", "Sai Ram Colony", "Uppuguda Govdam", "Uppuguda Village", "Vijay School Kapra"],
  "Yousufguda": ["Moulali", "Nscb Nagar"],
  "Jubilee Hills": ["Ameerpet", "Banjara Hills", "Film Nagar", "Gachibowli", "Hitech City", "Kondapur", "Madhapur", "Manikonda", "Mehdipatnam", "Panjagutta", "Tolichowki"],
  "Ramalingampally": ["Ankireddipalli", "Anthammagudem", "Bommalaramaram", "Cheekati Mamidi", "Dharmojigudem", "Dothigudem", "Guvambhavi", "Hazipur", "Jalalpur", "Kanumukula", "Malyala", "Mandakini Palle", "Naginenipalle", "Peda Parvathapuram", "Pedda Kondur", "Pyararam", "Ramalingampally", "Rangapuram", "Sirilla", "Solipet", "Thumkunta", "Yavavpuram", "Yellagiri"],
  "Gajraula": ["Aehrola Tejwan", "Aehrolla", "Afzalpur Lut", "Agapur Kalan", "Agapur Khurd", "Agrola Kalan", "Alampur", "Allipur", "Asp Ltd", "Atalee", "Atarpura", "Azadpur Mafi", "Baansle", "Bagadpur Mafi", "Bahadurpur Ghulam Mohiuddinpur", "Bahaleelpur", "Baldana Asgarali Khan", "Baldana Heerasingh", "Barampur", "Barsabad", "Basaili", "Basantpur Ahatmali", "Basantpur Must.", "Baseli", "Basera", "Bastaura", "Bastaura Mafi", "Basti", "Batupura", "Bawanpura Mafi", "Bhagwanpur Bhur", "Bhagwanpur Khadar", "Bhandi", "Bhanpur", "Bharapur Mafi", "Bhekanpur Somali", "Bhikanpur", "Bijora", "Bilra Atmali", "Chak Dhanauri", "Chak Kudaina", "Chak Shawajpur", "Chaki Kheda", "Chandanpur Kheri", "Chaubara", "Chauhadpur Mafi", "Chauparwa", "Chhoya", "Chobara", "Choharpur", "Dariyapur", "Dhakka", "Dhoriya", "Fatehpur", "Fattepur", "Firozpur", "Foundapure", "Gajraula", "Hayatpur", "Hussanpur Gujjar", "Insilco", "Inslnoko", "Jalapur", "Jubilant", "Kakadar", "Kamrala Bahadurpur", "Kankather", "Kankathera", "Karanpur Mafi", "Katai", "Khanpur", "Khumabali", "Khungavli", "Khyalipur", "Kudaina", "Kudaini", "Kumraila", "Leesdhi", "Lisri", "Maheshra", "Mahmedpur", "Manota", "Matena", "Meerpur", "Mohammadabad", "Mohammadpur", "Moharka", "Moharka Patti", "Mohmadabad", "Moradabad", "Nagalmafi", "Naglishekh", "Naipura", "Navada", "Navda", "Other", "Other Villages", "Paal Salempur", "Pal", "Papsara", "Rajbapur", "Rakheda", "Rakhera", "Raunaq", "Rehdra", "Rehmapur Mafi", "Sabjwpur Dor", "Sadallapur", "Sadullapur", "Saidnagli", "Salempur", "Shabajpur", "Shahpur", "Shawajpurdor", "Sihali Gosai", "Sihali Jagir", "Sitajagatdevpur", "Sultanpur Ther", "Sultanther", "Takhatpur", "Tanda", "Tanta", "Teva", "Tigaria Bhood", "Tigariya", "Tigiriya Bhood", "Tigiriya Khaddar", "Tigri", "Tt Ltd", "Us Foods", "Yakbagdi"],
  "Hasanpur": ["Burablee", "Patai Khadar", "Rukhalu", "Sohrkaa", "Sutablee"],
  "Tulsipur": ["Aadamapur", "Aadamapur Maajara", "Aasakapur", "Adampur Bada Majra", "Aogarpur", "Bagadpurchodya", "Bagarpur", "Bahaadurapur Mishr", "Bahadurpur Mishra", "Bartaura", "Bartora", "Baska Kalan", "Baska Khurd", "Beejhalapur", "Bhabli", "Bhagpura", "Bhamoripatti", "Bhanda", "Bhandi", "Bhansari", "Bheema Thikri", "Bhogpura", "Bhoobara", "Bhuvra", "Bijnora", "Birampur", "Bukhaareepur", "Bukharipur", "Cachunagal", "Calamundi", "Chachora", "Chahchara", "Chakoonee", "Chaktari", "Chakuni", "Chamarapateee", "Chamarpatayi", "Chandankota", "Chandanpur", "Chapana", "Cheela", "Dadyal", "Dahari Khadan", "Damagada", "Dariyal", "Dariyapur Tugan", "Darrara", "Daulatpur Kalan", "Daurara", "Dayawali", "Dehri Gurjar", "Dehri Khadar", "Dhabaarasee", "Dhakiya Khadar", "Dhakola", "Doolhepuraheer", "Dorara", "Dulhepur Ahir", "Enta", "Fatehpur", "Fatehpur Adhek", "Firojpur", "Fulpur", "Gangat Kola", "Gangeshwari", "Gangwar", "Garavpur", "Gulampur", "Gurantha", "Haidalapur", "Hajipur", "Hakampur", "Hayaatapur", "Hayatpur", "Heesakheda", "Hernota", "Hirnota", "Imratpur", "Isaratapur", "Jaliopur", "Jebda Mustkam", "Jeevpur", "Jivpur", "Kai Dwitiya", "Kailmundi", "Karanpur", "Karanpur Khadar", "Kasaipura", "Kasampur", "Khadagaraasee", "Khadagrani", "Khajepur", "Khaliya Khalsa", "Khaliya Khalsha", "Khaliya Patti", "Khanaura", "Khandasoli", "Khanora", "Khanupura", "Kharkhaunda", "Kharpadi", "Kheliya Khalsa", "Khurtia", "Khurtiya", "Kokapur", "Ladybug", "Lakhanapur", "Lakhanpur", "Lalapur", "Lathman Ki Maddya", "Lathmar Ki Mandiya", "Latthmar Ki Madahaiya", "Lesda", "Lisra", "Machariya", "Madaripur", "Maharpur", "Makarandpur", "Makrandpur", "Malakpur", "Mangrola", "Marora", "Masakpur", "Matipura", "Meerpur Dabka", "Meharpur", "Mirzapur", "Mirzapurdungar", "Mubarijpur", "Mujahidpur", "Mungta", "Nagla Khadar", "Nanai", "Narabpura", "Navavpura", "Niryawalikhadar", "Ogarpur", "Ogpura", "Other", "Pashupura", "Pathra", "Patikhadar", "Paurara", "Pharnota", "Phatapur", "Phatehapuraghek", "Phoolpur", "Piploti Kala", "Piploti Khurd", "Porara", "Porara Jatavoowali", "Porara Sainiwali", "Preetamapur", "Pritampur", "Pursal", "Putsaal", "Rahra", "Rehra", "Rehrai", "Roharu", "Roopaanaagal", "Rukhalu", "Rupanagal", "Rustampur", "Rustampur Khadar", "Saandhalapur", "Sakatpur", "Salara", "Santhalpur", "Sehdramilk", "Shahadarmilk", "Shahbazpurdhola", "Shakarpur", "Shergarh", "Shitala Sarai", "Simthala", "Sirsakalan", "Sirsakalan 1", "Sirsanal", "Sirsha Kalan", "Sisona", "Sodhan Millak", "Sohat", "Soobara", "Subra", "Sultaanapurabheema", "Sultanpur Bheema", "Sutabli", "Sutaoli", "Sutarikhurd", "Tajpur Dungar", "Talaabadha", "Talabada", "Taranpur", "Taroli", "Tatarpur Sandal", "Tigariya Nadirshah", "Tigrianadirshah", "Ukabali", "Vbijhalpur"],
  "Araniya": ["Agora", "Ahmadgarh", "Ajnara", "Asroli", "Aterna", "Aurangabad", "Baad", "Bad", "Badagaon", "Badshahpur Paehgai", "Baghrai", "Bahanpur", "Baina", "Balrampur", "Banail", "Barasu", "Baroli(Shikarpur)", "Barula(Baruli)", "Basaich", "Bhadwa", "Bhagrai", "Bhaipur(Seekra)", "Bheekampur", "Bhojgarhi", "Bijili Pur", "Bulandshahr New", "Chapana", "Chauganpur", "Chingrawali", "Chitson", "Choroli", "Daheli", "Dalelgarhi", "Dalpatpur", "Dashari", "Daupur", "Deeghi", "Devrala", "Fatehabad", "Fatehgarh", "Gangagarh", "Gangaoli", "Gawaroli", "Ghatal", "Ghusrana Hari Singh", "Ghusranagail", "Gwaroli", "Hameer Pur", "Hameerpur", "Hesara", "Hinsoti", "Ibrahimpur (Got)", "Jagdishpur", "Jalalpur(Md.Ginori)", "Java", "Jeerajpur", "Jinamai", "Kailawan", "Kala-Khuri", "Kalena", "Kandher", "Karira", "Kariyawali", "Kasoomi", "Khailia-Kalyanpur", "Khakhoonda", "Khandar", "Kheda", "Khurdkheda", "Khutana", "Kiyoli Khurd", "Lalner", "Lalpur", "Mahagura(Satha)", "Maharajpur-Karkora", "Mahav", "Mahmoodpur (Shik.)", "Malgosa", "Malyosa", "Mamau", "Md.Pur Ginori", "Mouroni", "Mukehra", "N. Bhensroli", "N.Rai Singh", "Nagaliya", "Nagla Harisingh", "Nagla Rai Singh", "Naglajagat", "Naglia Takkar", "Naglia Udaibhan", "Nar Mohamad", "Nawada", "Neemka", "Nemtabad", "Oranga", "Other", "Pala", "Palra", "Parauli", "Peetampur", "Rahmapur", "Raipur Daheli", "Ramnagar", "Rampur Manpur", "Ramwas", "Ranaich", "Rasoolpur", "Rohinda", "Sabitgarh", "Sahar", "Salabad", "Salaimpur", "Salaimpur(P.Garhi)", "Salampur", "Salimpur (B)", "Samastpur", "Seekra", "Sendra Faridpur", "Shahpur", "Shehwajpurdaulat", "Shukla", "Shyalri", "Shyampur", "Siddhaâ Garhi", "Sohi", "Sooratpur Khurd", "Sujapur Putha", "Surajpur Putha", "Suratpur", "Surja Vali (Salempur)", "Turkipurawas", "Udaypur"],
  "Anamika Sugar": ["Asratpur", "Beehra", "Bhandoria", "Bondra", "Jamalpur", "Jitaka", "Khanoda", "Khawajpur", "Kheri", "Kisholi", "Lakhaoti", "Maheshpur", "Moodibakapur", "Muktesra", "Nimchana", "Other", "Pasoli", "Pipala", "Rajgarhi", "Tomri"],
  "Noida Location": ["Accher", "Aicchar Sector 36", "Begumpur", "Bironda", "Dadupur", "Greater Noida", "Imliyaka", "Janta Flat", "Kashiram Colony", "Kasna", "Khakrala Village Phase 2", "Malakpur", "Manakpur", "Rampur", "Silver City", "Surajpur", "Swarn Nagri Greater Noida"],
  "Dadri": ["Other"],
  "Dankaur": ["Aichhar", "Balla Ki Mandhiya", "Barsaat", "Begumpur", "Bimtech School", "Bironda", "Dabra", "Dadha", "Dadupur", "Ghangola", "Godi Bachheda", "Gujarpur", "Gulistanpur", "Imliyaka", "Jfl Kasna", "Jls G. Noida", "Jls G.Noida", "Kasna", "Kayampur", "Khanpur", "Luksar", "Natto Ki Mandiya", "Other", "Pubhari", "Raipur Banger", "Rampur Fatehpur", "Sirsa", "Surajpur", "Tugalpur"],
  "SNS Block": ["Dadupur", "Devla", "Fazayalpur", "Ghangola", "Imliyaka", "Jaitpur", "Kasna", "Khanpur", "Ladpura", "Luksar", "Maycha", "Mkoda", "Natto Ki Mandiya", "Nyana", "Rampur-Fatehpur", "Salempur Gujjar", "Shapur", "Sirsa", "Surajpur", "Til Begumpur"],
  "Padrauna": ["Abdulcheck", "Adrauna", "Adrauna Kairtiya Taula", "Ahirauli", "Amdariya", "Babhanavli", "Badahara A", "Badahara B", "Badahara C", "Badhara", "Bag Padhna", "Bahadurganj", "Bakha Mahadeva", "Bakhanti", "Bandhawa", "Bariyatola", "Barwa Bazar Khurd", "Barwa Mahadeva", "Barwa Sthan", "Barwakhurd", "Basantpur", "Basdila", "Bhatwaliya", "Bhuaisohara", "Bihuli Sumali", "Bisanpura", "Bishunpur Ab", "Chandarpur", "Chandarpur Ahirtola", "Chandarpur Barwa", "Chandarpur Bauliya", "Chandarpur Gobarhi", "Chandarpur Khash", "Chandarpur Lachhiya", "Chandarpur Malgahan", "Dandopur", "Dandopur Pratham", "Dhautikar", "Dhodharahi", "Dhuwatika", "Dir Chapra", "Hanumanganj", "Jadahan", "Jagal Chauriya", "Jagal Jagdeeshpur", "Jamunbakha", "Jayi Chhapra", "Kalwari Patti", "Kathinhiya", "Kathiniya", "Khairatiya", "Khairatwa", "Kotwa", "Kuia", "Kusmi", "Laukariya", "Machharahan", "Madhav Gauji", "Madhopur", "Maghimathia A", "Mandarey", "Mansha Chapra", "Mathiadheer", "Mathiya Dheer", "Mishrauli", "Mishrauli Khan Taula", "Mishroli", "Morvan A", "Morvan B", "Morwan", "Moti Chhapra", "Motipur", "Narsar", "Navgawa", "Other", "Padari", "Pakdi Bantir Somali", "Pakdi Bantir Sonha", "Papaur B", "Papur", "Pardi", "Parsoni", "Patehra", "Pathar Deva", "Pathardeva", "Pharna", "Pidari", "Piparbujurg", "Pipra Khurd", "Pipra Khurd A", "Porarah", "Rampur Khas", "Rowari", "Sahuadeeh", "Saithayi Misr", "Sanera Malchapra", "Saneramal Chapra", "Sapaha Khas", "Sapaha Mahto", "Saunha", "Sekhue Misra", "Shauraha Khurd", "Sidhawat Chhavni", "Sidhawat Khas", "Sirsiya Kala", "Sirsiya Khurd", "Siswa Mathiya", "Sohrauna", "Surya Nagar", "Sushwaliya", "Taydi", "Urdahan-2", "Urdha 3", "Urdha A", "Vijayi Chapra", "Vishunpura Upadhyay Tola"],
  "Vibhutikhand": ["Ahmamau", "Ahmatnagar Musahabganj", "Alam Nagar", "Arjunganj", "Bani", "Banthra", "Bharatpuri", "Bhudeswar", "Dubagga", "Gadi Kanura", "Gomti Nagar", "Guda Kaloni", "Juggaur", "Khasiram Aawash Yojana", "Mauriya", "Natwan Dera", "Sarojini Nagar", "Sohramau", "Tal Katora", "Tejikheda", "Vikas Nagar"],
  "Bhagatpur Tanda": ["Aalamgeerpur", "Abdllapur Leda", "Adalpur", "Alhepur", "Aliabad", "Amantabad", "Ashalempur", "Badhapur", "Bahadur Nagar", "Baidhnathpur", "Bairampur", "Balapur", "Bamaniya Patti", "Bankawala", "Begampur", "Bhagiyawala", "Bhaipur", "Bhood", "Bobad Wala", "Budh Nagar", "Cane Office", "Chandanpur", "Chandupur", "Darapur", "Dhakwala Majhra", "Dulhapur", "Eshapur", "Fatanpur", "Hospura", "Jofrabad", "Juladhakiya", "Kalewala", "Kanakpur", "Karanpur", "Khai Kheda", "Khaikhera", "Khwajpur", "Kotha Mahamood", "Kundesra", "Lalawala", "Lalpur Goshai", "Lodhipur Patti", "Madaiya Vijay Rampur", "Madarpur", "Madhowala", "Mahespur", "Mallupura", "Mill Gat Yard", "Mill Gate", "Mishripur", "Modhiharatpur", "Modihajratpur", "Mohaddeenpur", "Mohiadinpur", "Mulawaan", "Mustafabad", "Naharwala", "Naherwala", "Nangla Tahar", "Nirmalpur", "Other", "Paindapur", "Pashiyapura Padarath", "Pattimodha", "Pipli Ahir", "Raghuwala", "Rajpur Milak", "Rajupur Kala", "Rani Nagal", "Raninagal", "Ratupura", "Rehta Maafi", "Rooppur Tandola", "Sabalpur", "Salarpur", "Salempur", "Sarkada Param", "Sarkara Vishnoi", "Sarkoda Param", "Shareef Nagar", "Sherpur Behlin", "Sherpur Patti", "Sugar Mill", "Sultanpur Khaadar", "Sultanpur Khaddar", "Sultanpur Munda", "Tigri", "Triveni Raninagal", "Udairwala", "Veerwala"],
  "KHATAULI": ["A.Mouchri", "Ahmadgarh", "Ahroda", "Akbarpur Sadat", "Akhepur", "Ambarpur", "Amroli", "Anti", "Antwara", "Badsu", "Bahpur", "Basayach", "Bhainsi East", "Bhainsi West", "Bhaleri", "Bhalwa", "Bhamori", "Bhangi- Bhangela", "Bhanwada", "Bhoop Khedi", "Buada Kalan", "Buada Khurd", "Chacherpur", "Chandsamand", "Chandsinha", "Chinduada", "Chinduadi", "Chitora", "Chittoda", "Dabathua", "Dahaud", "Dandu Pur", "Daulatpur", "Dayal Puri", "Dedupur", "Dudhali", "Dukhchara", "Dungar(Maliyana)", "Fahimpur", "Faridpur", "Gadanpura", "Gagsona", "Galibpur", "Gangdhari", "Gaya Nagla", "Ghanshyam Pur", "Ghatayan North", "Ghatayan South", "Goyala", "Hazipur", "Inchoda", "Incholi", "Jamal Pur", "Jandhedi Jatan", "Jangethi", "Jansath", "Jasaula", "Jatpura", "Javan", "Jeet Pur", "Jhinjharpur", "Kadli", "Kaihalawada", "Kailash Nagar", "Kakrala", "Kakroli", "Kalyanpur", "Katka", "Kawal", "Khalidpur", "Khanjapur", "Khanpur", "Khata", "Khataula", "Khatauli", "Khaukhani", "Kheda Chongava", "Khedi Quresh", "Khedi Tagan", "Khera", "Kheri", "Kitash", "Kusawali", "Ladpur", "Lahaudda", "Lisauda", "Madkarimpur", "Maheshpur", "Maksuda Bad", "Mandawali Bangar", "Mandawali Khadar", "Mandwadi", "Manphoda", "Mantaudi", "Mathedi", "Mimla Khedi", "Mira Pur Khurd", "Mirapur Dalpat", "Mohammadpur", "Mohiuddinpur", "Moman", "Mubarikpur", "Mujahid Pur", "Mustafabad", "Naepura", "Nagla Sayani", "Nagli Ajhad", "Nagli Mahasingh", "Nagli Sadharan", "Nagoari", "Naidu", "Nanglarout", "Nayagav", "Nithari", "Nuni Kheda", "Other", "Paharpur Bangar", "Pal", "Palda", "Paldi", "Pamnawali", "Phalauda", "Phulat", "Pilona", "Pimoda", "Pipal Hera", "Poothkhas", "Puttha", "Rahavati", "Raipur Nangli", "Rampur", "Rampur Ghoriya", "Rardhana", "Rasulpur Kilaura", "Ratore", "Riyawali Nagla", "Ruhasa", "Rukanpur", "Sadpur", "Saidipur", "Sakauti", "Salava", "Samoli", "Sanota", "Sarai Rasulpur", "Sardhan", "Sathedi", "Shahpur", "Shekhpura", "Sikanderpur Kala", "Sikanderpur Khurd", "Sikeda(Gate)", "Siyajudi", "Sohjni", "Tabita", "Tajpur", "Tanda", "Tigri", "Tilora", "Tingai", "Tisung", "Titoda", "Tulsipur", "Vazidpur Kavvali", "Wajidpur Khurd", "Yahiyapur"],
  "Tanda": ["Akbarabad", "Ali Ganj", "Alianagar", "Allehpur", "Bathuwa Khera", "Bhubra Mustekam", "Bodhi Daryal", "Boobra", "Chack Khardiya", "Chakdulli", "Chandupura", "Chandupuri", "Darhiyal", "Fattawala", "Ghosipura", "Jamna Jamni", "Jatpura", "Khanpur", "Kishanpur", "Kundesra", "Kundesri", "Laddpur Bibi", "Lodhipur Nayak", "Lohara Inayat", "Mahua Khera", "Majhra Mubana", "Mirapur Mirganj", "Mohmadpur", "Mubana", "Nankar Rani", "Narayanpur", "Narpat Nagar", "Other", "Piplinayak", "Pursupura", "Puswara", "Rahmant Ganj", "Roopapur", "Sarakthal", "Shivnagar", "Sikampur", "Sirka", "Sithla"],
  "Deoband": ["Abdullah Pur", "Akbargarh", "Alamgir Pur (Doodhli", "Alawalpur", "Ali Pur", "Amarpur Gadhi", "Amarpur Nain", "Ambehta Sheikh", "Ambeta Shekha", "Amboli", "Arnayach", "Babupur", "Bachiti", "Baddedi", "Badedi Kala", "Badhai Kalan (Deh)", "Badhedi", "Badhedi Khurd", "Baduli", "Baduli_N", "Bago Wali (Rohana)", "Bahadar Pur", "Bahera", "Bajeed Pur", "Bajhedi", "Balu Majra", "Balu Majra_N", "Balwa Kheri", "Bandar Juda", "Bargaon", "Bargaon N", "Bastam", "Beerpur", "Begam Pur", "Belda Bujurg", "Bhaila Kalan", "Bhaila Khurd", "Bhanera Khass", "Bharapur", "Bhataul", "Bhatpura", "Bhawanpur", "Bhayla Khurd", "Bhaylakala", "Bibipur", "Bijo Pura", "Biralsi", "Bishan Pur(Gunarsi)", "Budha Khera", "Chandena Koli", "Chandpur", "Chandpur Majbata", "Chaukra", "Chaundahedi", "Chhimau", "Chiraon", "Dakowali", "Daleep Pura", "Dangheda", "Datiayana", "Dehchand", "Dehra", "Deoband First", "Deoband Iind", "Dharam Pur Gurjar", "Dhoom Garh", "Diwal Hedi", "Doodhli (Rohana)", "Dudhli", "Dugchada", "Dugchari", "Dulichandpur", "Falauda", "Farid Pur", "Fatehpur", "Fatehullah Pur", "Gangdaspur", "Ganjheri", "Ghalauli", "Ghiana", "Ghisar Padi", "Ghissu Khera", "Gopali", "Gunarsa", "Gunarsi", "Gurgaj Pur", "Hasimpur", "Hulas Garh", "Ibdullapur", "Imalia", "Ismail Pur", "Jagdei", "Jahirpur", "Jakhwala", "Jalal Pur Mazri", "Jaroda Jatt", "Jatola Damodar Pur", "Jatoul", "Jhaniran", "Kallan Hedi", "Kanjali", "Kapoori", "Kasim Pur", "Kasim Pur Niwada", "Kasoli", "Kayampur", "Kendki", "Khajuri", "Khandja Ahmedpur", "Khedi Junka", "Kheri Assa", "Khoja Nagla", "Khudda", "Kishan Pura", "Kishanpura", "Korwa", "Kota", "Kulseth", "Kuralki", "Kurdi", "Kutesra Ghangarh Pat", "Kutesra Ibrahim P.", "Kutesra Lakkad Patti", "Kutesra Shankarpatti", "Kutesra Suleman P.", "Labkari", "Lacchipur", "Lakhnaur", "Lakhnouti", "Laltala", "Luhari", "Lukadari", "Maheshpur", "Majari", "Majhol", "Makbara", "Makhiyali", "Manki", "Manohar Pur", "Mathura", "Maya Pur", "Mayaheri", "Megh Raj Pur", "Miragpur Dola Paripe", "Miragpur Dola Patti", "Miragpur Kakan Matri", "Miragpur Ruhaiya", "Mirzapur", "Mohdin Pur", "Mushkipur", "Nagli Noor", "Nanehra Kalan", "Nanheda Teeptan", "Nanhera Asha", "Nanhera Khurd", "Nasrullapur", "Naya Gaon", "Nihal Khedi", "Niyamatpur", "Niyamu", "Noorpur", "Nunawari", "Other", "Pachim Charthawal", "Pahupur", "Palauli", "Paniyali", "Phulas-A-Pur", "Phulasi", "Pipal Shaha", "Purvi Charthawal", "Rahmat Pur", "Rajju Pur", "Rammu Pur", "Rankhandi", "Rankhandi (Rohana)", "Ranmal Pur", "Ransura", "Rasoolpur Tank", "Rastam", "Ratan Hedi", "Reda", "Saadpur", "Sadharan Pur", "Sahji", "Sainpur", "Sakhan Kala", "Sakhan Khurd", "Salauni", "Salem Pur", "Salha Pur", "Sampla Bakkal", "Sampla Khatri", "Seedki", "Seedpura", "Shabbir Pur", "Shahpur", "Shakarpur Tigri", "Shekhupur", "Shekhupur Tak", "Shimlana", "Shiv Pur", "Shivdass Pur", "Sikanderpur", "Sirsali Kalan", "Sirsali Khurd", "Sisauni", "Sisona Jamalpur", "Subre", "Sultanpur", "Sunehti", "Taiyab Pur", "Talheri Buzurg", "Telheri Khurd", "Thithki", "Thokar Pur", "Tigri", "Tigri(Morna)", "Uncha Gaon"],
  "Rampur": ["Rampur Vill", "Rampur Vill Two"],
  "Sarsawa": ["Sarsawa Vill 1", "Sarsawa Vill 2"],
  "Roorkee": ["Bhagwanpur", "Chauli 1", "Chauli 2", "Chhangamajri", "Chhapur", "Dadda Pati", "Daudbassi", "Gee", "Hassanpur Madanpur", "Kawad", "Khanpur", "Khelpur", "Khubbanpur", "Lavva", "Makkhanpur", "Mandawar", "Other", "Raipur", "Ruhalki", "Sikanderpur", "Sirchandi", "Sisona"],
  "Purulia": ["Bahadurpur", "Chelod", "Churulia", "Domohani Basti", "Kalyanpur", "Lachhipur", "Narayanpur", "Panipathar", "Rangamatia", "Salapara"],
  "Bolpur": ["Bolpur Â€“ Shantiniketan", "Goalpara", "Kankalitola", "Kustikapara", "Pearson Pally", "Prantik", "Raipur", "Shyambati", "Surul"],
  "Siliguri Town": ["Ashighar Slum Cluster", "Bagdogra Bypass Urban Pockets", "Champasari More Settlements", "Matigara Basti", "Pradhan Nagar Slum Pocket", "Railway Colony Adjacent Slums", "Shivmandir Fringe Area", "Subhashpally Informal Cluster", "Ward 46 Â€“ College Para"],
  "Domjur": ["Baniyara", "Bhagabatipur", "Biki Hakola", "Bikihakola", "Bikihakola (Skpara)", "Biprannapara", "Dhamisa", "Dhulagori", "Hatisal", "Jele Para", "Kandua", "Kandua (Royel Club)", "Kandua (Yubak Sangha)", "Khan Para", "Kulai", "Monsatala", "Nabghora (Netaji Club)", "Nabghora (Ruidaspara)", "New Road", "Ranihati", "Ruidas Para", "Sandhipur", "Sulati (Samaj Kalyan Samiti)", "Sulati (Skpara)"],
  "Kandua": ["Kandua", "Nanghara", "Sulati"],
  "Panchla": ["Bikihakola"],
  "Pashchim Medinipur": ["Chaknorsingha"],
  "Howrah": ["Bamnani", "Bamunari Shiv Tola", "Bangihati Dakshin Para", "Bangihati Majher Para", "Bangihati Uttor Para", "Bibir Ber", "Bibir Beri", "Dhamisa", "Ghash Para", "Gumodanga-1", "Gumodanga-2", "Jaladhulagori", "Kandua", "Madhpur", "Madhpur-1", "Madhpur-2", "Mirpur", "Mollar Beri", "Mollerber Madrasa Math", "Monsatala", "Panchla", "Paniyara", "Sankrail", "Satghara", "Satghora", "Simla Kali Tola", "Simla Kalitola", "Sulati", "Vaduya"],
  "Mullick Bazar": ["Beck Bazaar", "Beniapukur", "Circus Avenue", "Circus Avenue Pavement Dwellers", "Deb Lane Slum Pocket", "Free School Street Cluster", "Mullick Bazar", "Nonapukur Slum Pocket", "Nonnapukur Slum", "Park Circus", "Park Circus Seven Point Area", "Raja Bazaar", "Ripon Street Informal Cluster", "Sealdah Peripheral", "Tijila Road Basti", "Tiljala Road Basti", "Topsia Canal East", "Ward 56 Â€“ Mullick Bazar"],
  "South 24 Parganas": ["Canning I Â€“ Chhoto Mollakhali", "Canning I Â€“ Durgapur", "Canning I Â€“ Gopalpur", "Canning I Â€“ Taldi", "Canning Ii Â€“ Atharabanki", "Canning Ii Â€“ Bamankhali", "Canning Ii Â€“ Deuli", "Canning Ii Â€“ Jatar Deul", "Canning Ii Â€“ Kalikatala", "Canning Ii Â€“ Narayanpur"],
};

// 18 states / 68 districts / 111 blocks / 3,488 villages
const List<String> kAllSymptoms = [
  'Fever','Cough','Cold','Headache','Body ache','Nausea','Vomiting','Diarrhoea','Fatigue',
  'Rash','Joint Pain','Sore throat','Runny nose','Abdominal Pain','Chills','Sweating','Dizziness',
  'Loss of Appetite','Shortness of breath','Chest pain','Weakness','Skin allergy/ Itching',
  'Burning Micturition','Retro-orbital pain','Platelet drop','Jaundice','Dehydration',
  'Frequent urination','Blood in urine','Night sweats','Weight loss','Wheezing','Ear pain',
  'Eye redness','Swelling','Bloating','Muscle cramps','Palpitations','Constipation','Stiffness',
  'Numbness','Hypertension','Acidity','Back Pain','Knee Pain'
];

/// Local-language / colloquial aliases → standard symptoms ("Did you mean").
const Map<String, List<String>> kSymAlias = {
  'gas': ['Bloating','Abdominal pain','Constipation','Nausea'],
  'bukhar': ['Fever','Chills','Body ache','Headache'],
  'khansi': ['Cough','Sore throat','Runny nose'],
  'sir dard': ['Headache','Dizziness','Nausea'],
  'ulti': ['Vomiting','Nausea','Dehydration'],
  'dast': ['Diarrhoea','Dehydration','Abdominal pain'],
  'loose motion': ['Diarrhoea','Dehydration','Abdominal pain'],
  'peshab': ['Burning micturition','Frequent urination'],
  'thakan': ['Fatigue','Weakness','Body ache'],
  'kamzori': ['Weakness','Fatigue','Dizziness'],
  'cold': ['Runny nose','Cough','Sore throat','Fever'],
  'flu': ['Fever','Cough','Body ache','Headache'],
  'stomach': ['Abdominal pain','Nausea','Bloating'],
  'dengue': ['Fever','Rash','Joint pain','Retro-orbital pain','Platelet drop'],
  'typhoid': ['Fever','Abdominal pain','Headache','Loss of appetite'],
  'bp': ['Headache','Dizziness','Chest pain','Palpitations'],
  'sugar': ['Frequent urination','Fatigue','Weight loss'],
};

/// Related symptoms suggested once a symptom is chosen.
const Map<String, List<String>> kRelated = {
  'fever': ['Chills','Sweating','Headache','Body ache','Fatigue','Loss of appetite'],
  'headache': ['Nausea','Dizziness','Photophobia','Vomiting'],
  'cough': ['Sore throat','Runny nose','Chest pain','Shortness of breath','Wheezing'],
  'body ache': ['Fatigue','Weakness','Joint pain'],
  'nausea': ['Vomiting','Loss of appetite','Abdominal pain','Diarrhoea'],
  'rash': ['Itching','Fever','Swelling'],
  'diarrhoea': ['Abdominal pain','Nausea','Vomiting','Dehydration'],
  'joint pain': ['Swelling','Stiffness','Fever'],
  'chills': ['Fever','Sweating','Headache'],
  'fatigue': ['Weakness','Dizziness','Loss of appetite'],
  'chest pain': ['Shortness of breath','Cough','Palpitations'],
  'abdominal pain': ['Nausea','Vomiting','Diarrhoea','Bloating'],
  'burning micturition': ['Frequent urination','Blood in urine','Lower abdominal pain'],
  'sore throat': ['Cough','Runny nose','Fever'],
  'vomiting': ['Nausea','Dehydration','Abdominal pain'],
  'shortness of breath': ['Chest pain','Cough','Wheezing'],
};

class GeoBlock {
  final String outbreaks;
  final List<String> geo;
  final List<DiseasePrior> diseases;
  const GeoBlock(this.outbreaks, this.geo, this.diseases);
}

class DiseasePrior {
  final String name;
  final int p;
  final String level; // h/m/l
  const DiseasePrior(this.name, this.p, this.level);
}

/// Block-wise outbreak / geo-common symptoms / disease priors.
const Map<String, GeoBlock> kGeoDb = {
  'Gajraula': GeoBlock(
    'Dengue (High), Viral Fever (Moderate)',
    ['Fever','Rash','Retro-orbital pain','Nausea','Platelet drop','Joint pain','Vomiting','Loss of appetite'],
    [DiseasePrior('Dengue Fever',78,'h'),DiseasePrior('Viral Fever',55,'m'),DiseasePrior('Malaria',22,'l'),DiseasePrior('Typhoid',15,'l')],
  ),
  'Amroha': GeoBlock(
    'Malaria (Moderate), Typhoid (Low)',
    ['Fever','Chills','Sweating','Abdominal pain','Diarrhoea','Headache','Jaundice'],
    [DiseasePrior('Malaria',62,'h'),DiseasePrior('Typhoid',38,'m'),DiseasePrior('Viral Fever',28,'l'),DiseasePrior('Gastroenteritis',20,'l')],
  ),
  'Hasanpur': GeoBlock(
    'URTI (Moderate), Gastroenteritis (Low)',
    ['Cough','Runny nose','Sore throat','Diarrhoea','Fever','Vomiting'],
    [DiseasePrior('URTI',52,'h'),DiseasePrior('Gastroenteritis',35,'m'),DiseasePrior('Viral Fever',22,'l'),DiseasePrior('Dengue Fever',10,'l')],
  ),
  'Dankaur': GeoBlock(
    'Viral Fever (Moderate), Typhoid (Low)',
    ['Fever','Headache','Body ache','Diarrhoea','Abdominal pain','Fatigue'],
    [DiseasePrior('Viral Fever',48,'m'),DiseasePrior('Typhoid',32,'m'),DiseasePrior('Gastroenteritis',25,'l'),DiseasePrior('URTI',18,'l')],
  ),
  'Dadri': GeoBlock(
    'URTI (Low), Pneumonia (Low)',
    ['Cough','Shortness of breath','Chest pain','Fever','Fatigue','Wheezing'],
    [DiseasePrior('URTI',40,'m'),DiseasePrior('Pneumonia',30,'l'),DiseasePrior('Acute Bronchitis',22,'l'),DiseasePrior('Viral Fever',15,'l')],
  ),
};

/// Disease → weighted symptoms, for "Likely Conditions" scoring.
const Map<String, Map<String, int>> kDiseaseDb = {
  'Dengue Fever': {'Fever':3,'Headache':2,'Retro-orbital pain':3,'Rash':2,'Joint pain':2,'Platelet drop':3,'Nausea':1,'Vomiting':1,'Body ache':2,'Fatigue':1},
  'Malaria': {'Fever':3,'Chills':3,'Sweating':3,'Headache':2,'Body ache':2,'Nausea':1,'Fatigue':2,'Jaundice':2},
  'Typhoid': {'Fever':3,'Headache':2,'Abdominal pain':3,'Diarrhoea':2,'Loss of appetite':2,'Fatigue':2,'Nausea':1,'Body ache':1},
  'Viral Fever': {'Fever':3,'Headache':2,'Body ache':2,'Fatigue':2,'Runny nose':1,'Sore throat':1,'Cough':1,'Chills':1,'Weakness':1},
  'URTI': {'Cough':3,'Sore throat':3,'Runny nose':3,'Fever':2,'Headache':1,'Body ache':1,'Fatigue':1},
  'Pneumonia': {'Fever':3,'Cough':3,'Shortness of breath':3,'Chest pain':2,'Fatigue':2,'Chills':2,'Wheezing':1},
  'Gastroenteritis': {'Diarrhoea':3,'Vomiting':3,'Abdominal pain':2,'Nausea':2,'Fever':1,'Dehydration':3},
  'Chikungunya': {'Fever':3,'Joint pain':3,'Rash':2,'Headache':2,'Fatigue':2,'Body ache':2,'Swelling':2},
  'UTI': {'Burning micturition':3,'Frequent urination':3,'Blood in urine':2,'Fever':2},
  'Hypertension': {'Headache':2,'Dizziness':2,'Chest pain':1,'Palpitations':2,'Shortness of breath':1,'Fatigue':1},
  'Diabetes Type 2': {'Frequent urination':2,'Fatigue':2,'Weight loss':2,'Weakness':1,'Numbness':2},
};

class ScoredDisease {
  final String name;
  final int pct;
  final String level; // h/m/l
  const ScoredDisease(this.name, this.pct, this.level);
}

/// Score likely conditions from chosen symptoms + block geo prior boost.
List<ScoredDisease> scoreDiseases(List<String> symptoms, String? block) {
  final geo = kGeoDb[block] ?? kGeoDb['Gajraula']!;
  final res = <ScoredDisease>[];
  kDiseaseDb.forEach((name, weights) {
    var sc = 0, mx = 0;
    for (final s in symptoms) {
      sc += weights[s] ?? 0;
    }
    for (final v in weights.values) {
      mx += v;
    }
    var pct = mx > 0 ? (sc / mx * 100).round() : 0;
    final hasGeo = geo.diseases.any((d) => d.name == name);
    if (hasGeo) pct = (pct + 15).clamp(0, 98);
    if (pct >= 10) {
      res.add(ScoredDisease(name, pct, pct >= 60 ? 'h' : (pct >= 35 ? 'm' : 'l')));
    }
  });
  res.sort((a, b) => b.pct.compareTo(a.pct));
  return res.take(6).toList();
}

const List<String> kBloodGroups = ['O+','O-','A+','A-','B+','B-','AB+','AB-'];
const List<String> kCategories = ['General','OBC','SC','ST','N/A'];
const List<String> kDoctors = ['Dr. Aakanksha','Dr. Kedar','Dr. Nitin'];
const List<String> kCampTypes = ['Community','School','Workplace','Health Awareness'];
const List<String> kDeviceNames = ['Sphygmomanometer','Glucometer','Haemoglobinometer','Weighing Machine'];
const List<String> kDeviceStates = ['Working','Not Working','Not Applicable','Purchase Requested'];
