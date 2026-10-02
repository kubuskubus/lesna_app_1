

class PowierzchniaModel {
  String numer;
  String adres;
  String warstwa; // Added variable (stored as a string representation of an integer)
  List<DrzewoModel> drzewa;
  List<Gatunek> gatunki;

  PowierzchniaModel({
    required this.numer,
    required this.adres,
    required this.warstwa, // Added to constructor
    List<DrzewoModel>? drzewa,
    List<Gatunek>? gatunki,
  })  : drzewa = drzewa ?? [],
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

    return PowierzchniaModel(
      numer: json['numer'] ?? '',
      adres: json['adres'] ?? '',
      warstwa: json['warstwa']?.toString() ?? '', // Safely handles both String and int from JSON
      drzewa: parsedDrzewa,
      gatunki: parsedGatunki,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'numer': numer,
      'adres': adres,
      'warstwa': warstwa, // Added to JSON export
      'drzewa': drzewa.map((d) => d.toJson()).toList(),
      'gatunki': gatunki.map((g) => g.toJson()).toList(),
    };
  }
}


class DrzewoModel {
  final int numer; // Changed from 'number' to 'numer'
  String powierzchniaNumer;
  String gatunek;
  String typ;
  double srednica;
  double wysokosc;
  double azymut;
  double odl;
  int wiek;
  int klasaRozkladu;

  DrzewoModel({
    required this.numer, // Changed from 'number' to 'numer'
    required this.powierzchniaNumer,
    required this.gatunek,
    required this.typ,
    this.srednica = 0.0,
    this.wysokosc = 0.0,
    this.azymut = 0.0,
    this.odl = 0.0,
    this.wiek = 0,
    this.klasaRozkladu = 0,
  });

  factory DrzewoModel.fromJson(Map<String, dynamic> json) {
    return DrzewoModel(
      numer: json['numer'] ?? 0,
      powierzchniaNumer: json['powierzchnia_numer'] ?? '',
      gatunek: json['gatunek'] ?? '',
      typ: json['typ'] ?? 'zywe',
      srednica: (json['srednica'] ?? 0.0).toDouble(),
      wysokosc: (json['wysokosc'] ?? 0.0).toDouble(),
      azymut: (json['azymut'] ?? 0.0).toDouble(),
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
      'srednica': srednica,
      'wysokosc': wysokosc,
      'azymut': azymut,
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
      // Checking multiple keys just in case it's parsed directly from your raw JSON
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
    // Parse the nested 'list_of_trees' directly into Gatunek objects
    var treesFromJson = json['list_of_trees'] as List?;
    List<Gatunek> parsedTrees = treesFromJson != null
        ? treesFromJson.map((i) => Gatunek.fromJson(Map<String, dynamic>.from(i))).toList()
        : [];

    return WydzielenieModel(
      // Safely parse everything to String to handle both int and String JSON formats
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

