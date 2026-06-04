// ─── App Shortcut Model ──────────────────────────────────────────────────────
class AppShortcut {
  final String id;
  String name;
  String executablePath;
  String iconPath; // can be empty, will use default
  String color; // hex string e.g. "#00D4FF"

  AppShortcut({
    required this.id,
    required this.name,
    required this.executablePath,
    this.iconPath = '',
    this.color = '#00D4FF',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'executablePath': executablePath,
    'iconPath': iconPath,
    'color': color,
  };

  factory AppShortcut.fromJson(Map<String, dynamic> json) => AppShortcut(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    executablePath: json['executablePath'] ?? '',
    iconPath: json['iconPath'] ?? '',
    color: json['color'] ?? '#00D4FF',
  );
}

// ─── Website Shortcut Model ──────────────────────────────────────────────────
class WebShortcut {
  final String id;
  String name;
  String url;
  String favicon; // URL or empty
  String color;

  WebShortcut({
    required this.id,
    required this.name,
    required this.url,
    this.favicon = '',
    this.color = '#7B2FFF',
  });

  String get domain {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }

  String get faviconUrl {
    if (favicon.isNotEmpty) return favicon;
    return 'https://www.google.com/s2/favicons?sz=64&domain=$domain';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'favicon': favicon,
    'color': color,
  };

  factory WebShortcut.fromJson(Map<String, dynamic> json) => WebShortcut(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    url: json['url'] ?? '',
    favicon: json['favicon'] ?? '',
    color: json['color'] ?? '#7B2FFF',
  );
}

// ─── Todo Model ───────────────────────────────────────────────────────────────
class TodoItem {
  final String id;
  String text;
  bool completed;
  DateTime createdAt;

  TodoItem({
    required this.id,
    required this.text,
    this.completed = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'completed': completed,
    'createdAt': createdAt.toIso8601String(),
  };

  factory TodoItem.fromJson(Map<String, dynamic> json) => TodoItem(
    id: json['id'] ?? '',
    text: json['text'] ?? '',
    completed: json['completed'] ?? false,
    createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
  );
}

// ─── Dashboard Widget Layout Model ───────────────────────────────────────────
class DashboardWidgetLayout {
  final int x;
  final int y;
  final int width;
  final int height;

  const DashboardWidgetLayout({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  DashboardWidgetLayout copyWith({int? x, int? y, int? width, int? height}) {
    return DashboardWidgetLayout(
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };

  factory DashboardWidgetLayout.fromJson(Map<String, dynamic> json) {
    return DashboardWidgetLayout(
      x: (json['x'] as num?)?.toInt() ?? 0,
      y: (json['y'] as num?)?.toInt() ?? 0,
      width: (json['width'] as num?)?.toInt() ?? 2,
      height: (json['height'] as num?)?.toInt() ?? 2,
    );
  }
}

// ─── Weather Model ───────────────────────────────────────────────────────────
class ForecastDay {
  final DateTime date;
  final double tempMax;
  final double tempMin;
  final String icon;
  final String condition;

  const ForecastDay({
    required this.date,
    required this.tempMax,
    required this.tempMin,
    required this.icon,
    required this.condition,
  });
}

class WeatherData {
  final String city;
  final double temperature;
  final String condition;
  final String icon;
  final int humidity;
  final double windSpeed;
  final double feelsLike;
  final List<ForecastDay> forecast;

  const WeatherData({
    required this.city,
    required this.temperature,
    required this.condition,
    required this.icon,
    required this.humidity,
    required this.windSpeed,
    required this.feelsLike,
    this.forecast = const [],
  });

  factory WeatherData.fromOpenWeather(
    Map<String, dynamic> json, {
    required bool useMetricUnits,
    List<ForecastDay> forecast = const [],
  }) {
    return WeatherData(
      city: json['name'] ?? 'Unknown',
      temperature: (json['main']['temp'] as num).toDouble(),
      condition: json['weather'][0]['description'] ?? '',
      icon: json['weather'][0]['icon'] ?? '01d',
      humidity: json['main']['humidity'] ?? 0,
      windSpeed: (json['wind']['speed'] as num).toDouble(),
      feelsLike: (json['main']['feels_like'] as num).toDouble(),
      forecast: forecast,
    );
  }

  factory WeatherData.fromOpenMeteo({
    required Map<String, dynamic> json,
    required String city,
  }) {
    final current = json['current'] as Map<String, dynamic>;
    final code = current['weather_code'] as int? ?? -1;
    final forecast = _parseOpenMeteoForecast(json);
    return WeatherData(
      city: city,
      temperature: (current['temperature_2m'] as num).toDouble(),
      condition: openMeteoCondition(code),
      icon: openMeteoIcon(code),
      humidity: current['relative_humidity_2m'] as int? ?? 0,
      windSpeed: (current['wind_speed_10m'] as num?)?.toDouble() ?? 0,
      feelsLike: (current['apparent_temperature'] as num).toDouble(),
      forecast: forecast,
    );
  }

  static List<ForecastDay> _parseOpenMeteoForecast(Map<String, dynamic> json) {
    final daily = json['daily'] as Map<String, dynamic>?;
    if (daily == null) return [];

    final dates = daily['time'] as List<dynamic>? ?? [];
    final maxTemps = daily['temperature_2m_max'] as List<dynamic>? ?? [];
    final minTemps = daily['temperature_2m_min'] as List<dynamic>? ?? [];
    final codes = daily['weather_code'] as List<dynamic>? ?? [];
    final count = [
      dates.length,
      maxTemps.length,
      minTemps.length,
      codes.length,
      8,
    ].reduce((a, b) => a < b ? a : b);

    final forecast = <ForecastDay>[];
    for (var i = 0; i < count; i++) {
      final date = DateTime.tryParse(dates[i].toString());
      if (date == null) continue;
      final code = (codes[i] as num?)?.toInt() ?? -1;
      forecast.add(
        ForecastDay(
          date: DateTime(date.year, date.month, date.day),
          tempMax: (maxTemps[i] as num?)?.toDouble() ?? 0,
          tempMin: (minTemps[i] as num?)?.toDouble() ?? 0,
          icon: openMeteoIcon(code),
          condition: openMeteoCondition(code),
        ),
      );
    }
    return forecast;
  }

  static String openMeteoCondition(int code) {
    if (code == 0) return 'Clear sky';
    if ([1, 2, 3].contains(code)) return 'Partly cloudy';
    if ([45, 48].contains(code)) return 'Fog';
    if ([51, 53, 55, 56, 57].contains(code)) return 'Drizzle';
    if ([61, 63, 65, 66, 67, 80, 81, 82].contains(code)) return 'Rain';
    if ([71, 73, 75, 77, 85, 86].contains(code)) return 'Snow';
    if ([95, 96, 99].contains(code)) return 'Thunderstorm';
    return 'Weather';
  }

  static String openMeteoIcon(int code) {
    if (code == 0) return '01d';
    if ([1, 2, 3].contains(code)) return '02d';
    if ([45, 48].contains(code)) return '50d';
    if ([51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82].contains(code)) {
      return '10d';
    }
    if ([71, 73, 75, 77, 85, 86].contains(code)) return '13d';
    if ([95, 96, 99].contains(code)) return '11d';
    return '01d';
  }

  // Mock data for demo / when no API key
  factory WeatherData.mock() => const WeatherData(
    city: 'Cairo',
    temperature: 28,
    condition: 'Clear Sky',
    icon: '01d',
    humidity: 35,
    windSpeed: 4.2,
    feelsLike: 30,
  );
}

// ─── System Stats Model ──────────────────────────────────────────────────────
class DiskActivity {
  final String label;
  final double readBytesPerSecond;
  final double writeBytesPerSecond;

  const DiskActivity({
    required this.label,
    required this.readBytesPerSecond,
    required this.writeBytesPerSecond,
  });

  double get readMegabytesPerSecond => readBytesPerSecond / (1024 * 1024);
  double get writeMegabytesPerSecond => writeBytesPerSecond / (1024 * 1024);
}

class GpuActivity {
  final String name;
  final double usagePercent;
  final double? temperatureC;

  const GpuActivity({
    required this.name,
    required this.usagePercent,
    this.temperatureC,
  });
}

class SystemStats {
  final double cpuUsage;
  final double? cpuTemperatureC;
  final List<GpuActivity> gpus;
  final double ramUsage;
  final double ramTotal;
  final List<DiskActivity> disks;
  final String osName;
  final String hostname;

  const SystemStats({
    required this.cpuUsage,
    this.cpuTemperatureC,
    required this.gpus,
    required this.ramUsage,
    required this.ramTotal,
    required this.disks,
    required this.osName,
    required this.hostname,
  });

  double get ramPercent => ramTotal > 0 ? (ramUsage / ramTotal) : 0;

  factory SystemStats.empty() => const SystemStats(
    cpuUsage: 0,
    cpuTemperatureC: null,
    gpus: [],
    ramUsage: 0,
    ramTotal: 16,
    disks: [],
    osName: 'Windows 11',
    hostname: 'DESKTOP',
  );
}
