import 'dart:io';

enum PowerAction { shutdown, restart }

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
    };
  }
}

Future<void> runPowerAction(PowerAction action) async {
  final command = PowerCommand.forAction(action);
  final process = await Process.start(
    command.executable,
    command.arguments,
    runInShell: true,
  );
  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    throw ProcessException(command.executable, command.arguments);
  }
}
