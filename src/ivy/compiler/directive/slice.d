module ivy.compiler.directive.slice;

import ivy.compiler.directive.utils;

class SliceCompiler: BaseDirectiveCompiler
{
	override void compile(IDirectiveStatement stmt, ByteCodeCompiler compiler)
	{
		auto stmtRange = stmt[];

		assure(!stmtRange.empty, `Expected node as "slice"s "aggregate" argument!`);
		stmtRange.front.accept(compiler);
		stmtRange.popFront();

		assure(!stmtRange.empty, `Expected node as "slice"s "begin" argument!`);
		stmtRange.front.accept(compiler);
		stmtRange.popFront();

		assure(!stmtRange.empty, `Expected node as "slice"s "end" argument!`);
		stmtRange.front.accept(compiler);
		stmtRange.popFront();

		compiler.addInstr(OpCode.LoadSlice); // Add Insert instruction that works with 3 passed arguments

		assure(stmtRange.empty, "Expected end of \"slice\" directive. Maybe ';' is missing");
	}
}