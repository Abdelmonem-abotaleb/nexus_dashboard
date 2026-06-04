import 'dart:io';

typedef CommandRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

class StartupService {
  static const runKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const valueName = 'NexusDashboard';

  final String operatingSystem;
  final String executablePath;
  final CommandRunner runCommand;

  StartupService({
    String? operatingSystem,
    String? executablePath,
    CommandRunner? runCommand,
  }) : operatingSystem = operatingSystem ?? Platform.operatingSystem,
       executablePath = executablePath ?? Platform.resolvedExecutable,
       runCommand = runCommand ?? Process.run;

  bool get isSupported => operatingSystem == 'windows';

  Future<bool> isEnabled() async {
    if (!isSupported) return false;

    final result = await runCommand('reg', ['query', runKey, '/v', valueName]);

    return result.exitCode == 0 && result.stdout.toString().contains(valueName);
  }

  Future<void> setEnabled(bool enabled) async {
    if (!isSupported) return;

    final result = enabled ? await _enable() : await _disable();
    if (result.exitCode != 0) {
      throw StartupServiceException(result.stderr.toString().trim());
    }
  }

  Future<ProcessResult> _enable() {
    return runCommand('reg', [
      'add',
      runKey,
      '/v',
      valueName,
      '/t',
      'REG_SZ',
      '/d',
      '"$executablePath"',
      '/f',
    ]);
  }

  Future<ProcessResult> _disable() {
    return runCommand('reg', ['delete', runKey, '/v', valueName, '/f']);
  }
}

class StartupServiceException implements Exception {
  final String message;

  const StartupServiceException(this.message);

  @override
  String toString() {
    if (message.isEmpty) return 'Could not update startup setting';
    return message;
  }
}
