class PowierzchniaModel {
  String numer;
  List<String> adres;
  List<String> warstwa;
  int nachylenie; // Default value set to 100
  double azymutNachylenia; // Slope azimuth (0 - 360 degrees, 1000.0 if unset)
  double maxRadius; // <-- Added maxRadius variable with default 0
  List<DrzewoModel> drzewa;
  List<Gatunek> gatunki;
  String notes;
  Map<String, String> completion;

  PowierzchniaModel({
    required this.numer,
    List<String>? adres,
    List<String>? warstwa,
    int? nachylenie,
    double? azymutNachylenia,
    double? maxRadius, // <-- Added to constructor
    List<DrzewoModel>? drzewa,
    List<Gatunek>? gatunki,
    String? notes,
    Map<String, String>? completion,
  })  : adres = adres ?? [],
        warstwa = warstwa ?? [],
        nachylenie = nachylenie ?? 100,
        azymutNachylenia = azymutNachylenia ?? 1000.0,
        maxRadius = maxRadius ?? 0.0, // <-- Default to 0.0 if null
        drzewa = drzewa ?? [],
        gatunki = gatunki ?? [],
        notes = notes ?? '',
        completion = completion ?? {'completion': 'notEdited'};

  factory PowierzchniaModel.fromJson(Map<String, dynamic> json) {
    var drzewaFromJson = json['drzewa'] as List?;
    List<DrzewoModel> parsedDrzewa = drzewaFromJson != null
        ? drzewaFromJson.map((i) => DrzewoModel.fromJson(Map<String, dynamic>.from(i))).toList()
        : [];

    var gatunkiFromJson = json['gatunki'] as List?;
    List<Gatunek> parsedGatunki = gatunkiFromJson != null
        ? gatunkiFromJson.map((i) => Gatunek.fromJson(Map<String, dynamic>.from(i))).toList()
        : [];

    // Safely parse the list of strings for 'adres'
    List<String> parsedAdres = [];
    if (json['adres'] is List) {
      parsedAdres = (json['adres'] as List)
          .map((e) => e.toString())
          .toList();
    } else if (json['adres'] != null) {
      parsedAdres = [json['adres'].toString()];
    }

    // Safely parse the list of strings for 'warstwa', defaulting to ['1'] if missing or malformed
    List<String> parsedWarstwa = ['1'];
    if (json['warstwa'] is List) {
      parsedWarstwa = (json['warstwa'] as List)
          .map((e) => e.toString())
          .toList();

      if (parsedWarstwa.isEmpty) {
        parsedWarstwa = ['1'];
      }
    } else if (json['warstwa'] != null) {
      parsedWarstwa = [json['warstwa'].toString()];
    }

    // Safely parse 'nachylenie', defaulting to 100 if missing or invalid
    int parsedNachylenie = int.tryParse(json['nachylenie']?.toString() ?? '100') ?? 100;

    // Safely parse 'azymutNachylenia', defaulting to 1000.0 if missing or invalid
    double parsedAzymutNachylenia = double.tryParse(json['azymutNachylenia']?.toString() ?? '1000.0') ?? 1000.0;

    // Safely parse 'maxRadius', defaulting to 0.0 if missing or invalid
    double parsedMaxRadius = double.tryParse(json['maxRadius']?.toString() ?? '0.0') ?? 0.0;

    // Safely parse the 'completion' map, defaulting to 'notEdited' to prevent null errors on legacy JSON data
    Map<String, String> parsedCompletion = {'completion': 'notEdited'};
    if (json['completion'] is Map) {
      parsedCompletion = Map<String, String>.from(json['completion']);
    }

    return PowierzchniaModel(
      numer: json['numer'] ?? '',
      adres: parsedAdres,
      warstwa: parsedWarstwa,
      nachylenie: parsedNachylenie,
      azymutNachylenia: parsedAzymutNachylenia,
      maxRadius: parsedMaxRadius, // <-- Loaded into constructor
      drzewa: parsedDrzewa,
      gatunki: parsedGatunki,
      notes: json['notes']?.toString() ?? '',
      completion: parsedCompletion,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'numer': numer,
      'adres': adres,
      'warstwa': warstwa,
      'nachylenie': nachylenie,
      'azymutNachylenia': azymutNachylenia,
      'maxRadius': maxRadius, // <-- Saved to JSON
      'drzewa': drzewa.map((t) => t.toJson()).toList(),
      'gatunki': gatunki.map((g) => g.toJson()).toList(),
      'notes': notes,
      'completion': completion,
    };
  }
}


class DrzewoModel {
  final int numer;
  String powierzchniaNumer;
  String gatunek;
  Map<String, String> typ;
  String warstwa;
  double srednica;
  double wysokosc;
  double? azymut;
  double odl;
  int wiek;
  int klasaRozkladu;
  bool wysRequired;
  String notes;
  List<String> listDates; // <-- NEW PARAMETER

  DrzewoModel({
    required this.numer,
    required this.powierzchniaNumer,
    required this.gatunek,
    required this.typ,
    required this.warstwa,
    required this.srednica,
    required this.wysokosc,
    this.azymut,
    required this.odl,
    required this.wiek,
    required this.klasaRozkladu,
    this.wysRequired = false,
    this.notes = '',
    this.listDates = const [], // <-- Defaults to empty list
  });

  factory DrzewoModel.fromJson(Map<String, dynamic> json) {
    // --- SAFELY PARSE THE NEW MAP TYPE ---
    Map<String, String> parsedTyp = {'state': 'zywe', 'type': ''}; // Fallback default

    if (json['typ'] is Map) {
      // If it's already saved in the new Map format, cast it directly
      parsedTyp = Map<String, String>.from(json['typ'] as Map);
    } else if (json['typ'] is String) {
      // Legacy support: Convert old String format to the new Map format
      String legacyTyp = json['typ'].toString();
      if (legacyTyp == 'zywe') {
        parsedTyp = {'state': 'zywe', 'type': ''};
      } else {
        // If it was 'martwe', 'posusz', 'zlomy', etc.
        parsedTyp = {
          'state': 'martwe',
          'type': legacyTyp == 'martwe' ? '' : legacyTyp,
        };
      }
    }

    // --- SAFELY PARSE LIST OF DATES ---
    var datesFromJson = json['list_dates'] as List?;
    List<String> parsedDates = datesFromJson != null
        ? datesFromJson.map((e) => e.toString()).toList()
        : [];

    return DrzewoModel(
      numer: json['numer'] ?? 0,
      powierzchniaNumer: json['powierzchnia_numer']?.toString() ?? '',
      gatunek: json['gatunek']?.toString() ?? '',
      typ: parsedTyp,
      warstwa: json['warstwa']?.toString() ?? '',
      srednica: (json['srednica'] ?? 0.0).toDouble(),
      wysokosc: (json['wysokosc'] ?? 0.0).toDouble(),
      azymut: json['azymut'] != null ? (json['azymut']).toDouble() : null,
      odl: (json['odl'] ?? 0.0).toDouble(),
      wiek: json['wiek'] ?? 0,
      klasaRozkladu: json['klasa_rozkladu'] ?? 0,
      wysRequired: json['wys_required'] ?? false,
      notes: json['notes']?.toString() ?? '',
      listDates: parsedDates, // <-- Load list of dates
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'numer': numer,
      'powierzchnia_numer': powierzchniaNumer,
      'gatunek': gatunek,
      'typ': typ,
      'warstwa': warstwa,
      'srednica': srednica,
      'wysokosc': wysokosc,
      'azymut': azymut,
      'odl': odl,
      'wiek': wiek,
      'klasa_rozkladu': klasaRozkladu,
      'wys_required': wysRequired,
      'notes': notes,
      'list_dates': listDates, // <-- Save list of dates
    };
  }
}

class Gatunek {
  String nazwa;
  int wiek;

  Gatunek({
    required this.nazwa,
    this.wiek = 0,
  });

  factory Gatunek.fromJson(Map<String, dynamic> json) {
    return Gatunek(
      nazwa: json['nazwa'] ?? json['name'] ?? json['gatunek'] ?? '',
      wiek: int.tryParse(json['wiek']?.toString() ?? json['age']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nazwa': nazwa,
      'wiek': wiek,
    };
  }
}

class WydzielenieModel {
  final String numPp;
  final List<String> adressLes;
  final List<String> numWydz;
  final List<int> sampleIntNum;
  final List<int> arodesIntNum;
  final List<Gatunek> listOfTrees;
  final Map<String, dynamic> geograficData; // Mapped from survey_data[cite: 6]

  // Fields are marked as final because this model is strictly read-only
  WydzielenieModel({
    required this.numPp,
    required this.adressLes,
    required this.numWydz,
    required this.sampleIntNum,
    required this.arodesIntNum,
    required this.listOfTrees,
    required this.geograficData,
  });

  factory WydzielenieModel.fromJson(Map<String, dynamic> json) {
    var treesFromJson = json['list_of_trees'] as List?;
    List<Gatunek> parsedTrees = treesFromJson != null
        ? treesFromJson.map((i) => Gatunek.fromJson(Map<String, dynamic>.from(i))).toList()
        : [];

    return WydzielenieModel(
      numPp: json['num_pp']?.toString() ?? '',
      adressLes: (json['adress_les'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      numWydz: (json['num_wydz'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      sampleIntNum: (json['sample_int_num'] as List<dynamic>?)?.map((e) => int.tryParse(e.toString()) ?? 0).toList() ?? [],
      arodesIntNum: (json['arodes_int_num'] as List<dynamic>?)?.map((e) => int.tryParse(e.toString()) ?? 0).toList() ?? [],
      listOfTrees: parsedTrees,
      // Mapping the new survey_data key[cite: 6]
      geograficData: json['survey_data'] != null
          ? Map<String, dynamic>.from(json['survey_data'])
          : <String, dynamic>{},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'num_pp': numPp,
      'adress_les': adressLes,
      'num_wydz': numWydz,
      'sample_int_num': sampleIntNum,
      'arodes_int_num': arodesIntNum,
      'list_of_trees': listOfTrees.map((t) => t.toJson()).toList(),
      'survey_data': geograficData, // Exports back to survey_data[cite: 6]
    };
  }
}

// class WydzielenieModel {
//   final String numPp;
//   final String adressLes;
//   final String numWydz;
//   final int sampleIntNum;
//   final int arodesIntNum;
//   final List<Gatunek> listOfTrees;
//   final Map<String, dynamic> geograficData; // Added geographic data map
//
//   // Fields are marked as final because this model is strictly read-only
//   WydzielenieModel({
//     required this.numPp,
//     required this.adressLes,
//     required this.numWydz,
//     required this.sampleIntNum,
//     required this.arodesIntNum,
//     required this.listOfTrees,
//     required this.geograficData, // Added to constructor
//   });
//
//   factory WydzielenieModel.fromJson(Map<String, dynamic> json) {
//     var treesFromJson = json['list_of_trees'] as List?;
//     List<Gatunek> parsedTrees = treesFromJson != null
//         ? treesFromJson.map((i) => Gatunek.fromJson(Map<String, dynamic>.from(i))).toList()
//         : [];
//
//     return WydzielenieModel(
//       numPp: json['num_pp']?.toString() ?? '',
//       adressLes: json['adress_les']?.toString() ?? '',
//       numWydz: json['num_wydz']?.toString() ?? '',
//       sampleIntNum: int.tryParse(json['sample_int_num']?.toString() ?? '') ?? 0,
//       arodesIntNum: int.tryParse(json['arodes_int_num']?.toString() ?? '') ?? 0,
//       listOfTrees: parsedTrees,
//       // Safely parse the map, defaulting to an empty map if null
//       geograficData: json['geografic_data'] != null
//           ? Map<String, dynamic>.from(json['geografic_data'])
//           : <String, dynamic>{},
//     );
//   }
//
//   Map<String, dynamic> toJson() {
//     return {
//       'num_pp': numPp,
//       'adress_les': adressLes,
//       'num_wydz': numWydz,
//       'sample_int_num': sampleIntNum,
//       'arodes_int_num': arodesIntNum,
//       'list_of_trees': listOfTrees.map((t) => t.toJson()).toList(),
//       'geografic_data': geograficData, // Included in JSON export
//     };
//   }
// }