import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/app_icon_service.dart';

enum ThemeModePreference {
  system,
  light,
  dark;

  static ThemeModePreference fromString(String? value) {
    return switch (value) {
      'system' => ThemeModePreference.system,
      'light' => ThemeModePreference.light,
      'dark' => ThemeModePreference.dark,
      _ => ThemeModePreference.dark,
    };
  }

  bool resolveUseDarkMode({required bool platformDarkMode}) {
    return switch (this) {
      ThemeModePreference.system => platformDarkMode,
      ThemeModePreference.light => false,
      ThemeModePreference.dark => true,
    };
  }
}

class DashboardProvider extends ChangeNotifier {
  static const backgroundRotationMinuteOptions = [1, 2, 5, 10, 15];

  static const defaultWidgetOrder = [
    'clock',
    'weather',
    'system',
    'todos',
    'apps',
    'websites',
    'shutdown',
    'restart',
    'sleep',
  ];

  static const Map<String, DashboardWidgetLayout> defaultWidgetLayouts = {
    'clock': DashboardWidgetLayout(x: 0, y: 0, width: 3, height: 2),
    'weather': DashboardWidgetLayout(x: 3, y: 0, width: 3, height: 3),
    'system': DashboardWidgetLayout(x: 6, y: 0, width: 3, height: 3),
    'todos': DashboardWidgetLayout(x: 9, y: 0, width: 3, height: 3),
    'apps': DashboardWidgetLayout(x: 0, y: 3, width: 7, height: 3),
    'websites': DashboardWidgetLayout(x: 0, y: 6, width: 7, height: 2),
    'shutdown': DashboardWidgetLayout(x: 7, y: 3, width: 2, height: 1),
    'restart': DashboardWidgetLayout(x: 9, y: 3, width: 2, height: 1),
    'sleep': DashboardWidgetLayout(x: 11, y: 3, width: 1, height: 1),
  };

  final SharedPreferences _prefs;

  List<AppShortcut> _apps = [];
  List<WebShortcut> _websites = [];
  List<TodoItem> _todos = [];

  List<String> _backgroundImagePaths = [];
  List<String> _validBackgroundImagePaths = [];
  int _currentBackgroundImageIndex = 0;
  int _backgroundRotationMinutes = 2;
  List<int> _backgroundRotationOrder = [];
  final Random _backgroundRotationRandom = Random();
  String _userName = 'Abdo';
  String _accentColor = '#00D4FF';
  bool _showSeconds = true;
  bool _use24Hour = true;
  ThemeModePreference _themeModePreference = ThemeModePreference.dark;
  String _weatherApiKey = '';
  String _weatherCity = '';
  bool _isEditMode = false;
  bool _takeoverMode = false;
  bool _fullscreenEnabled = false;
  bool _borderlessEnabled = false;
  bool _alwaysOnTop = false;
  bool _hideFromTaskbar = false;
  bool _protectWindowControls = false;
  bool _wakeFocusFallback = true;
  int _startupDelaySeconds = 2;
  double _windowOpacity = 1.0;
  double _backgroundDim = 0.7;
  double _blurStrength = 4.0;
  double _glassIntensity = 1.0;
  List<String> _widgetOrder = List.of(defaultWidgetOrder);
  Set<String> _disabledWidgetIds = {};
  Map<String, String> _widgetSizes = {};
  Map<String, DashboardWidgetLayout> _widgetLayouts = Map.of(
    defaultWidgetLayouts,
  );
  bool _weatherMetricUnits = true;
  int _weatherRefreshMinutes = 15;
  bool _lowResourceMode = false;

  DashboardProvider(this._prefs) {
    _loadData();
  }

  // ─── Getters ─────────────────────────────────────────────────────────────
  List<AppShortcut> get apps => _apps;
  List<WebShortcut> get websites => _websites;
  List<TodoItem> get todos => _todos;
  List<String> get backgroundImagePaths =>
      List.unmodifiable(_backgroundImagePaths);
  List<String> get validBackgroundImagePaths =>
      List.unmodifiable(_validBackgroundImagePaths);
  int get backgroundRotationMinutes => _backgroundRotationMinutes;
  String get currentBackgroundImagePath {
    if (_backgroundImagePaths.isEmpty) return '';
    final index = _currentBackgroundImageIndex.clamp(
      0,
      _backgroundImagePaths.length - 1,
    );
    return _backgroundImagePaths[index];
  }

  String get backgroundImagePath => currentBackgroundImagePath;
  String get userName => _userName;
  String get accentColor => _accentColor;
  bool get showSeconds => _showSeconds;
  bool get use24Hour => _use24Hour;
  ThemeModePreference get themeModePreference => _themeModePreference;
  bool get useDarkMode => _themeModePreference == ThemeModePreference.dark;
  String get weatherApiKey => _weatherApiKey;
  String get weatherCity => _weatherCity;
  bool get isEditMode => _isEditMode;
  bool get takeoverMode => _takeoverMode;
  bool get fullscreenEnabled => _fullscreenEnabled;
  bool get borderlessEnabled => _borderlessEnabled;
  bool get alwaysOnTop => _alwaysOnTop;
  bool get hideFromTaskbar => _hideFromTaskbar;
  bool get protectWindowControls => _protectWindowControls;
  bool get wakeFocusFallback => _wakeFocusFallback;
  int get startupDelaySeconds => _startupDelaySeconds;
  double get windowOpacity => _windowOpacity;
  double get backgroundDim => _backgroundDim;
  double get blurStrength => _blurStrength;
  double get glassIntensity => _glassIntensity;
  List<String> get widgetOrder => List.unmodifiable(_widgetOrder);
  bool get weatherMetricUnits => _weatherMetricUnits;
  int get weatherRefreshMinutes => _weatherRefreshMinutes;
  bool get lowResourceMode => _lowResourceMode;

  Color get accentColorValue {
    try {
      return Color(int.parse(_accentColor.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF00D4FF);
    }
  }

  List<TodoItem> get pendingTodos => _todos.where((t) => !t.completed).toList();
  List<TodoItem> get completedTodos =>
      _todos.where((t) => t.completed).toList();
  List<String> get visibleWidgetOrder =>
      _widgetOrder.where(isWidgetEnabled).toList();

  // ─── Load / Save ──────────────────────────────────────────────────────────
  void _loadData() {
    // Load apps
    final appsJson = _prefs.getStringList('apps') ?? [];
    _apps = appsJson.map((s) => AppShortcut.fromJson(jsonDecode(s))).toList();

    // Load websites
    final websitesJson = _prefs.getStringList('websites') ?? [];
    _websites = websitesJson
        .map((s) => WebShortcut.fromJson(jsonDecode(s)))
        .toList();

    // Load todos
    final todosJson = _prefs.getStringList('todos') ?? [];
    _todos = todosJson.map((s) => TodoItem.fromJson(jsonDecode(s))).toList();

    // Load settings
    _backgroundImagePaths = _normalizeBackgroundImagePaths(
      _prefs.getStringList('backgroundImages') ?? [],
    );
    final legacyBackgroundImage = _prefs.getString('backgroundImage') ?? '';
    if (_backgroundImagePaths.isEmpty && legacyBackgroundImage.isNotEmpty) {
      _backgroundImagePaths = [legacyBackgroundImage];
      _prefs.setStringList('backgroundImages', _backgroundImagePaths);
    }
    _refreshValidBackgroundImages();
    _backgroundRotationMinutes = _normalizeBackgroundRotationMinutes(
      _prefs.getInt('backgroundRotationMinutes') ?? 2,
    );
    final savedUserName = _prefs.getString('userName');
    _userName = savedUserName == null || savedUserName == 'User'
        ? 'Abdo'
        : savedUserName;
    _accentColor = _prefs.getString('accentColor') ?? '#00D4FF';
    _showSeconds = _prefs.getBool('showSeconds') ?? true;
    _use24Hour = _prefs.getBool('use24Hour') ?? true;
    _themeModePreference = _loadThemeModePreference();
    _weatherApiKey = _prefs.getString('weatherApiKey') ?? '';
    _weatherCity = _prefs.getString('weatherCity') ?? '';
    _takeoverMode = _prefs.getBool('takeoverMode') ?? false;
    _fullscreenEnabled = _prefs.getBool('fullscreenEnabled') ?? false;
    _borderlessEnabled = _prefs.getBool('borderlessEnabled') ?? false;
    _alwaysOnTop = _prefs.getBool('alwaysOnTop') ?? false;
    _hideFromTaskbar = _prefs.getBool('hideFromTaskbar') ?? false;
    _protectWindowControls = _prefs.getBool('protectWindowControls') ?? false;
    _wakeFocusFallback = _prefs.getBool('wakeFocusFallback') ?? true;
    _startupDelaySeconds = _prefs.getInt('startupDelaySeconds') ?? 2;
    _windowOpacity = _prefs.getDouble('windowOpacity') ?? 1.0;
    _backgroundDim = _prefs.getDouble('backgroundDim') ?? 0.7;
    _blurStrength = _prefs.getDouble('blurStrength') ?? 4.0;
    _glassIntensity = _prefs.getDouble('glassIntensity') ?? 1.0;
    _disabledWidgetIds = (_prefs.getStringList('disabledWidgets') ?? [])
        .toSet();
    _widgetOrder = _normalizeWidgetOrder(
      _prefs.getStringList('widgetOrder') ?? defaultWidgetOrder,
    );
    _widgetSizes = _loadWidgetSizes(_prefs.getStringList('widgetSizes') ?? []);
    _widgetLayouts = _loadWidgetLayouts(
      _prefs.getStringList('widgetLayouts') ?? [],
    );
    _weatherMetricUnits = _prefs.getBool('weatherMetricUnits') ?? true;
    _weatherRefreshMinutes = _prefs.getInt('weatherRefreshMinutes') ?? 15;
    _lowResourceMode = _prefs.getBool('lowResourceMode') ?? false;

    // Add demo data if first launch
    if (_apps.isEmpty) _loadDemoApps();
    if (_websites.isEmpty) _loadDemoWebsites();
    _hydrateMissingAppIcons();

    notifyListeners();
  }

  Future<void> _saveApps() async {
    await _prefs.setStringList(
      'apps',
      _apps.map((a) => jsonEncode(a.toJson())).toList(),
    );
  }

  Future<void> _saveWebsites() async {
    await _prefs.setStringList(
      'websites',
      _websites.map((w) => jsonEncode(w.toJson())).toList(),
    );
  }

  Future<void> _saveTodos() async {
    await _prefs.setStringList(
      'todos',
      _todos.map((t) => jsonEncode(t.toJson())).toList(),
    );
  }

  List<String> _normalizeWidgetOrder(List<String> order) {
    final normalized = <String>[];
    for (final id in order) {
      if (defaultWidgetOrder.contains(id) && !normalized.contains(id)) {
        normalized.add(id);
      }
    }
    for (final id in defaultWidgetOrder) {
      if (!normalized.contains(id)) normalized.add(id);
    }
    return normalized;
  }

  Map<String, String> _loadWidgetSizes(List<String> entries) {
    final sizes = <String, String>{};
    for (final entry in entries) {
      final parts = entry.split(':');
      if (parts.length != 2) continue;
      if (!defaultWidgetOrder.contains(parts[0])) continue;
      if (!['compact', 'normal', 'large'].contains(parts[1])) continue;
      sizes[parts[0]] = parts[1];
    }
    return sizes;
  }

  Map<String, DashboardWidgetLayout> _loadWidgetLayouts(List<String> entries) {
    final layouts = Map<String, DashboardWidgetLayout>.of(defaultWidgetLayouts);
    for (final entry in entries) {
      try {
        final decoded = jsonDecode(entry);
        if (decoded is! Map<String, dynamic>) continue;
        final id = decoded['id'] as String?;
        if (id == null || !defaultWidgetOrder.contains(id)) continue;
        layouts[id] = _sanitizeWidgetLayout(
          DashboardWidgetLayout.fromJson(decoded),
        );
      } catch (_) {
        continue;
      }
    }
    return layouts;
  }

  DashboardWidgetLayout _sanitizeWidgetLayout(DashboardWidgetLayout layout) {
    return DashboardWidgetLayout(
      x: layout.x.clamp(0, 11),
      y: layout.y.clamp(0, 60),
      width: layout.width.clamp(1, 12),
      height: layout.height.clamp(1, 12),
    );
  }

  ThemeModePreference _loadThemeModePreference() {
    final savedPreference = _prefs.getString('themeModePreference');
    if (savedPreference != null) {
      return ThemeModePreference.fromString(savedPreference);
    }
    final legacyDarkMode = _prefs.getBool('useDarkMode') ?? true;
    return legacyDarkMode
        ? ThemeModePreference.dark
        : ThemeModePreference.light;
  }

  Future<void> _saveWidgetSizes() async {
    await _prefs.setStringList(
      'widgetSizes',
      _widgetSizes.entries.map((e) => '${e.key}:${e.value}').toList(),
    );
  }

  Future<void> _saveWidgetLayouts() async {
    await _prefs.setStringList(
      'widgetLayouts',
      _widgetLayouts.entries
          .map(
            (entry) => jsonEncode({'id': entry.key, ...entry.value.toJson()}),
          )
          .toList(),
    );
  }

  List<String> _normalizeBackgroundImagePaths(List<String> paths) {
    final normalized = <String>[];
    for (final path in paths) {
      final trimmed = path.trim();
      if (trimmed.isEmpty || normalized.contains(trimmed)) continue;
      normalized.add(trimmed);
    }
    return normalized;
  }

  int _normalizeBackgroundRotationMinutes(int value) {
    if (backgroundRotationMinuteOptions.contains(value)) return value;
    return 2;
  }

  Future<void> _saveBackgroundImages() async {
    await _prefs.setStringList('backgroundImages', _backgroundImagePaths);
  }

  void _refreshValidBackgroundImages({bool Function(String path)? fileExists}) {
    final exists = fileExists ?? (path) => File(path).existsSync();
    _validBackgroundImagePaths = _backgroundImagePaths
        .where((path) => exists(path))
        .toList();
  }

  void _resetBackgroundRotationOrder() {
    _backgroundRotationOrder = List.generate(
      _backgroundImagePaths.length,
      (index) => index,
    )..shuffle(_backgroundRotationRandom);
    _backgroundRotationOrder.remove(_currentBackgroundImageIndex);
  }

  // ─── Demo Data ────────────────────────────────────────────────────────────
  void _loadDemoApps() {
    _apps = [
      AppShortcut(
        id: '1',
        name: 'Chrome',
        executablePath:
            r'C:\Program Files\Google\Chrome\Application\chrome.exe',
        color: '#4285F4',
      ),
      AppShortcut(
        id: '2',
        name: 'VS Code',
        executablePath:
            r'C:\Users\%USERNAME%\AppData\Local\Programs\Microsoft VS Code\Code.exe',
        color: '#007ACC',
      ),
      AppShortcut(
        id: '3',
        name: 'Spotify',
        executablePath:
            r'C:\Users\%USERNAME%\AppData\Roaming\Spotify\Spotify.exe',
        color: '#1DB954',
      ),
      AppShortcut(
        id: '4',
        name: 'Discord',
        executablePath: r'C:\Users\%USERNAME%\AppData\Local\Discord\Update.exe',
        color: '#5865F2',
      ),
    ];
    _saveApps();
  }

  void _loadDemoWebsites() {
    _websites = [
      WebShortcut(
        id: '1',
        name: 'YouTube',
        url: 'https://youtube.com',
        color: '#FF0000',
      ),
      WebShortcut(
        id: '2',
        name: 'GitHub',
        url: 'https://github.com',
        color: '#6E40C9',
      ),
      WebShortcut(
        id: '3',
        name: 'Gmail',
        url: 'https://mail.google.com',
        color: '#EA4335',
      ),
      WebShortcut(
        id: '4',
        name: 'Reddit',
        url: 'https://reddit.com',
        color: '#FF4500',
      ),
    ];
    _saveWebsites();
  }

  Future<void> _hydrateMissingAppIcons() async {
    var changed = false;
    for (final app in _apps) {
      if (app.iconPath.isNotEmpty && File(app.iconPath).existsSync()) {
        continue;
      }
      final iconPath = await extractWindowsAppIcon(
        executablePath: app.executablePath,
        appId: app.id,
      );
      if (iconPath.isEmpty) continue;
      app.iconPath = iconPath;
      changed = true;
    }

    if (!changed) return;
    await _saveApps();
    notifyListeners();
  }

  // ─── Edit Mode ────────────────────────────────────────────────────────────
  void toggleEditMode() {
    _isEditMode = !_isEditMode;
    notifyListeners();
  }

  // ─── App Management ───────────────────────────────────────────────────────
  void addApp(AppShortcut app) {
    _apps.add(app);
    _saveApps();
    notifyListeners();
  }

  void updateApp(AppShortcut app) {
    final idx = _apps.indexWhere((a) => a.id == app.id);
    if (idx != -1) {
      _apps[idx] = app;
      _saveApps();
      notifyListeners();
    }
  }

  void removeApp(String id) {
    _apps.removeWhere((a) => a.id == id);
    _saveApps();
    notifyListeners();
  }

  void reorderApps(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final item = _apps.removeAt(oldIndex);
    _apps.insert(newIndex, item);
    _saveApps();
    notifyListeners();
  }

  // ─── Website Management ───────────────────────────────────────────────────
  void addWebsite(WebShortcut site) {
    _websites.add(site);
    _saveWebsites();
    notifyListeners();
  }

  void updateWebsite(WebShortcut site) {
    final idx = _websites.indexWhere((w) => w.id == site.id);
    if (idx != -1) {
      _websites[idx] = site;
      _saveWebsites();
      notifyListeners();
    }
  }

  void removeWebsite(String id) {
    _websites.removeWhere((w) => w.id == id);
    _saveWebsites();
    notifyListeners();
  }

  void reorderWebsites(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _websites.length) return;
    if (newIndex < 0 || newIndex > _websites.length) return;
    if (newIndex > oldIndex) newIndex--;
    final item = _websites.removeAt(oldIndex);
    _websites.insert(newIndex, item);
    _saveWebsites();
    notifyListeners();
  }

  // ─── Todo Management ──────────────────────────────────────────────────────
  void addTodo(String text) {
    if (text.trim().isEmpty) return;
    _todos.insert(
      0,
      TodoItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text.trim(),
      ),
    );
    _saveTodos();
    notifyListeners();
  }

  void toggleTodo(String id) {
    final index = _todos.indexWhere((t) => t.id == id);
    if (index == -1) return;
    final todo = _todos[index];
    todo.completed = !todo.completed;
    _saveTodos();
    notifyListeners();
  }

  void deleteTodo(String id) {
    _todos.removeWhere((t) => t.id == id);
    _saveTodos();
    notifyListeners();
  }

  void clearCompletedTodos() {
    _todos.removeWhere((t) => t.completed);
    _saveTodos();
    notifyListeners();
  }

  // ─── Settings ─────────────────────────────────────────────────────────────
  Future<void> setBackgroundImage(String path) async {
    _backgroundImagePaths = _normalizeBackgroundImagePaths(
      path.isEmpty ? [] : [path],
    );
    _refreshValidBackgroundImages();
    _currentBackgroundImageIndex = 0;
    _resetBackgroundRotationOrder();
    await _saveBackgroundImages();
    await _prefs.setString('backgroundImage', path);
    notifyListeners();
  }

  Future<void> addBackgroundImages(List<String> paths) async {
    final merged = _normalizeBackgroundImagePaths([
      ..._backgroundImagePaths,
      ...paths,
    ]);
    if (merged.length == _backgroundImagePaths.length) return;
    final hadNoImages = _backgroundImagePaths.isEmpty;
    _backgroundImagePaths = merged;
    _refreshValidBackgroundImages();
    if (hadNoImages) _currentBackgroundImageIndex = 0;
    _resetBackgroundRotationOrder();
    await _saveBackgroundImages();
    await _prefs.setString('backgroundImage', currentBackgroundImagePath);
    notifyListeners();
  }

  Future<void> clearBackgroundImages() async {
    _backgroundImagePaths = [];
    _validBackgroundImagePaths = [];
    _currentBackgroundImageIndex = 0;
    _backgroundRotationOrder = [];
    await _saveBackgroundImages();
    await _prefs.setString('backgroundImage', '');
    notifyListeners();
  }

  Future<void> setBackgroundRotationMinutes(int value) async {
    if (!backgroundRotationMinuteOptions.contains(value)) return;
    _backgroundRotationMinutes = value;
    await _prefs.setInt(
      'backgroundRotationMinutes',
      _backgroundRotationMinutes,
    );
    notifyListeners();
  }

  void advanceBackgroundImage() {
    if (_backgroundImagePaths.length < 2) return;
    if (_currentBackgroundImageIndex >= _backgroundImagePaths.length) {
      _currentBackgroundImageIndex = 0;
    }
    if (_backgroundRotationOrder.isEmpty) {
      _resetBackgroundRotationOrder();
    }
    if (_backgroundRotationOrder.isEmpty) return;
    _currentBackgroundImageIndex = _backgroundRotationOrder.removeAt(0);
    notifyListeners();
  }

  Future<void> setUserName(String name) async {
    _userName = name;
    await _prefs.setString('userName', name);
    notifyListeners();
  }

  Future<void> setAccentColor(String hex) async {
    _accentColor = hex;
    await _prefs.setString('accentColor', hex);
    notifyListeners();
  }

  Future<void> setShowSeconds(bool value) async {
    _showSeconds = value;
    await _prefs.setBool('showSeconds', value);
    notifyListeners();
  }

  Future<void> setUse24Hour(bool value) async {
    _use24Hour = value;
    await _prefs.setBool('use24Hour', value);
    notifyListeners();
  }

  Future<void> setUseDarkMode(bool value) async {
    _themeModePreference = value
        ? ThemeModePreference.dark
        : ThemeModePreference.light;
    await _prefs.setBool('useDarkMode', value);
    await _prefs.setString('themeModePreference', _themeModePreference.name);
    notifyListeners();
  }

  Future<void> setThemeModePreference(ThemeModePreference value) async {
    _themeModePreference = value;
    await _prefs.setString('themeModePreference', value.name);
    await _prefs.setBool('useDarkMode', value == ThemeModePreference.dark);
    notifyListeners();
  }

  bool resolveUseDarkMode({required bool platformDarkMode}) {
    return _themeModePreference.resolveUseDarkMode(
      platformDarkMode: platformDarkMode,
    );
  }

  Future<void> setTakeoverMode(bool value) async {
    _takeoverMode = value;
    await _prefs.setBool('takeoverMode', value);
    notifyListeners();
  }

  Future<void> setFullscreenEnabled(bool value) async {
    _fullscreenEnabled = value;
    await _prefs.setBool('fullscreenEnabled', value);
    notifyListeners();
  }

  Future<void> setBorderlessEnabled(bool value) async {
    _borderlessEnabled = value;
    await _prefs.setBool('borderlessEnabled', value);
    notifyListeners();
  }

  Future<void> setAlwaysOnTop(bool value) async {
    _alwaysOnTop = value;
    await _prefs.setBool('alwaysOnTop', value);
    notifyListeners();
  }

  Future<void> setHideFromTaskbar(bool value) async {
    _hideFromTaskbar = value;
    await _prefs.setBool('hideFromTaskbar', value);
    notifyListeners();
  }

  Future<void> setProtectWindowControls(bool value) async {
    _protectWindowControls = value;
    await _prefs.setBool('protectWindowControls', value);
    notifyListeners();
  }

  Future<void> setWakeFocusFallback(bool value) async {
    _wakeFocusFallback = value;
    await _prefs.setBool('wakeFocusFallback', value);
    notifyListeners();
  }

  Future<void> setStartupDelaySeconds(int value) async {
    _startupDelaySeconds = value.clamp(0, 30);
    await _prefs.setInt('startupDelaySeconds', _startupDelaySeconds);
    notifyListeners();
  }

  Future<void> setWindowOpacity(double value) async {
    _windowOpacity = value.clamp(0.25, 1.0);
    await _prefs.setDouble('windowOpacity', _windowOpacity);
    notifyListeners();
  }

  Future<void> setBackgroundDim(double value) async {
    _backgroundDim = value.clamp(0.0, 0.95);
    await _prefs.setDouble('backgroundDim', _backgroundDim);
    notifyListeners();
  }

  Future<void> setBlurStrength(double value) async {
    _blurStrength = value.clamp(0.0, 30.0);
    await _prefs.setDouble('blurStrength', _blurStrength);
    notifyListeners();
  }

  Future<void> setGlassIntensity(double value) async {
    _glassIntensity = value.clamp(0.2, 1.4);
    await _prefs.setDouble('glassIntensity', _glassIntensity);
    notifyListeners();
  }

  bool isWidgetEnabled(String id) => !_disabledWidgetIds.contains(id);

  Future<void> setWidgetEnabled(String id, bool value) async {
    if (!defaultWidgetOrder.contains(id)) return;
    if (value) {
      _disabledWidgetIds.remove(id);
    } else {
      _disabledWidgetIds.add(id);
    }
    await _prefs.setStringList('disabledWidgets', _disabledWidgetIds.toList());
    notifyListeners();
  }

  void reorderDashboardWidget(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _widgetOrder.length) return;
    if (newIndex < 0 || newIndex > _widgetOrder.length) return;
    if (newIndex > oldIndex) newIndex--;
    final item = _widgetOrder.removeAt(oldIndex);
    _widgetOrder.insert(newIndex, item);
    _prefs.setStringList('widgetOrder', _widgetOrder);
    notifyListeners();
  }

  String widgetSize(String id) => _widgetSizes[id] ?? 'normal';

  DashboardWidgetLayout widgetLayout(String id) {
    return _widgetLayouts[id] ?? defaultWidgetLayouts[id]!;
  }

  Future<void> setWidgetLayout(String id, DashboardWidgetLayout layout) async {
    if (!defaultWidgetOrder.contains(id)) return;
    _widgetLayouts[id] = _sanitizeWidgetLayout(layout);
    await _saveWidgetLayouts();
    notifyListeners();
  }

  Future<void> setWidgetSize(String id, String size) async {
    if (!defaultWidgetOrder.contains(id)) return;
    if (!['compact', 'normal', 'large'].contains(size)) return;
    _widgetSizes[id] = size;
    await _saveWidgetSizes();
    notifyListeners();
  }

  Future<void> setWeatherMetricUnits(bool value) async {
    _weatherMetricUnits = value;
    await _prefs.setBool('weatherMetricUnits', value);
    notifyListeners();
  }

  Future<void> setWeatherRefreshMinutes(int value) async {
    _weatherRefreshMinutes = value.clamp(1, 120);
    await _prefs.setInt('weatherRefreshMinutes', _weatherRefreshMinutes);
    notifyListeners();
  }

  Future<void> setLowResourceMode(bool value) async {
    _lowResourceMode = value;
    await _prefs.setBool('lowResourceMode', value);
    notifyListeners();
  }

  Future<void> setWeatherApiKey(String key) async {
    _weatherApiKey = key;
    await _prefs.setString('weatherApiKey', key);
    notifyListeners();
  }

  Future<void> setWeatherCity(String city) async {
    _weatherCity = city;
    await _prefs.setString('weatherCity', city);
    notifyListeners();
  }

  // Generate unique ID
  String generateId() => DateTime.now().millisecondsSinceEpoch.toString();
}
