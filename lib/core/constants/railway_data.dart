class RailwayData {
  /// Complete mapping of Railway Zones to their Divisions and Cities
  static const Map<String, Map<String, List<String>>> data = {
    'Central Railway': {
      'Mumbai CST': ['Mumbai CSMT', 'Dadar', 'Kalyan', 'Thane', 'Lonavala', 'Igatpuri'],
      'Bhusawal': ['Bhusawal', 'Jalgaon', 'Nashik Road', 'Akola', 'Khandwa', 'Burhanpur'],
      'Pune': ['Pune', 'Shivajinagar', 'Miraj', 'Kolhapur'],
      'Solapur': ['Solapur', 'Kalaburagi (Gulbarga)', 'Kurduvadi', 'Ahmednagar', 'Daund'],
      'Nagpur CR': ['Nagpur', 'Wardha', 'Ballarshah', 'Chandrapur'],
    },
    'Western Railway': {
      'Ratlam': ['Ratlam', 'Indore', 'Ujjain', 'Nagda', 'Chittaurgarh', 'Dr. Ambedkar Nagar (Mhow)'],
      'Mumbai Central': ['Mumbai Central', 'Bandra Terminus', 'Surat', 'Valsad', 'Vapi', 'Navsari'],
      'Vadodara': ['Vadodara', 'Anand', 'Bharuch', 'Godhra', 'Nadiad'],
      'Ahmedabad': ['Ahmedabad', 'Gandhinagar Capital', 'Palanpur', 'Mahesana', 'Bhuj'],
      'Rajkot': ['Rajkot', 'Surendranagar', 'Okha', 'Dwarka', 'Jamnagar'],
      'Bhavnagar': ['Bhavnagar Terminus', 'Porbandar', 'Veraval', 'Junagadh', 'Somnath'],
    },
    'Northern Railway': {
      'Delhi': ['New Delhi', 'Old Delhi', 'Hazrat Nizamuddin', 'Rohtak', 'Meerut', 'Panipat'],
      'Ambala': ['Ambala Cantt', 'Chandigarh', 'Saharanpur', 'Kalka', 'Bathinda', 'Patiala'],
      'Firozpur': ['Firozpur', 'Ludhiana', 'Jalandhar', 'Amritsar', 'Jammu Tawi', 'Shri Mata Vaishno Devi Katra'],
      'Lucknow NR': ['Lucknow Charbagh', 'Varanasi Cantt', 'Ayodhya Cantt', 'Rae Bareli', 'Pratapgarh'],
      'Moradabad': ['Moradabad', 'Bareilly', 'Haridwar', 'Dehradun', 'Roorkee'],
    },
    'North Central Railway': {
      'Prayagraj': ['Prayagraj Junction', 'Kanpur Central', 'Aligarh', 'Mirzapur', 'Etawah'],
      'Agra': ['Agra Cantt', 'Mathura', 'Idgah Agra', 'Raja Ki Mandi'],
      'Jhansi': ['VGL Jhansi', 'Gwalior', 'Banda', 'Mahoba', 'Lalitpur'],
    },
    'North Western Railway': {
      'Jaipur': ['Jaipur', 'Alwar', 'Rewari', 'Phulera', 'Kishangarh'],
      'Ajmer': ['Ajmer', 'Udaipur City', 'Bhilwara', 'Abu Road', 'Marwar Junction'],
      'Bikaner': ['Bikaner', 'Sri Ganganagar', 'Hisar', 'Bhiwani', 'Churu'],
      'Jodhpur': ['Jodhpur', 'Jaisalmer', 'Barmer', 'Pali Marwar', 'Nagaur'],
    },
    'West Central Railway': {
      'Jabalpur': ['Jabalpur', 'Katni', 'Satna', 'Rewa', 'Pipariya', 'Maihar'],
      'Bhopal': ['Bhopal', 'Rani Kamlapati', 'Itarsi', 'Bina', 'Vidisha', 'Harda'],
      'Kota': ['Kota', 'Sawai Madhopur', 'Bharatpur', 'Ramganj Mandi', 'Bundi'],
    },
    'Eastern Railway': {
      'Howrah': ['Howrah', 'Bardhaman', 'Bandel', 'Rampurhat'],
      'Sealdah': ['Sealdah', 'Naihati', 'Ranaghat', 'Krishnanagar', 'Barasat'],
      'Asansol': ['Asansol', 'Durgapur', 'Jasidih', 'Madhupur', 'Andal'],
      'Malda': ['Malda Town', 'Bhagalpur', 'Jammalpur', 'Sahibganj'],
    },
    'East Central Railway': {
      'Danapur': ['Patna', 'Danapur', 'Ara', 'Buxar', 'Mokama', 'Rajgir'],
      'Pt. Deen Dayal Upadhyaya': ['DDU Junction (Mughalsarai)', 'Gaya', 'Sasaram', 'Dehri-on-Sone'],
      'Dhanbad': ['Dhanbad', 'Gomoh', 'Barkakana', 'Chopan', 'Koderma'],
      'Samastipur': ['Samastipur', 'Darbhanga', 'Saharsa', 'Raxaul', 'Jaynagar'],
      'Sonpur': ['Sonpur', 'Hajipur', 'Muzaffarpur', 'Barauni', 'Khagaria'],
    },
    'North Eastern Railway': {
      'Lucknow NER': ['Lucknow Junction', 'Gorakhpur', 'Gonda', 'Basti', 'Sitapur'],
      'Izzatnagar': ['Bareilly City', 'Kathgodam', 'Pilibhit', 'Kasganj', 'Haldwani'],
      'Varanasi': ['Varanasi City', 'Chhapra', 'Mau', 'Ballia', 'Ghazipur'],
    },
    'Northeast Frontier Railway': {
      'Lumding': ['Lumding', 'Guwahati', 'Badarpur', 'Silchar', 'Agartala'],
      'Katihar': ['Katihar', 'New Jalpaiguri', 'Kishanganj', 'Purnea', 'Darjeeling'],
      'Alipurduar': ['Alipurduar Junction', 'New Cooch Behar', 'Siliguri'],
      'Rangiya': ['Rangiya', 'New Bongaigaon', 'Barpeta Road', 'Goalpara'],
      'Tinsukia': ['Tinsukia', 'Dibrugarh', 'Mariani', 'Jorhat'],
    },
    'South Central Railway': {
      'Secunderabad': ['Secunderabad', 'Kazipet', 'Warangal', 'Bidar', 'Khammam'],
      'Hyderabad': ['Hyderabad Deccan (Nampally)', 'Kurnool City', 'Nizamabad', 'Kacheguda', 'Mahbubnagar'],
      'Nanded': ['Hazur Sahib Nanded', 'Aurangabad', 'Jalna', 'Parbhani', 'Purna'],
    },
    'Southern Railway': {
      'Chennai': ['Chennai Central', 'Chennai Egmore', 'Arakkonam', 'Katpadi', 'Tambaram'],
      'Tiruchirappalli': ['Tiruchirappalli', 'Thanjavur', 'Villupuram', 'Nagapattinam', 'Kumbakonam'],
      'Madurai': ['Madurai', 'Tirunelveli', 'Dindigul', 'Tuticorin', 'Rameswaram'],
      'Palakkad': ['Palakkad', 'Mangaluru', 'Shoranur', 'Kozhikode', 'Kannur'],
      'Salem': ['Salem', 'Coimbatore', 'Erode', 'Tiruppur', 'Karur'],
      'Thiruvananthapuram': ['Thiruvananthapuram', 'Ernakulam', 'Thrissur', 'Kanyakumari', 'Kottayam'],
    },
    'South Western Railway': {
      'Hubballi': ['Hubballi', 'Dharwad', 'Hosapete', 'Belagavi', 'Vasco-da-Gama', 'Ballari'],
      'Bengaluru': ['KSR Bengaluru', 'Yesvantpur', 'Bangarapet', 'Krishnarajapuram', 'Kengeri'],
      'Mysuru': ['Mysuru', 'Hassan', 'Shivamogga Town', 'Davangere', 'Arsikere'],
    },
    'South Eastern Railway': {
      'Kharagpur': ['Kharagpur', 'Balasore', 'Shalimar', 'Santragachi', 'Panskura'],
      'Chakradharpur': ['Chakradharpur', 'Tatanagar (Jamshedpur)', 'Rourkela', 'Jharsuguda'],
      'Adra': ['Adra', 'Purulia', 'Bokaro Steel City', 'Bankura', 'Bishnupur'],
      'Ranchi': ['Ranchi', 'Hatia', 'Muri'],
    },
    'South East Central Railway': {
      'Bilaspur': ['Bilaspur', 'Raigarh', 'Champa', 'Anuppur', 'Korba'],
      'Raipur': ['Raipur', 'Durg', 'Bhilai Power House', 'Bhatapara'],
      'Nagpur SEC': ['Nagpur (Itwari)', 'Gondia', 'Bhandara Road', 'Dongargarh'],
    },
    'East Coast Railway': {
      'Khurda Road': ['Bhubaneswar', 'Puri', 'Cuttack', 'Khurda Road', 'Brahmapur'],
      'Sambalpur': ['Sambalpur', 'Titlagarh', 'Balangir', 'Bargarh'],
      'Rayagada': ['Rayagada', 'Koraput', 'Gunupur', 'Malkangiri'],
    },
    'South Coast Railway': {
      'Visakhapatnam': ['Visakhapatnam', 'Vizianagaram', 'Srikakulam'],
      'Vijayawada': ['Vijayawada', 'Rajahmundry', 'Eluru', 'Nellore', 'Ongole'],
      'Guntur': ['Guntur', 'Nandyal', 'Nadikudi', 'Narsaraopet'],
      'Guntakal': ['Guntakal', 'Tirupati', 'Raichur', 'Kadapa', 'Renigunta', 'Anantapur'],
    },
    'Konkan Railway': {
      'Ratnagiri': ['Ratnagiri', 'Chiplun', 'Khed', 'Sindhudurg'],
      'Karwar': ['Karwar', 'Udupi', 'Madgaon', 'Murdeshwar'],
    },
    'Kolkata Metro Railway': {
      'Headquarters': ['Kolkata'],
    },
  };

  /// List of all Railway Zones (18 zones based on the provided data)
  static List<String> get zones => data.keys.toList();

  static List<String> getDivisionsForZone(String? zone) {
    if (zone == null || zone.trim().isEmpty) return ['Unknown Division'];
    
    final matchedZoneKey = data.keys.firstWhere(
      (k) => k.toLowerCase() == zone.trim().toLowerCase(),
      orElse: () => '',
    );
    
    if (matchedZoneKey.isEmpty) return ['Unknown Division'];
    
    final divisionsMap = data[matchedZoneKey];
    final divisions = divisionsMap?.keys.toList() ?? [];
    return divisions.isNotEmpty ? divisions : ['Unknown Division'];
  }
  
  /// Check if a zone has divisions available
  static bool hasDivisions(String? zone) {
    return getDivisionsForZone(zone).isNotEmpty;
  }

  static List<String> getCitiesForDivision(String? zone, String? division) {
    if (zone == null || zone.trim().isEmpty || division == null || division.trim().isEmpty) return ['Unknown City'];
    
    final matchedZoneKey = data.keys.firstWhere(
      (k) => k.toLowerCase() == zone.trim().toLowerCase(),
      orElse: () => '',
    );
    
    if (matchedZoneKey.isEmpty) return ['Unknown City'];
    
    final divisionsMap = data[matchedZoneKey]!;
    
    final matchedDivKey = divisionsMap.keys.firstWhere(
      (k) => k.toLowerCase() == division.trim().toLowerCase(),
      orElse: () => '',
    );
    
    if (matchedDivKey.isEmpty) {
      final allCities = divisionsMap.values.expand((cities) => cities).toSet().toList();
      return allCities.isNotEmpty ? allCities : ['Unknown City'];
    }
    
    final cities = divisionsMap[matchedDivKey] ?? [];
    return cities.isNotEmpty ? cities : ['Unknown City'];
  }
  
  /// Check if a division has cities available
  static bool hasCities(String? zone, String? division) {
    return getCitiesForDivision(zone, division).isNotEmpty;
  }
}
