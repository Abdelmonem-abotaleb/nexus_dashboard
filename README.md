# 🌌 NEXUS DASHBOARD
### Sleek Windows Desktop Dashboard with Dark Glass/Neon Aesthetic

---

## ✨ Features

| Widget | Description |
|--------|-------------|
| 🕐 **Clock & Date** | Live clock with 12/24hr format, greeting by time of day |
| 🌤️ **Weather** | Real-time weather via OpenWeatherMap API |
| 🚀 **App Launcher** | Launch your favourite Windows apps with one click |
| 🌐 **Website Shortcuts** | Open your favourite websites in the browser |
| ✅ **To-Do / Notes** | Persistent task list with completion tracking |
| 💻 **System Stats** | Live CPU, RAM, and Disk usage with neon bars |
| 🖥️ **Takeover Mode** | Fullscreen, always-on-top, taskbar hiding, protected controls |
| 🧩 **Widget Controls** | Enable/disable and reorder dashboard widgets |
| 🪟 **Transparency** | Window opacity, glass intensity, blur, and background dim controls |

---

## 🛠️ Setup Instructions

### Step 1: Install Flutter for Windows

1. Download Flutter SDK: https://docs.flutter.dev/get-started/install/windows
2. Extract to `C:\src\flutter`
3. Add `C:\src\flutter\bin` to your PATH environment variable
4. Run `flutter doctor` and fix any issues shown

### Step 2: Enable Windows Desktop Support

```powershell
flutter config --enable-windows-desktop
```

### Step 3: Install Dependencies

Open a terminal in the `nexus_dashboard` folder and run:

```powershell
flutter pub get
```

### Step 4: Run the App

```powershell
flutter run -d windows
```

### Step 5: Build a Release EXE

```powershell
flutter build windows --release
```

Your `.exe` will be at:
```
build\windows\x64\runner\Release\nexus_dashboard.exe
```

---

## ⚙️ Configuration

### Adding Apps
1. Click **EDIT** in the top bar
2. Click **+ ADD APP** in the App Launcher section
3. Browse to your `.exe` file or paste the path
4. Choose a name and color
5. Click **ADD APP**

### Adding Websites
1. Click **EDIT** in the top bar
2. Click **+ ADD SITE** in the Websites section
3. Enter the site name and URL
4. Choose a color

### Weather Setup (Optional)
1. Get a free API key at https://openweathermap.org/api
2. Open **Settings** (top right)
3. Paste your API key and enter your city name
4. Click **REFRESH WEATHER**

### Setting as Startup App
1. Build the release `.exe`
2. Run the release app
3. Open **Settings → System**
4. Turn on **Start on Login**

The startup entry points to the executable you are currently running. For daily use, enable it from the release app, not from a debug build.

### Packaging a Release

```powershell
.\scripts\package_release.ps1
```

The script builds the Windows release and creates a portable zip under `dist\`.
If Inno Setup is installed and `ISCC.exe` is on your `PATH`, it also creates
`dist\nexus_dashboard_setup.exe`. The installer includes optional desktop
shortcut and startup-on-login tasks.

---

## 🎨 Customization

In **Settings** you can:
- Set your **display name** (shows in greeting)
- Set a custom **background image**
- Choose an **accent color** from presets
- Switch **dark/light mode**
- Tune **window opacity**, **background dim**, **blur**, and **glass intensity**
- Enable **Takeover Mode**, **fullscreen**, **always on top**, **hide from taskbar**, and protected window controls
- Enable/disable and reorder dashboard widgets
- Toggle **24-hour clock** and **show seconds**
- Configure **weather** city and API key
- Toggle metric weather units and set the weather refresh interval

### Emergency Exit

When Takeover Mode is active, press:

```text
Ctrl + Alt + N
```

This disables takeover/fullscreen/always-on-top/taskbar hiding and brings the app back to a normal window.

---

## 📦 Dependencies

| Package | Purpose |
|---------|---------|
| `provider` | State management |
| `shared_preferences` | Persistent storage |
| `http` | Weather API calls |
| `url_launcher` | Open websites |
| `file_picker` | Browse for exe/image files |
| `window_manager` | Custom window chrome |
| `intl` | Date/time formatting |

---

## 🗂️ Project Structure

```
lib/
├── main.dart                   # App entry point
├── theme/
│   └── app_theme.dart          # Dark glass/neon theme
├── models/
│   └── models.dart             # Data models
├── providers/
│   ├── dashboard_provider.dart # Main state (apps, sites, todos)
│   ├── weather_provider.dart   # Weather fetching
│   └── system_provider.dart   # System stats
├── screens/
│   └── dashboard_screen.dart   # Main screen layout
└── widgets/
    ├── clock_widget.dart        # Clock & date
    ├── weather_widget.dart      # Weather display
    ├── app_launcher_widget.dart # App grid
    ├── website_widget.dart      # Website chips
    ├── todo_widget.dart         # Task list
    ├── system_stats_widget.dart # CPU/RAM/Disk bars
    ├── settings_panel.dart      # Settings drawer
    ├── particle_background.dart # Floating particles
    ├── add_app_dialog.dart      # Add/edit app dialog
    └── add_website_dialog.dart  # Add/edit website dialog
```

---

Made with ❤️ using Flutter for Windows Desktop
