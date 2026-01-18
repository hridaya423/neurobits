class TextUtils {
  static final Set<String> _acronyms = {
    'ai',
    'ml',
    'api',
    'sql',
    'css',
    'html',
    'js',
    'ui',
    'ux',
    'ios',
    'sdk',
    'json',
    'xml',
    'http',
    'https',
    'rest',
    'crud',
    'mvc',
    'mvvm',
    'oop',
    'dsa',
    'ci',
    'cd',
    'aws',
    'gcp',
    'php',
    'asp',
    'dom',
    'cli',
    'gui',
    'ram',
    'cpu',
    'gpu',
    'ssd',
    'hdd',
    'lan',
    'wan',
    'vpn',
    'dns',
    'ftp',
    'ssh',
    'ssl',
    'tls',
    'tcp',
    'udp',
    'ip',
    'nat',
    'dhcp',
    'sat',
    'sats',
    'gcse',
    'ib',
    'ap',
    'sat'
  };
  static String capitalizeTitle(String text) {
    if (text.isEmpty) return text;

    final words = text.split(' ');
    return words.map((word) {
      if (word.isEmpty) return word;

      final lowerWord = word.toLowerCase();
      if (_acronyms.contains(lowerWord)) {
        return word.toUpperCase();
      }

      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  static String capitalizeSentence(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  static String toTitleCase(String text) {
    return capitalizeTitle(text);
  }
}
