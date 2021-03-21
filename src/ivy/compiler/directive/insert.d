module ivy.compiler.directive.insert;

import ivy.compiler.directive.utils;

class InsertCompiler: BaseDirectiveCompiler
{
public:
	override void compile(IDirectiveStatement stmt, ByteCodeCompiler compiler)
	{
		auto stmtRange = stmt[];

		assure(!stmtRange.empty, `Expected node as "insert"s "aggregate" argument!`);
		stmtRange.front.accept(compiler);
		stmtRange.popFront();

		assure(!stmtRange.empty, `Expected node as "insert"s "value" argument!`);
		stmtRange.front.accept(compiler);
		stmtRange.popFront();

		assure(!stmtRange.empty, `Expected node as "insert"s "index" argument!`);
		stmtRange.front.accept(compiler);
		stmtRange.popFront();

		compiler.addInstr(OpCode.Insert); // Add Insert instruction that works with 3 passed arguments

		assure(stmtRange.empty, `Expected end of "insert" directive. Maybe ';' is missing`);
	}
}