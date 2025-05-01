// lib/services/data_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class DataService {
  // List of all retail websites
  final List<Map<String, String>> retailSites = [
    {'name': 'Gucci', 'url': 'https://www.gucci.com/tr/en_gb/'},
    {'name': 'Louis Vuitton', 'url': 'https://us.louisvuitton.com/eng-us/homepage'},
    {'name': 'Zara', 'url': 'https://www.zara.com/tr/en/'},
    {'name': 'Stradivarius', 'url': 'https://www.stradivarius.com/tr/en/'},
    {'name': 'Cartier', 'url': 'https://www.cartier.com/en-tr/home'},
    {'name': 'Swarovski', 'url': 'https://www.swarovski.com/en-TR/'},
    {'name': 'Guess', 'url': 'https://www.guess.eu/en-tr/home'},
    {'name': 'Mango', 'url': 'https://shop.mango.com/tr/tr/h/kadin'},
    {'name': 'Bershka', 'url': 'https://www.bershka.com/tr/en/'},
    {'name': 'Massimo Dutti', 'url': 'https://www.massimodutti.com/tr/'},
    {'name': 'Deep Atelier', 'url': 'https://www.deepatelier.co/'},
    {'name': 'Pandora', 'url': 'https://tr.pandora.net/'},
    {'name': 'Miu Miu', 'url': 'https://www.miumiu.com/tr/tr.html'},
    {'name': 'Victoria\'s Secret', 'url': 'https://www.victoriassecret.com.tr/'},
    {'name': 'Nocturne', 'url': 'https://www.nocturne.com.tr/'},
    {'name': 'Beymen', 'url': 'https://www.beymen.com/tr/kadin-10006'},
    {'name': 'Lacoste', 'url': 'https://www.lacoste.com.tr/'},
    {'name': 'Manc', 'url': 'https://tr.mancofficial.com/'},
    {'name': 'Ipekyol', 'url': 'https://www.ipekyol.com.tr/'},
    {'name': 'Sandro', 'url': 'https://www.sandro.com.tr/'},
  ];

  Future<int> getLastSiteIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('lastSiteIndex') ?? 0;
  }

  Future<void> saveLastSiteIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastSiteIndex', index);
  }

  String getUrlForIndex(int index) {
    if (index >= 0 && index < retailSites.length) {
      return retailSites[index]['url'] ?? '';
    }
    return retailSites[0]['url'] ?? '';
  }

  String getNameForIndex(int index) {
    if (index >= 0 && index < retailSites.length) {
      return retailSites[index]['name'] ?? '';
    }
    return retailSites[0]['name'] ?? '';
  }
}