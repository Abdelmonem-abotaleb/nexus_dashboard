// ─── App Shortcut Model ──────────────────────────────────────────────────────
class AppShortcut {
  final String id;
  final String name;
  final String executablePath;
  final String iconPath; // can be empty, will use default
  final String color;

  AppShortcut({
    required this.id,
    required this.name,
    required this.executablePath,
    this.iconPath = '',
    this.color = '#00D4FF',
  });

  AppShortcut copyWith({
    String? name,
    String? executablePath,
    String? iconPath,
    String? color,
  }) => AppShortcut(
    id: id,
    name: name ?? this.name,
    executablePath: executablePath ?? this.executablePath,
    iconPath: iconPath ?? this.iconPath,
    color: color ?? this.color,
  );

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
  final String name;
  final String url;
  final String favicon; // URL or empty
  final String color;

  WebShortcut({
    required this.id,
    required this.name,
    required this.url,
    this.favicon = '',
    this.color = '#7B2FFF',
  });

  WebShortcut copyWith({
    String? name,
    String? url,
    String? favicon,
    String? color,
  }) => WebShortcut(
    id: id,
    name: name ?? this.name,
    url: url ?? this.url,
    favicon: favicon ?? this.favicon,
    color: color ?? this.color,
  );

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

enum TodoPriority { none, low, medium, high }

// ─── Todo Model ───────────────────────────────────────────────────────────────
class TodoItem {
  final String id;
  final String text;
  final bool completed;
  final DateTime createdAt;
  final DateTime? dueAt;
  final TodoPriority priority;
  final bool remind;

  TodoItem({
    required this.id,
    required this.text,
    this.completed = false,
    DateTime? createdAt,
    this.dueAt,
    this.priority = TodoPriority.none,
    this.remind = false,
  }) : createdAt = createdAt ?? DateTime.now();

  TodoItem copyWith({
    String? text,
    bool? completed,
    DateTime? createdAt,
    DateTime? dueAt,
    TodoPriority? priority,
    bool? remind,
  }) =>
      TodoItem(
        id: id,
        text: text ?? this.text,
        completed: completed ?? this.completed,
        createdAt: createdAt ?? this.createdAt,
        dueAt: dueAt ?? this.dueAt,
        priority: priority ?? this.priority,
        remind: remind ?? this.remind,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'completed': completed,
    'createdAt': createdAt.toIso8601String(),
    'dueAt': dueAt?.toIso8601String(),
    'priority': priority.name,
    'remind': remind,
  };

  factory TodoItem.fromJson(Map<String, dynamic> json) => TodoItem(
    id: json['id'] ?? '',
    text: json['text'] ?? '',
    completed: json['completed'] ?? false,
    createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    dueAt: json['dueAt'] != null ? DateTime.tryParse(json['dueAt'] ?? '') : null,
    priority: TodoPriority.values.firstWhere(
      (p) => p.name == json['priority'],
      orElse: () => TodoPriority.none,
    ),
    remind: json['remind'] ?? false,
  );
}

class AgendaEvent {
  final String id;
  final String title;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String notes;
  final bool isAllDay;

  const AgendaEvent({
    required this.id,
    required this.title,
    required this.startsAt,
    this.endsAt,
    this.notes = '',
    this.isAllDay = false,
  });

  AgendaEvent copyWith({
    String? title,
    DateTime? startsAt,
    DateTime? endsAt,
    bool clearEndsAt = false,
    String? notes,
    bool? isAllDay,
  }) {
    return AgendaEvent(
      id: id,
      title: title ?? this.title,
      startsAt: startsAt ?? this.startsAt,
      endsAt: clearEndsAt ? null : endsAt ?? this.endsAt,
      notes: notes ?? this.notes,
      isAllDay: isAllDay ?? this.isAllDay,
    );
  }

  String? validate() {
    if (title.trim().isEmpty) return 'Title is required.';
    if (endsAt != null && endsAt!.isBefore(startsAt)) {
      return 'End time must be after the start time.';
    }
    if (isAllDay &&
        (startsAt.hour != 0 || startsAt.minute != 0 || endsAt != null)) {
      return 'All-day events must use a date without times.';
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'startsAt': startsAt.toIso8601String(),
    'endsAt': endsAt?.toIso8601String(),
    'notes': notes,
    'isAllDay': isAllDay,
  };

  factory AgendaEvent.fromJson(Map<String, dynamic> json) {
    final startsAt = DateTime.tryParse(json['startsAt'] as String? ?? '');
    if (startsAt == null) throw const FormatException('Invalid event date');
    final event = AgendaEvent(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      startsAt: startsAt,
      endsAt: DateTime.tryParse(json['endsAt'] as String? ?? ''),
      notes: json['notes'] as String? ?? '',
      isAllDay: json['isAllDay'] as bool? ?? false,
    );
    final error = event.validate();
    if (event.id.isEmpty || error != null) {
      throw FormatException(error ?? 'Event id is required.');
    }
    return event;
  }
}

// ─── Dashboard Widget Layout Model ───────────────────────────────────────────
// ─── Weather Model ───────────────────────────────────────────────────────────
enum LayoutBreakpoint {
  medium(6, 'widgetPlacementsMedium'),
  wide(12, 'widgetPlacementsWide');

  final int columns;
  final String storageKey;
  const LayoutBreakpoint(this.columns, this.storageKey);
}

class DashboardWidgetPlacement {
  final String id;
  final int x;
  final int y;
  final int width;
  final int height;

  const DashboardWidgetPlacement({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  int get right => x + width;
  int get bottom => y + height;

  DashboardWidgetPlacement copyWith({
    int? x,
    int? y,
    int? width,
    int? height,
  }) => DashboardWidgetPlacement(
    id: id,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    height: height ?? this.height,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };

  factory DashboardWidgetPlacement.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    if (id.isEmpty) throw const FormatException('Widget id is required');
    return DashboardWidgetPlacement(
      id: id,
      x: (json['x'] as num?)?.toInt() ?? 0,
      y: (json['y'] as num?)?.toInt() ?? 0,
      width: (json['width'] as num?)?.toInt() ?? 1,
      height: (json['height'] as num?)?.toInt() ?? 1,
    );
  }
}

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

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'tempMax': tempMax,
    'tempMin': tempMin,
    'icon': icon,
    'condition': condition,
  };

  factory ForecastDay.fromJson(Map<String, dynamic> json) => ForecastDay(
    date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
    tempMax: (json['tempMax'] as num?)?.toDouble() ?? 0.0,
    tempMin: (json['tempMin'] as num?)?.toDouble() ?? 0.0,
    icon: json['icon'] ?? '01d',
    condition: json['condition'] ?? 'Clear',
  );
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

  Map<String, dynamic> toJson() => {
    'city': city,
    'temperature': temperature,
    'condition': condition,
    'icon': icon,
    'humidity': humidity,
    'windSpeed': windSpeed,
    'feelsLike': feelsLike,
    'forecast': forecast.map((f) => f.toJson()).toList(),
  };

  factory WeatherData.fromJson(Map<String, dynamic> json) => WeatherData(
    city: json['city'] ?? '',
    temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
    condition: json['condition'] ?? '',
    icon: json['icon'] ?? '01d',
    humidity: (json['humidity'] as num?)?.toInt() ?? 0,
    windSpeed: (json['windSpeed'] as num?)?.toDouble() ?? 0.0,
    feelsLike: (json['feelsLike'] as num?)?.toDouble() ?? 0.0,
    forecast: (json['forecast'] as List<dynamic>?)
            ?.map((f) => ForecastDay.fromJson(f as Map<String, dynamic>))
            .toList() ??
        const [],
  );

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
    osName: 'Windows',
    hostname: 'DESKTOP',
  );
}
