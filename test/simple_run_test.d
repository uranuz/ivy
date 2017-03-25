module ivy.interpreter_test;

import std.stdio;
import ivy;
import ivy.common;

import ivy, ivy.compiler, ivy.interpreter, ivy.common, ivy.lexer, ivy.parser;

void f() {
	import std.path: getcwd, buildNormalizedPath;
	
	void stdOutLoger(LogInfo logInfo) {
		writeln(logInfo.sourceFileName, `(`, logInfo.sourceLine, `), `, logInfo.sourceFuncName, `: `, logInfo.msg);
	}

	IvyConfig ivyConfig;
	ivyConfig.importPaths = [buildNormalizedPath(getcwd(), `test`)];
	ivyConfig.fileExtension = ".html";
	ivyConfig.interpreterLoger = &stdOutLoger;
	ivyConfig.compilerLoger = &stdOutLoger;
	ivyConfig.parserLoger = &stdOutLoger;

	auto progCache = new ProgrammeCache!(false)(ivyConfig);
	auto prog = progCache.getByModuleName("compiler_test_template");
	
	TDataNode dataDict;
	TDataNode result = prog.run(dataDict);

	writeln(result.toString());

}

void main()
{
	f();
}
