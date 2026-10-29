/// Mises en forme propres aux écrans vidéo (dates en français, durées, temps
/// du lecteur, recherche insensible aux accents).
library;

const _months = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

/// Date locale avec l'année : « 12 juin 2026 », « 1er mars 2026 ». Le serveur
/// renvoie des dates UTC : on les convertit dans le fuseau de l'appareil.
String formatVideoDate(DateTime date) {
  final local = date.toLocal();
  final day = local.day == 1 ? '1er' : '${local.day}';
  return '$day ${_months[local.month - 1]} ${local.year}';
}

/// Durée lisible : « 24 min 08 s », « 1 h 02 min », « 45 s ». `null` quand la
/// durée est inconnue (0 tant que le traitement n'est pas terminé), pour ne
/// jamais afficher « 0 min ».
String? formatVideoDuration(int seconds) {
  if (seconds <= 0) return null;
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final rest = seconds % 60;
  if (hours > 0) {
    return '$hours h ${minutes.toString().padLeft(2, '0')} min';
  }
  if (minutes > 0) {
    return '$minutes min ${rest.toString().padLeft(2, '0')} s';
  }
  return '$rest s';
}

/// Temps de lecture : « 3:07 » ou « 1:02:03 ».
String formatPlayerTime(Duration duration) {
  final total = duration.isNegative ? 0 : duration.inSeconds;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = (total % 60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$seconds';
  }
  return '$minutes:$seconds';
}

const _accents = {
  'à': 'a',
  'â': 'a',
  'ä': 'a',
  'ç': 'c',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'î': 'i',
  'ï': 'i',
  'ô': 'o',
  'ö': 'o',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'œ': 'oe',
};

/// Minuscules sans accents, pour comparer une recherche à un titre.
String foldForSearch(String text) {
  final lower = text.toLowerCase().trim();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_accents[char] ?? char);
  }
  return buffer.toString();
}
