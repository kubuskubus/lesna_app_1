class PowierzchniaModel {
  String numer;
  String adres;
  List<Map<String, dynamic>> grupy;
  List<Map<String, dynamic>> drzewa; // <--- Nowa właściwość na drzewa

  PowierzchniaModel({
    required this.numer,
    required this.adres,
    List<Map<String, dynamic>>? grupy,
    List<Map<String, dynamic>>? drzewa,
  })  : grupy = grupy ?? [],
        drzewa = drzewa ?? [];

  // Konwersja z JSON (odczyt z pliku)
  factory PowierzchniaModel.fromJson(Map<String, dynamic> json) {
    return PowierzchniaModel(
      numer: json['numer'] ?? '',
      adres: json['adres'] ?? '',
      grupy: json['grupy'] != null
          ? List<Map<String, dynamic>>.from(json['grupy'])
          : [],
      drzewa: json['drzewa'] != null
          ? List<Map<String, dynamic>>.from(json['drzewa'])
          : [],
    );
  }

  // Konwersja do JSON (zapis do pliku)
  Map<String, dynamic> toJson() {
    return {
      'numer': numer,
      'adres': adres,
      'grupy': grupy,
      'drzewa': drzewa, // <--- Zapis listy drzew
    };
  }
}