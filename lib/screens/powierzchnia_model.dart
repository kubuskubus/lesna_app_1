

class PowierzchniaModel {
  String numer;
  String adres;
  Map<String, dynamic> wydz_data;
  List<DrzewoModel> drzewa;

  PowierzchniaModel({
    required this.numer,
    required this.adres,
    required this.wydz_data,
    List<DrzewoModel>? drzewa,
  }) : drzewa = drzewa ?? []; // Ensures the list is always growable

  factory PowierzchniaModel.fromJson(Map<String, dynamic> json) {
    // Parse the single list of trees
    var drzewaFromJson = json['drzewa'] as List?;
    List<DrzewoModel> parsedDrzewa = drzewaFromJson != null
        ? drzewaFromJson.map((i) => DrzewoModel.fromJson(Map<String, dynamic>.from(i))).toList()
        : [];

    return PowierzchniaModel(
      numer: json['numer'] ?? '',
      adres: json['adres'] ?? '',
      wydz_data: json['wydz_data'] != null
          ? Map<String, dynamic>.from(json['wydz_data'])
          : <String, dynamic>{},
      drzewa: parsedDrzewa,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'numer': numer,
      'adres': adres,
      'wydz_data': wydz_data,
      // Convert the unified list back to JSON
      'drzewa': drzewa.map((d) => d.toJson()).toList(),
    };
  }
}


class DrzewoModel {
  String powierzchniaNumer;
  String gatunek;
  String typ;
  double srednica;
  double wysokosc;
  double azymut;
  double odl;
  int wiek;          // Added age field
  int klasaRozkladu;

  DrzewoModel({
    required this.powierzchniaNumer,
    required this.gatunek,
    required this.typ,
    this.srednica = 0.0,
    this.wysokosc = 0.0,
    this.azymut = 0.0,
    this.odl = 0.0,
    this.wiek = 0,   // Default value
    this.klasaRozkladu = 0,
  });

  factory DrzewoModel.fromJson(Map<String, dynamic> json) {
    return DrzewoModel(
      powierzchniaNumer: json['powierzchnia_numer'] ?? '',
      gatunek: json['gatunek'] ?? '',
      typ: json['typ'] ?? 'zywe',
      srednica: (json['srednica'] ?? 0.0).toDouble(),
      wysokosc: (json['wysokosc'] ?? 0.0).toDouble(),
      azymut: (json['azymut'] ?? 0.0).toDouble(),
      odl: (json['odl'] ?? 0.0).toDouble(),
      wiek: json['wiek'] ?? 0, // Parsed from JSON
      klasaRozkladu: json['klasa_rozkladu'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'powierzchnia_numer': powierzchniaNumer,
      'gatunek': gatunek,
      'typ': typ,
      'srednica': srednica,
      'wysokosc': wysokosc,
      'azymut': azymut,
      'odl': odl,
      'wiek': wiek, // Serialized to JSON
      'klasa_rozkladu': klasaRozkladu,
    };
  }
}

