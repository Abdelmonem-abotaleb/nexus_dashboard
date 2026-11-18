import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Manages native Windows DWM attributes for seamless transparent widget mode.
class WindowTransparencyService {
  WindowTransparencyService._();

  static const _windowClassName = 'FLUTTER_RUNNER_WIN32_WINDOW';
  static const _dwmwaBorderColor = 34;
  static const _dwmwaSystemBackdropType = 38;
  static const _dwmwaMicaEffect = 1029;
  static const _dwmSbtNone = 1;
  static const _dwmColorNone = 0xFFFFFFFE;
  static const _dwmColorDefault = 0xFFFFFFFF;

  /// Clears Windows 11 system backdrop, removes the OS frame border, and
  /// extends the DWM frame into the client area for per-pixel transparency.
  static void applyTransparentWidgetBackdrop() {
    if (!Platform.isWindows) return;
    final hwnd = _findCurrentProcessWindow();
    if (hwnd == 0) return;

    try {
      final exStyle = GetWindowLongPtr(hwnd, GWL_EXSTYLE);
      if ((exStyle & WS_EX_LAYERED) != 0) {
        SetWindowLongPtr(hwnd, GWL_EXSTYLE, exStyle & ~WS_EX_LAYERED);
        SetWindowPos(
          hwnd,
          0,
          0,
          0,
          0,
          0,
          SWP_NOMOVE |
              SWP_NOSIZE |
              SWP_NOZORDER |
              SWP_NOACTIVATE |
              SWP_FRAMECHANGED,
        );
      }

      _setDwmIntAttribute(hwnd, _dwmwaSystemBackdropType, _dwmSbtNone);
      _setDwmIntAttribute(hwnd, _dwmwaMicaEffect, FALSE);
      _setDwmUint32Attribute(hwnd, _dwmwaBorderColor, _dwmColorNone);

      final margins = calloc<MARGINS>();
      try {
        margins.ref
          ..cxLeftWidth = -1
          ..cxRightWidth = -1
          ..cyTopHeight = -1
          ..cyBottomHeight = -1;
        DwmExtendFrameIntoClientArea(hwnd, margins);
      } finally {
        calloc.free(margins);
      }
    } catch (_) {
      // Ignore DWM errors on older Windows builds or headless test hosts.
    }
  }

  /// Restores the default OS window border before applying a standard backdrop.
  static void restoreStandardBackdrop() {
    if (!Platform.isWindows) return;
    final hwnd = _findCurrentProcessWindow();
    if (hwnd == 0) return;

    try {
      _setDwmUint32Attribute(hwnd, _dwmwaBorderColor, _dwmColorDefault);
    } catch (_) {
      // Ignore DWM errors on older Windows builds or headless test hosts.
    }
  }

  static void _setDwmIntAttribute(int hwnd, int attribute, int value) {
    final ptr = calloc<Int32>();
    try {
      ptr.value = value;
      DwmSetWindowAttribute(hwnd, attribute, ptr, sizeOf<Int32>());
    } finally {
      calloc.free(ptr);
    }
  }

  static void _setDwmUint32Attribute(int hwnd, int attribute, int value) {
    final ptr = calloc<Uint32>();
    try {
      ptr.value = value;
      DwmSetWindowAttribute(hwnd, attribute, ptr, sizeOf<Uint32>());
    } finally {
      calloc.free(ptr);
    }
  }

  static int _findCurrentProcessWindow() {
    final currentPid = GetCurrentProcessId();
    final classNamePtr = TEXT(_windowClassName);
    final windowPidPtr = calloc<Uint32>();
    try {
      var hwnd = FindWindowEx(0, 0, classNamePtr, nullptr);
      while (hwnd != 0) {
        GetWindowThreadProcessId(hwnd, windowPidPtr);
        if (windowPidPtr.value == currentPid) {
          return hwnd;
        }
        hwnd = FindWindowEx(0, hwnd, classNamePtr, nullptr);
      }
      return 0;
    } finally {
      calloc.free(classNamePtr);
      calloc.free(windowPidPtr);
    }
  }
}
