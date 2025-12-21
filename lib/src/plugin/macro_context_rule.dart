import 'dart:io';

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:macro_kit/src/common/logger.dart';
import 'package:path/path.dart' as p;

class MacroContextRule extends AnalysisRule {
  MacroContextRule({
    required this.logger,
    required this.onNewAnalysisContext,
  }) : super(
         name: 'macro_context',
         description:
             'Allows macros to discover and apply contextual information from analysis contexts during code generation',
       );

  final MacroLogger logger;
  final void Function(String) onNewAnalysisContext;

  @override
  DiagnosticCode get diagnosticCode => LintCode(
    'macro_context',
    'macro context',
    uniqueName: 'macro_context',
    correctionMessage: '',
    hasPublishedDocs: false,
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    var visitor = _Visitor(rule: this);
    registry.addCompilationUnit(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor({required this.rule});

  final MacroContextRule rule;

  @override
  void visitCompilationUnit(CompilationUnit node) {
    const macroContextFileName = 'macro_context.dart';

    final element = node.declaredFragment?.element;
    if (element == null) return;

    // Get the file name
    final fileName = element.library.firstFragment.source.shortName;

    // Check if this is macro file or not
    if (fileName != macroContextFileName) return;

    // Get the full file path
    final filePath = element.library.firstFragment.source.fullName;
    final file = File(filePath);

    if (p.basenameWithoutExtension(file.parent.path) != 'lib') {
      // Must be in lib folder
      return;
    }

    // Find the project root
    final contextRoot = _findProjectRoot(file);
    if (contextRoot == null) {
      rule.logger.warn('project root not found');
      rule.reportAtOffset(
        0,
        0,
        arguments: ['Could not find pubspec.yaml for macro_context.dart'],
      );
      return;
    }

    rule.onNewAnalysisContext(contextRoot);
  }

  String? _findProjectRoot(File file) {
    const maxLevels = 3;
    var directory = file.parent;
    var levelsChecked = 0;

    // Traverse up the directory tree looking for pubspec.yaml
    while (levelsChecked < maxLevels) {
      var pubspecPath = p.join(directory.path, 'pubspec.yaml');

      if (File(pubspecPath).existsSync()) {
        return directory.path;
      }

      // Move to parent directory & Check if we've reached the filesystem root
      final parent = directory.parent;
      if (parent.path == directory.path) {
        return null;
      }

      directory = parent;
      levelsChecked++;
    }

    return null;
  }
}
