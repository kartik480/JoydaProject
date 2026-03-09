// One-time script: run with `dart run tool/download_fonts.dart` to download font files into fonts/.
import 'dart:io';

import 'package:http/http.dart' as http;

void main() async {
  final scriptDir = File(Platform.script.toFilePath()).parent;
  final projectRoot = scriptDir.parent;
  final fontsDir = Directory('${projectRoot.path}/fonts');
  if (!await fontsDir.exists()) await fontsDir.create(recursive: true);
  final fonts = [
    ('https://fonts.gstatic.com/s/a/fea39bbc0034c9d19bbe216022ff35f730f708d2f6c8b2460160b6e92a4a3e0e.ttf', 'Baloo2-Regular.ttf'),
    ('https://fonts.gstatic.com/s/a/6e183273b09ace60f0265257f3a2f015fc46d5226fd729b724ce17648ff1010a.ttf', 'Baloo2-SemiBold.ttf'),
    ('https://fonts.gstatic.com/s/a/291dcfb1305552ec2a8b0bcff09b55a2fcd6d554b7c6f04cb06c733e1ba86780.ttf', 'Baloo2-Bold.ttf'),
    ('https://fonts.gstatic.com/s/a/6f96017e762896b4cf3c2db345d41d7a72a3720a95698c3cd47020bf433db435.ttf', 'Nunito-Regular.ttf'),
  ];
  for (final entry in fonts) {
    final url = entry.$1;
    final name = entry.$2;
    final file = File('${fontsDir.path}/$name');
    if (await file.exists() && await file.length() > 1000) {
      print('OK (cached): $name');
      continue;
    }
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        print('OK: $name (${response.bodyBytes.length} bytes) -> ${file.path}');
      } else {
        print('FAIL: $name status ${response.statusCode}');
      }
    } catch (e) {
      print('FAIL: $name $e');
    }
  }
}
