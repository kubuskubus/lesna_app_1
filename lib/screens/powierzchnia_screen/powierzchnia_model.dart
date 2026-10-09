class PowierzchniaModel {
  String numer;
  List<String> adres;
  List<String> warstwa;
  int nachylenie; // Default value set to 100
  List<DrzewoModel> drzewa;
  List<Gatunek> gatunki;

  PowierzchniaModel({
    required this.numer,
    List<String>? adres,
    List<String>? warstwa,
    int? nachylenie,
    List<DrzewoModel>? drzewa,
    List<Gatunek>? gatunki,
  })  : adres = adres ?? [],
        warstwa = warstwa ?? [],
        nachylenie = nachylenie ?? 100, // Defaults to 100 if not provided
        drzewa = drzewa ?? [],
        gatunki = gatunki ?? [];

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

    return PowierzchniaModel(
      numer: json['numer'] ?? '',
      adres: parsedAdres,
      warstwa: parsedWarstwa,
      nachylenie: parsedNachylenie,
      drzewa: parsedDrzewa,
      gatunki: parsedGatunki,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'numer': numer,
      'adres': adres,
      'warstwa': warstwa,
      'nachylenie': nachylenie,
      'drzewa': drzewa.map((d) => d.toJson()).toList(),
      'gatunki': gatunki.map((g) => g.toJson()).toList(),
    };
  }
}


class DrzewoModel {
  final int numer;
  String powierzchniaNumer;
  String gatunek;
  String typ;
  String warstwa;
  double srednica;
  double wysokosc;
  double? azymut; // <-- Make it nullable (double?)
  double odl;
  int wiek;
  int klasaRozkladu;
  bool wysRequired;

  DrzewoModel({
    required this.numer,
    required this.powierzchniaNumer,
    required this.gatunek,
    required this.typ,
    this.warstwa = '',
    this.srednica = 0.0,
    this.wysokosc = 0.0,
    this.azymut, // <-- Optional, defaults to null if not provided
    this.odl = 0.0,
    this.wiek = 0,
    this.klasaRozkladu = 0,
    this.wysRequired = false,
  });

  factory DrzewoModel.fromJson(Map<String, dynamic> json) {
    return DrzewoModel(
      numer: json['numer'] ?? 0,
      powierzchniaNumer: json['powierzchnia_numer']?.toString() ?? '',
      gatunek: json['gatunek']?.toString() ?? '',
      typ: json['typ']?.toString() ?? 'zywe',
      warstwa: json['warstwa']?.toString() ?? '',
      srednica: (json['srednica'] ?? 0.0).toDouble(),
      wysokosc: (json['wysokosc'] ?? 0.0).toDouble(),
      // Read as nullable double from JSON
      azymut: json['azymut'] != null ? (json['azymut']).toDouble() : null,
      odl: (json['odl'] ?? 0.0).toDouble(),
      wiek: json['wiek'] ?? 0,
      klasaRozkladu: json['klasa_rozkladu'] ?? 0,
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
      'azymut': azymut, // Can save as null to the database/json
      'odl': odl,
      'wiek': wiek,
      'klasa_rozkladu': klasaRozkladu,
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
  final String adressLes;
  final String numWydz;
  final List<Gatunek> listOfTrees;

  // Fields are marked as final because this model is strictly read-only
  WydzielenieModel({
    required this.numPp,
    required this.adressLes,
    required this.numWydz,
    required this.listOfTrees,
  });

  factory WydzielenieModel.fromJson(Map<String, dynamic> json) {
    var treesFromJson = json['list_of_trees'] as List?;
    List<Gatunek> parsedTrees = treesFromJson != null
        ? treesFromJson.map((i) => Gatunek.fromJson(Map<String, dynamic>.from(i))).toList()
        : [];

    return WydzielenieModel(
      numPp: json['num_pp']?.toString() ?? '',
      adressLes: json['adress_les']?.toString() ?? '',
      numWydz: json['num_wydz']?.toString() ?? '',
      listOfTrees: parsedTrees,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'num_pp': numPp,
      'adress_les': adressLes,
      'num_wydz': numWydz,
      'list_of_trees': listOfTrees.map((t) => t.toJson()).toList(),
    };
  }
}