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
	
	stdout.writeln(toJSON(&astJSON, true));

	ModuleObject moduleObj = new ModuleObject(sourceFileName, sourceFileName);
	ByteCodeCompiler compiler = new ByteCodeCompiler( moduleObj );
	ast.accept(compiler);

	DirectiveObject rootDirObj = new DirectiveObject;
	rootDirObj._codeObj = moduleObj.getMainCodeObject();

	Interpreter interp = new Interpreter(rootDirObj);
 	interp.setLocalValue("content", TDataNode("<div>Основное содержимое формы</div>"));
 	interp.setLocalValue("content2", TDataNode("Еще какое-то содержимое страницы"));
 	interp.setLocalValue("content3", TDataNode("Здравствуй, Вася"));
 	interp.setLocalValue("x", TDataNode(20));
 	interp.setLocalValue("y", TDataNode("no"));

	interp.execLoop();

	import std.range: back;
	writeln(interp._stack.back);
	
}