import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_theme/system_theme.dart';

import '../models/models.dart';
import '../services/app_icon_service.dart';
import '../services/dashboard_grid_service.dart';
import '../services/notification_service.dart';

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
  static const layoutSchemaVersion = 3;

  static const defaultWidgetOrder = [
    'clock',
    'weather',
    'agenda',
    'apps',
    'todos',
    'prayerTimes',
    'system',
    'power',
    'websites',
  ];

  static const defaultDesktopWidgetEnabled = {'clock', 'weather', 'prayerTimes'};

  final SharedPreferences _prefs;

  List<AppShortcut> _apps = [];
  List<WebShortcut> _websites = [];
  List<TodoItem> _todos = [];

  List<String> _backgroundImagePaths = const [];
  List<String> _validBackgroundImagePaths = const [];
  int _currentBackgroundImageIndex = 0;
  int _backgroundRotationMinutes = 2;
  List<int> _backgroundRotationOrder = [];
  final Random _backgroundRotationRandom = Random();
  String _userName = 'Abdo';
  String _accentColor = '#00D4FF';
  bool _followSystemAccent = true;
  String _backdropEffect = 'mica';
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
  Map<LayoutBreakpoint, List<DashboardWidgetPlacement>> _placements = const {};
  int _layoutRevision = 0;
  bool _weatherMetricUnits = true;
  int _weatherRefreshMinutes = 15;
  bool _lowResourceMode = false;
  bool _desktopWidgetMode = false;
  List<String> _desktopWidgetOrder = List.of(defaultWidgetOrder);
  Set<String> _desktopWidgetEnabledIds = Set.of(defaultDesktopWidgetEnabled);
  bool _desktopWidgetAlwaysOnTop = false;
  bool _desktopWidgetHideFromTaskbar = true;
  bool _desktopWidgetLockPosition = false;
  double _desktopWidgetOpacity = 0.94;
  Rect? _dashboardWindowBounds;
  Rect? _desktopWidgetWindowBounds;

  DashboardProvider(this._prefs) {
    _loadData();
  }

  // ─── Getters ─────────────────────────────────────────────────────────────
  List<AppShortcut> get apps => _apps;
  List<WebShortcut> get websites => _websites;
  List<TodoItem> get todos => _todos;
  List<String> get backgroundImagePaths => _backgroundImagePaths;
  List<String> get validBackgroundImagePaths => _validBackgroundImagePaths;
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
  List<DashboardWidgetPlacement> placementsFor(LayoutBreakpoint breakpoint) =>
      _placements[breakpoint] ?? DashboardGridService.defaults(breakpoint);
  int get layoutRevision => _layoutRevision;
  void _bumpLayoutRevision() => _layoutRevision++;
  bool get weatherMetricUnits => _weatherMetricUnits;
  int get weatherRefreshMinutes => _weatherRefreshMinutes;
  bool get lowResourceMode => _lowResourceMode;
  bool get desktopWidgetMode => _desktopWidgetMode;
  List<String> get desktopWidgetOrder => List.unmodifiable(_desktopWidgetOrder);
  bool isDesktopWidgetEnabled(String id) =>
      _desktopWidgetEnabledIds.contains(id);
  List<String> get visibleDesktopWidgetOrder =>
      _desktopWidgetOrder.where(isDesktopWidgetEnabled).toList();
  bool get desktopWidgetAlwaysOnTop => _desktopWidgetAlwaysOnTop;
  bool get desktopWidgetHideFromTaskbar => _desktopWidgetHideFromTaskbar;
  bool get desktopWidgetLockPosition => _desktopWidgetLockPosition;
  double get desktopWidgetOpacity => _desktopWidgetOpacity;
  Rect? get dashboardWindowBounds => _dashboardWindowBounds;
  Rect? get desktopWidgetWindowBounds => _desktopWidgetWindowBounds;

  bool get followSystemAccent => _followSystemAccent;
  String get backdropEffect => _backdropEffect;

  Color get accentColorValue {
    if (_followSystemAccent && Platform.isWindows) {
      try {
        return SystemTheme.accentColor.accent;
      } catch (_) {}
    }
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
    _apps = List.unmodifiable(
      appsJson.map((s) => AppShortcut.fromJson(jsonDecode(s))),
    );

    // Load websites
    final websitesJson = _prefs.getStringList('websites') ?? [];
    _websites = List.unmodifiable(
      websitesJson.map((s) => WebShortcut.fromJson(jsonDecode(s))),
    );

    // Load todos
    final todosJson = _prefs.getStringList('todos') ?? [];
    _todos = List.unmodifiable(
      todosJson.map((s) => TodoItem.fromJson(jsonDecode(s))),
    );
    for (final todo in _todos) {
      if (todo.remind && todo.dueAt != null && !todo.completed) {
        NotificationService.instance.scheduleTodoReminder(
          todoId: todo.id,
          title: todo.text,
          dueAt: todo.dueAt!,
        );
      }
    }

    // Load settings
    _backgroundImagePaths = _normalizeBackgroundImagePaths(
      _prefs.getStringList('backgroundImages') ?? [],
    );
    final legacyBackgroundImage = _prefs.getString('backgroundImage') ?? '';
    if (_backgroundImagePaths.isEmpty && legacyBackgroundImage.isNotEmpty) {
      _backgroundImagePaths = List.unmodifiable([legacyBackgroundImage]);
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
    _followSystemAccent = _prefs.getBool('followSystemAccent') ?? true;
    _backdropEffect = _prefs.getString('backdropEffect') ?? 'mica';
    _applyBackdropEffect();
    if (Platform.isWindows) {
      SystemTheme.onChange.listen((_) {
        if (_followSystemAccent) {
          notifyListeners();
        }
      });
    }
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
    _loadLayoutPreferences();
    _weatherMetricUnits = _prefs.getBool('weatherMetricUnits') ?? true;
    _weatherRefreshMinutes = _prefs.getInt('weatherRefreshMinutes') ?? 15;
    _lowResourceMode = _prefs.getBool('lowResourceMode') ?? false;
    _loadDesktopWidgetPreferences();

    // Add demo data if first launch
    if (_apps.isEmpty) _loadDemoApps();
    if (_websites.isEmpty) _loadDemoWebsites();
    _hydrateMissingAppIcons();

    notifyListeners();
  }

  void _loadLayoutPreferences() {
    final savedDisabled = (_prefs.getStringList('disabledWidgets') ?? [])
        .toSet();
    final savedVersion = _prefs.getInt('layoutSchemaVersion') ?? 1;
    if (savedVersion < 2) {
      _widgetOrder = List.of(defaultWidgetOrder);
      _disabledWidgetIds = savedDisabled
          .where(defaultWidgetOrder.contains)
          .toSet();
      final allLegacyPowerActionsDisabled = const {
        'shutdown',
        'restart',
        'sleep',
      }.every(savedDisabled.contains);
      if (allLegacyPowerActionsDisabled) _disabledWidgetIds.add('power');
      _prefs
        ..setStringList('widgetOrder', _widgetOrder)
        ..setStringList('disabledWidgets', _disabledWidgetIds.toList())
        ..remove('widgetSizes')
        ..remove('widgetLayouts');
    } else {
      _disabledWidgetIds = savedDisabled
          .where(defaultWidgetOrder.contains)
          .toSet();
      _widgetOrder = _normalizeWidgetOrder(
        _prefs.getStringList('widgetOrder') ?? defaultWidgetOrder,
      );
    }

    _placements = Map.unmodifiable({
      for (final breakpoint in LayoutBreakpoint.values)
        breakpoint: savedVersion < 3
            ? DashboardGridService.defaults(breakpoint)
            : _loadPlacements(breakpoint),
    });
    if (savedVersion < layoutSchemaVersion) {
      for (final breakpoint in LayoutBreakpoint.values) {
        _savePlacements(breakpoint);
      }
      _prefs.setInt('layoutSchemaVersion', layoutSchemaVersion);
    }
  }

  List<DashboardWidgetPlacement> _loadPlacements(LayoutBreakpoint breakpoint) {
    final loaded = <DashboardWidgetPlacement>[];
    for (final encoded in _prefs.getStringList(breakpoint.storageKey) ?? []) {
      try {
        final json = jsonDecode(encoded);
        if (json is Map<String, dynamic>) {
          final placement = DashboardWidgetPlacement.fromJson(json);
          if (defaultWidgetOrder.contains(placement.id) &&
              !loaded.any((item) => item.id == placement.id)) {
            loaded.add(placement);
          }
        }
      } catch (_) {
        // Skip malformed placement records without blocking startup.
      }
    }
    final defaults = DashboardGridService.defaults(breakpoint);
    for (final placement in defaults) {
      if (!loaded.any((item) => item.id == placement.id)) {
        loaded.add(placement);
      }
    }
    return DashboardGridService.normalize(loaded, breakpoint);
  }

  Future<void> _savePlacements(LayoutBreakpoint breakpoint) async {
    await _prefs.setStringList(
      breakpoint.storageKey,
      placementsFor(
        breakpoint,
      ).map((item) => jsonEncode(item.toJson())).toList(),
    );
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
    return List.unmodifiable(normalized);
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
    _validBackgroundImagePaths = List.unmodifiable(
      _backgroundImagePaths.where((path) => exists(path)),
    );
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
    _apps = List.unmodifiable([
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
    ]);
    _saveApps();
  }

  void _loadDemoWebsites() {
    _websites = List.unmodifiable([
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
    ]);
    _saveWebsites();
  }

  Future<void> _hydrateMissingAppIcons() async {
    var changed = false;
    final hydrated = await Future.wait(
      _apps.map((app) async {
        if (app.iconPath.isNotEmpty && File(app.iconPath).existsSync()) {
          return app;
        }
        final iconPath = await extractWindowsAppIcon(
          executablePath: app.executablePath,
          appId: app.id,
        );
        if (iconPath.isNotEmpty && iconPath != app.iconPath) {
          changed = true;
          return app.copyWith(iconPath: iconPath);
        }
        return app;
      }),
    );

    if (!changed) return;
    _apps = List.unmodifiable(hydrated);
    await _saveApps();
    notifyListeners();
  }

  // ─── Edit Mode ────────────────────────────────────────────────────────────
  void toggleEditMode() {
    _isEditMode = !_isEditMode;
    _bumpLayoutRevision();
    notifyListeners();
  }

  // ─── App Management ───────────────────────────────────────────────────────
  void addApp(AppShortcut app) {
    _apps = List.unmodifiable([..._apps, app]);
    _saveApps();
    notifyListeners();
  }

  void updateApp(AppShortcut app) {
    final idx = _apps.indexWhere((a) => a.id == app.id);
    if (idx != -1) {
      final updated = [..._apps]..[idx] = app;
      _apps = List.unmodifiable(updated);
      _saveApps();
      notifyListeners();
    }
  }

  void removeApp(String id) {
    _apps = List.unmodifiable(_apps.where((a) => a.id != id));
    _saveApps();
    notifyListeners();
  }

  void reorderApps(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final updated = [..._apps];
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    _apps = List.unmodifiable(updated);
    _saveApps();
    notifyListeners();
  }

  // ─── Website Management ───────────────────────────────────────────────────
  void addWebsite(WebShortcut site) {
    _websites = List.unmodifiable([..._websites, site]);
    _saveWebsites();
    notifyListeners();
  }

  void updateWebsite(WebShortcut site) {
    final idx = _websites.indexWhere((w) => w.id == site.id);
    if (idx != -1) {
      final updated = [..._websites]..[idx] = site;
      _websites = List.unmodifiable(updated);
      _saveWebsites();
      notifyListeners();
    }
  }

  void removeWebsite(String id) {
    _websites = List.unmodifiable(_websites.where((w) => w.id != id));
    _saveWebsites();
    notifyListeners();
  }

  void reorderWebsites(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _websites.length) return;
    if (newIndex < 0 || newIndex > _websites.length) return;
    if (newIndex > oldIndex) newIndex--;
    final updated = [..._websites];
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    _websites = List.unmodifiable(updated);
    _saveWebsites();
    notifyListeners();
  }

  // ─── Todo Management ──────────────────────────────────────────────────────
  void addTodoItem(TodoItem item) {
    if (item.text.trim().isEmpty) return;
    _todos = List.unmodifiable([item, ..._todos]);
    _saveTodos();
    if (item.remind && item.dueAt != null && !item.completed) {
      NotificationService.instance.scheduleTodoReminder(
        todoId: item.id,
        title: item.text,
        dueAt: item.dueAt!,
      );
    }
    notifyListeners();
  }

  void addTodo(
    String text, {
    DateTime? dueAt,
    TodoPriority priority = TodoPriority.none,
    bool remind = false,
  }) {
    if (text.trim().isEmpty) return;
    final item = TodoItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text.trim(),
      dueAt: dueAt,
      priority: priority,
      remind: remind,
    );
    addTodoItem(item);
  }

  void toggleTodo(String id) {
    final index = _todos.indexWhere((t) => t.id == id);
    if (index == -1) return;
    final updated = [..._todos];
    final nextState = !updated[index].completed;
    updated[index] = updated[index].copyWith(completed: nextState);
    if (nextState) {
      NotificationService.instance.cancelReminder(id);
    } else if (updated[index].remind && updated[index].dueAt != null) {
      NotificationService.instance.scheduleTodoReminder(
        todoId: id,
        title: updated[index].text,
        dueAt: updated[index].dueAt!,
      );
    }
    _todos = List.unmodifiable(updated);
    _saveTodos();
    notifyListeners();
  }

  void deleteTodo(String id) {
    NotificationService.instance.cancelReminder(id);
    _todos = List.unmodifiable(_todos.where((t) => t.id != id));
    _saveTodos();
    notifyListeners();
  }

  void clearCompletedTodos() {
    for (final todo in _todos.where((t) => t.completed)) {
      NotificationService.instance.cancelReminder(todo.id);
    }
    _todos = List.unmodifiable(_todos.where((t) => !t.completed));
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
    _backgroundImagePaths = const [];
    _validBackgroundImagePaths = const [];
    _currentBackgroundImageIndex = 0;
    _backgroundRotationOrder = [];
    await _saveBackgroundImages();
    await _prefs.setString('backgroundImage', '');
    notifyListeners();
  }

  Future<void> removeBackgroundImage(String path) async {
    final removedIndex = _backgroundImagePaths.indexOf(path);
    if (removedIndex < 0) return;
    final wasCurrent = removedIndex == _currentBackgroundImageIndex;
    _backgroundImagePaths = List.unmodifiable(
      _backgroundImagePaths.where((item) => item != path),
    );
    _refreshValidBackgroundImages();
    if (_backgroundImagePaths.isEmpty) {
      _currentBackgroundImageIndex = 0;
      _backgroundRotationOrder = [];
    } else {
      if (removedIndex < _currentBackgroundImageIndex) {
        _currentBackgroundImageIndex--;
      }
      _currentBackgroundImageIndex = _currentBackgroundImageIndex.clamp(
        0,
        _backgroundImagePaths.length - 1,
      );
      _resetBackgroundRotationOrder();
      if (wasCurrent && _backgroundRotationOrder.isNotEmpty) {
        _currentBackgroundImageIndex = _backgroundRotationOrder.removeAt(0);
      }
    }
    await _saveBackgroundImages();
    await _prefs.setString('backgroundImage', currentBackgroundImagePath);
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
    _prefs.setString('backgroundImage', currentBackgroundImagePath);
    notifyListeners();
  }

  Future<void> setUserName(String name) async {
    _userName = name;
    await _prefs.setString('userName', name);
    notifyListeners();
  }

  Future<void> setAccentColor(String hex) async {
    _accentColor = hex;
    _followSystemAccent = false;
    await _prefs.setBool('followSystemAccent', false);
    await _prefs.setString('accentColor', hex);
    notifyListeners();
  }

  Future<void> setFollowSystemAccent(bool value) async {
    _followSystemAccent = value;
    await _prefs.setBool('followSystemAccent', value);
    notifyListeners();
  }

  Future<void> setBackdropEffect(String effect) async {
    _backdropEffect = effect;
    await _prefs.setString('backdropEffect', effect);
    _applyBackdropEffect();
    notifyListeners();
  }

  void _applyBackdropEffect() {
    if (!Platform.isWindows) return;
    try {
      final effect = switch (_backdropEffect) {
        'acrylic' => WindowEffect.acrylic,
        'solid' => WindowEffect.solid,
        'tabbed' => WindowEffect.tabbed,
        _ => WindowEffect.mica,
      };
      Window.setEffect(
        effect: effect,
        dark: _themeModePreference == ThemeModePreference.dark ||
            (_themeModePreference == ThemeModePreference.system &&
                (PlatformDispatcher.instance.platformBrightness ==
                    Brightness.dark)),
      );
    } catch (e) {
      debugPrint('Failed to apply backdrop effect: $e');
    }
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
    _applyBackdropEffect();
    notifyListeners();
  }

  Future<void> setThemeModePreference(ThemeModePreference value) async {
    _themeModePreference = value;
    await _prefs.setString('themeModePreference', value.name);
    await _prefs.setBool('useDarkMode', value == ThemeModePreference.dark);
    _applyBackdropEffect();
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
    final updated = [..._widgetOrder];
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    _widgetOrder = List.unmodifiable(updated);
    _prefs.setStringList('widgetOrder', _widgetOrder);
    notifyListeners();
  }

  Future<void> updateWidgetPlacement(
    LayoutBreakpoint breakpoint,
    DashboardWidgetPlacement placement,
  ) async {
    if (!defaultWidgetOrder.contains(placement.id)) return;
    final updated = DashboardGridService.reflow(
      placements: placementsFor(breakpoint),
      edited: placement,
      breakpoint: breakpoint,
    );
    _placements = Map.unmodifiable({..._placements, breakpoint: updated});
    _widgetOrder = List.unmodifiable(updated.map((item) => item.id));
    _bumpLayoutRevision();
    await _savePlacements(breakpoint);
    await _prefs.setStringList('widgetOrder', _widgetOrder);
    notifyListeners();
  }

  Future<void> resetWidgetPlacements(LayoutBreakpoint breakpoint) async {
    final defaults = DashboardGridService.defaults(breakpoint);
    _placements = Map.unmodifiable({..._placements, breakpoint: defaults});
    _widgetOrder = List.unmodifiable(defaults.map((item) => item.id));
    _bumpLayoutRevision();
    await _savePlacements(breakpoint);
    await _prefs.setStringList('widgetOrder', _widgetOrder);
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

  // ─── Desktop Widget Mode ──────────────────────────────────────────────────
  void _loadDesktopWidgetPreferences() {
    _desktopWidgetMode = _prefs.getBool('desktopWidgetMode') ?? false;
    _desktopWidgetOrder = _normalizeWidgetOrder(
      _prefs.getStringList('desktopWidgetOrder') ?? defaultWidgetOrder,
    );
    final savedEnabled = _prefs.getStringList('desktopWidgetEnabledIds');
    _desktopWidgetEnabledIds = savedEnabled == null
        ? Set.of(defaultDesktopWidgetEnabled)
        : savedEnabled.where(defaultWidgetOrder.contains).toSet();
    _desktopWidgetAlwaysOnTop =
        _prefs.getBool('desktopWidgetAlwaysOnTop') ?? false;
    _desktopWidgetHideFromTaskbar =
        _prefs.getBool('desktopWidgetHideFromTaskbar') ?? true;
    _desktopWidgetLockPosition =
        _prefs.getBool('desktopWidgetLockPosition') ?? false;
    _desktopWidgetOpacity = (_prefs.getDouble('desktopWidgetOpacity') ?? 0.94)
        .clamp(0.25, 1.0);
    _dashboardWindowBounds = _readWindowBounds('dashboardWin');
    _desktopWidgetWindowBounds = _readWindowBounds('widgetWin');
  }

  Rect? _readWindowBounds(String prefix) {
    final x = _prefs.getDouble('${prefix}X');
    final y = _prefs.getDouble('${prefix}Y');
    final w = _prefs.getDouble('${prefix}W');
    final h = _prefs.getDouble('${prefix}H');
    if (x == null || y == null || w == null || h == null) return null;
    if (w <= 0 || h <= 0) return null;
    return Rect.fromLTWH(x, y, w, h);
  }

  Future<void> _writeWindowBounds(String prefix, Rect bounds) async {
    await _prefs.setDouble('${prefix}X', bounds.left);
    await _prefs.setDouble('${prefix}Y', bounds.top);
    await _prefs.setDouble('${prefix}W', bounds.width);
    await _prefs.setDouble('${prefix}H', bounds.height);
  }

  Future<void> setDesktopWidgetMode(bool value) async {
    if (_desktopWidgetMode == value) return;
    _desktopWidgetMode = value;
    _isEditMode = false;
    _bumpLayoutRevision();
    await _prefs.setBool('desktopWidgetMode', value);
    notifyListeners();
  }

  Future<void> toggleDesktopWidgetMode() =>
      setDesktopWidgetMode(!_desktopWidgetMode);

  Future<void> setDesktopWidgetEnabled(String id, bool value) async {
    if (!defaultWidgetOrder.contains(id)) return;
    if (value) {
      _desktopWidgetEnabledIds.add(id);
    } else {
      _desktopWidgetEnabledIds.remove(id);
    }
    _bumpLayoutRevision();
    await _prefs.setStringList(
      'desktopWidgetEnabledIds',
      _desktopWidgetEnabledIds.toList(),
    );
    notifyListeners();
  }

  void reorderDesktopWidget(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _desktopWidgetOrder.length) return;
    if (newIndex < 0 || newIndex > _desktopWidgetOrder.length) return;
    if (newIndex > oldIndex) newIndex--;
    final updated = [..._desktopWidgetOrder];
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    _desktopWidgetOrder = List.unmodifiable(updated);
    _bumpLayoutRevision();
    _prefs.setStringList('desktopWidgetOrder', _desktopWidgetOrder);
    notifyListeners();
  }

  Future<void> setDesktopWidgetAlwaysOnTop(bool value) async {
    _desktopWidgetAlwaysOnTop = value;
    await _prefs.setBool('desktopWidgetAlwaysOnTop', value);
    notifyListeners();
  }

  Future<void> setDesktopWidgetHideFromTaskbar(bool value) async {
    _desktopWidgetHideFromTaskbar = value;
    await _prefs.setBool('desktopWidgetHideFromTaskbar', value);
    notifyListeners();
  }

  Future<void> setDesktopWidgetLockPosition(bool value) async {
    _desktopWidgetLockPosition = value;
    await _prefs.setBool('desktopWidgetLockPosition', value);
    notifyListeners();
  }

  Future<void> setDesktopWidgetOpacity(double value) async {
    _desktopWidgetOpacity = value.clamp(0.25, 1.0);
    await _prefs.setDouble('desktopWidgetOpacity', _desktopWidgetOpacity);
    notifyListeners();
  }

  Future<void> saveDashboardWindowBounds(Rect bounds) async {
    if (bounds.width <= 0 || bounds.height <= 0) return;
    _dashboardWindowBounds = bounds;
    await _writeWindowBounds('dashboardWin', bounds);
  }

  Future<void> saveDesktopWidgetWindowBounds(Rect bounds) async {
    if (bounds.width <= 0 || bounds.height <= 0) return;
    _desktopWidgetWindowBounds = bounds;
    await _writeWindowBounds('widgetWin', bounds);
  }

  // Generate unique ID
  String generateId() => DateTime.now().millisecondsSinceEpoch.toString();
}
