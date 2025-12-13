import 'dart:io';

import 'package:yaml/yaml.dart';

void main() async {
  print('🚀 Starting Release Process\n');

  try {
    // Step 1: Read pubspec.yaml and extract version info
    final pubspecFile = File('pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      throw Exception('pubspec.yaml not found in current directory');
    }

    final pubspecContent = pubspecFile.readAsStringSync();
    final pubspec = loadYaml(pubspecContent);
    final versionName = pubspec['version'] as String;

    if (!await confirm('Continue to check git status?')) {
      print('❌ Aborted by user');
      exit(1);
    }

    // Step 4: Check for uncommitted changes
    print('\n🔍 Checking git status...');
    final gitStatus = await runCommand('git', ['status', '--porcelain']);

    if (gitStatus.trim().isNotEmpty) {
      print('❌ You have uncommitted changes:');
      print(gitStatus);
      print('\nPlease commit or stash your changes before releasing.');
      exit(1);
    }
    print('✅ No uncommitted changes');

    if (!await confirm('Continue to create git tag and release?')) {
      print('❌ Aborted by user');
      exit(1);
    }

    // Step 5: Extract changelog for this version
    print('\n📋 Extracting changelog...');
    final changelogFile = File('CHANGELOG.md');
    if (!changelogFile.existsSync()) {
      throw Exception('CHANGELOG.md not found');
    }

    final changelogContent = changelogFile.readAsStringSync();
    final changelog = extractChangelogForVersion(changelogContent, versionName);

    if (changelog.isEmpty) {
      print('⚠️  No changelog found for version $versionName');
      if (!await confirm('Continue without changelog?')) {
        print('❌ Aborted by user');
        exit(1);
      }
    } else {
      print('📋 Changelog for v$versionName:');
      print(changelog);
      if (!await confirm('Is this changelog correct?')) {
        print('❌ Aborted by user');
        exit(1);
      }
    }

    // Step 6: Create git tag
    final tagName = 'macro_kit-$versionName';
    print('\n🏷️  Creating git tag: $tagName');

    await runCommand('git', ['tag', '-a', tagName, '-m', 'Release $versionName']);
    print('✅ Tag created');

    if (!await confirm('Push tag to remote?')) {
      print('❌ Aborted by user');
      print('⚠️  Tag created locally but not pushed. Run: git push origin $tagName');
      exit(1);
    }

    await runCommand('git', ['push', 'origin', tagName]);
    print('✅ Tag pushed to remote');

    // Step 7: Create GitHub release
    print('\n🎉 Creating GitHub release...');

    final releaseBody = changelog.isNotEmpty ? changelog : 'Release $versionName';

    // Using gh CLI to create release
    final ghInstalled = await isCommandAvailable('gh');
    if (!ghInstalled) {
      print('⚠️  GitHub CLI (gh) not found. Please install it or create the release manually.');
      print('   Tag: $tagName');
      print('   Release notes:\n$releaseBody');
      exit(0);
    }

    if (!await confirm('Create GitHub release using gh CLI?')) {
      print('❌ Aborted by user');
      print('⚠️  Tag pushed but release not created. You can create it manually on GitHub.');
      exit(1);
    }

    final releaseFile = File('.release_notes_temp.md');
    releaseFile.writeAsStringSync(releaseBody);

    try {
      await runCommand('gh', [
        'release',
        'create',
        tagName,
        '--title',
        'Release $versionName',
        '--notes-file',
        '.release_notes_temp.md',
      ]);
      print('✅ GitHub release created');
    } finally {
      if (releaseFile.existsSync()) {
        releaseFile.deleteSync();
      }
    }

    print('\n🎊 Release process completed successfully!');
    print('   Version: $versionName');
    print('   Tag: $tagName');
    print('   Release: https://github.com/YOUR_ORG/YOUR_REPO/releases/tag/$tagName');
  } catch (e) {
    print('\n❌ Error: $e');
    exit(1);
  }
}

Future<bool> confirm(String message) async {
  stdout.write('$message (y/n) [y]: ');
  final input = stdin.readLineSync()?.toLowerCase().trim();
  return input == 'y' || input == 'yes' || input == '' || input == null;
}

Future<String> runCommand(String command, List<String> args) async {
  final result = await Process.run(command, args);
  if (result.exitCode != 0) {
    throw Exception('Command failed: $command ${args.join(' ')}\n${result.stderr}');
  }
  return result.stdout.toString();
}

Future<bool> isCommandAvailable(String command) async {
  try {
    await Process.run('which', [command]);
    return true;
  } catch (e) {
    return false;
  }
}

String extractChangelogForVersion(String changelog, String version) {
  // Match pattern like "## 0.2.2" or "## [0.2.2]"
  final versionPattern = RegExp(
    r'##\s+\[?' + RegExp.escape(version) + r'\]?.*?\n(.*?)(?=\n##|\Z)',
    multiLine: true,
    dotAll: true,
  );

  final match = versionPattern.firstMatch(changelog);
  if (match != null && match.groupCount >= 1) {
    return match.group(1)!.trim();
  }

  return '';
}
