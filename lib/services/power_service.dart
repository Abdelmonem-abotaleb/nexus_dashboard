import 'dart:io';

enum PowerAction { shutdown, restart, sleep }

class PowerCommand {
  final String executable;
  final List<String> arguments;

  const PowerCommand({required this.executable, required this.arguments});

  factory PowerCommand.forAction(PowerAction action) {
    return switch (action) {
      PowerAction.shutdown => const PowerCommand(
        executable: 'shutdown',
        arguments: ['/s', '/t', '0'],
      ),
      PowerAction.restart => const PowerCommand(
        executable: 'shutdown',
        arguments: ['/r', '/t', '0'],
      ),
      PowerAction.sleep => const PowerCommand(
        executable: 'rundll32',
        arguments: ['powrprof.dll,SetSuspendState', 'Sleep'],
      ),
    };
  }
}

Future<void> runPowerAction(
  PowerAction action, {
  Future<Process> Function(String, List<String>, {bool runInShell})? processStarter,
}) async {
  final command = PowerCommand.forAction(action);
  final starter = processStarter ??
      ((exe, args, {bool runInShell = false}) =>
          Process.start(exe, args, runInShell: runInShell));
  final process = await starter(
    command.executable,
    command.arguments,
    runInShell: false,
  );
  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    throw ProcessException(command.executable, command.arguments);
  }
}
