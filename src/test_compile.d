module ivy.interpreter_test;

import std.stdio;
import ivy;
import ivy.common;

/++
void main()
{
	import std.path: getcwd, buildNormalizedPath;
	
	void stdOutLoger(LogInfo logInfo) {
		writeln(logInfo.sourceFileName, `(`, logInfo.sourceLine, `), `, logInfo.sourceFuncName, `: `, logInfo.msg);
	}

	IvyConfig ivyConfig;
	ivyConfig.importPaths = [buildNormalizedPath(`C:\valera\`)];
	ivyConfig.fileExtension = ".ivy";
	ivyConfig.interpreterLoger = &stdOutLoger;
	ivyConfig.compilerLoger = &stdOutLoger;
	ivyConfig.parserLoger = &stdOutLoger;

	auto progCache = new ProgrammeCache!(true)(ivyConfig);
	auto prog = progCache.getByModuleName("fir.controls.PlainListBox");
	
	//TDataNode dataDict;
	//TDataNode result = prog.run(dataDict);
	import std.file;
	
	//writeln(prog.toString());
	write(`compiled.json`, prog.toStdJSON().toString());
}
+/