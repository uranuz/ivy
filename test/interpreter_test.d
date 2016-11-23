module ivy.interpreter_test;

import std.stdio, std.json, std.file;

import ivy.interpreter, ivy.directive_interpreters, ivy.interpreter_data, ivy.node, ivy.lexer_tools, ivy.lexer, ivy.common, ivy.parser, ivy.ast_writer, ivy.compiler;



void main()
{
	alias TextRange = TextForwardRange!(string, LocationConfig());
	alias TDataNode = DataNode!string;

	string sourceFileName = "test/compiler_test_template.html";
	string source = cast(string) std.file.read(sourceFileName);
	
	auto parser = new Parser!(TextRange)(source, sourceFileName);
	
	IvyNode ast;
	
	try {
		ast = parser.parse();
	} catch(Throwable e) {
		throw e;
	}
	
	JSONValue astJSON;
	
	writeASTasJSON(parser.lexer.sourceRange, ast, astJSON);
	
	stdout.writeln(toJSON(astJSON, true));

	auto compilerModuleRepo = new CompilerModuleRepository("test");
	auto symbCollector = new CompilerSymbolsCollector(compilerModuleRepo, "test");
	ast.accept(symbCollector);

	SymbolTableFrame[string] symbTable = symbCollector.getModuleSymbols();
	/+
	string modulesSymbolTablesDump;
	foreach( modName, frame; symbTable )
	{
		modulesSymbolTablesDump ~= "\r\nMODULE " ~ modName ~ " CONTENTS:\r\n";
		modulesSymbolTablesDump ~= frame.toPrettyStr() ~ "\r\n";
	}

	writeln(modulesSymbolTablesDump);
	+/

	auto compiler = new ByteCodeCompiler( compilerModuleRepo, symbTable, "test" );
	ast.accept(compiler);

	writeln( compiler.toPrettyStr() );

	DirectiveObject rootDirObj = new DirectiveObject;
	rootDirObj._codeObj = compiler.getMainModule().getMainCodeObject();

	Interpreter interp = new Interpreter(rootDirObj);
	interp.execLoop();

	import std.range: back;
	writeln("Programme returned: ", interp._stack.back);
}
