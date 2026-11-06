final _values = <String, String>{};

String? readView(String key) => _values[key];

void writeView(String key, String value) => _values[key] = value;
