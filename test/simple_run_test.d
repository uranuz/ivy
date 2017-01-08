module ivy.interpreter_test;

import std.stdio;

import ivy;



void main()
{
	import std.path: getcwd, buildNormalizedPath;
	string sourceFileName = "test/compiler_test_template.html";

	auto progCache = new ProgrammeCache!(true)([getcwd()]);
	ExecutableProgramme prog = progCache.getProgramme( buildNormalizedPath(getcwd(), sourceFileName) );
	
	TDataNode[string] dataDict;
	TDataNode result = prog.run( TDataNode(dataDict) );

	writeln( result.toString() );
}
