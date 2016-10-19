module ivy.interpreter_test;

import std.stdio, std.json, std.file;

import ivy.interpreter, ivy.directive_interpreters, ivy.interpreter_data, ivy.node, ivy.lexer_tools, ivy.lexer, ivy.common, ivy.parser, ivy.ast_writer;



void main()
{
	alias TextRange = TextForwardRange!(string, LocationConfig());

	string sourceFileName = "test/bytecode_template.html";
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

	ICompositeInterpretersController rootController = makeRootInterpreter();
	ICompositeInterpretersController inlineDirController = new InlineDirectivesController();
	rootController.addController(inlineDirController);

	auto visitor = new Interpreter(rootController, inlineDirController);
 	alias TDataNode = DataNode!string;


	ast.accept(visitor);

	writeln(visitor.opnd);

}