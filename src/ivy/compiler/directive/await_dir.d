module ivy.compiler.directive.await_dir;

import ivy.compiler.directive.utils;

class AwaitCompiler: BaseDirectiveCompiler
{
public:
	override void compile(IDirectiveStatement stmt, ByteCodeCompiler compiler)
	{
		auto stmtRange = stmt[];
		assure(!stmtRange.empty, "Expected node as \"await\" argument!");

		stmtRange.front.accept(compiler);
		stmtRange.popFront();

		compiler.addInstr(OpCode.Await);

		assure(stmtRange.empty, "Expected end of \"await\" directive. Maybe ';' is missing");
	}
}