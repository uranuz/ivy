module ivy.compiler.directive.await_dir;

import ivy.compiler.directive.utils;

class AwaitCompiler: BaseDirectiveCompiler
{
public:
	override void compile(IDirectiveStatement stmt, ByteCodeCompiler compiler)
	{
		auto stmtRange = stmt[];
		if( stmtRange.empty )
			compiler.log.error(`Expected node as "await" argument!`);

		stmtRange.front.accept(compiler);
		stmtRange.popFront();

		compiler.addInstr(OpCode.Await);

		if( !stmtRange.empty ) {
			compiler.log.error(`Expected end of "await" directive. Maybe ';' is missing`);
		}
	}
}