module ivy.interpreter_test;

import std.stdio;

import ivy;



void main()
{
	import std.path: getcwd;
	string sourceFileName = "test/compiler_test_template.html";
	ExecutableProgramme prog = ivy.compileFile( sourceFileName, [getcwd()] );
	
	TDataNode[string] dataDict;
	TDataNode result = prog.run( TDataNode(dataDict) );

	writeln( result.toString() );
}
