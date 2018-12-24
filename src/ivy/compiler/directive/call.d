module ivy.compiler.directive.call;

import ivy.compiler.directive.utils;

class CallCompiler: IDirectiveCompiler
{
	override void compile(IDirectiveStatement stmt, ByteCodeCompiler compiler)
	{
		auto stmtRange = stmt[];
		if( stmtRange.empty )
			compiler.loger.error(`Expected callable argument!`);

		stmtRange.front.accept(compiler);
		stmtRange.popFront();

		if( stmtRange.empty )
			compiler.loger.error(`Expected arguments!`);
		stmtRange.front.accept(compiler);
		stmtRange.popFront();

		compiler.addInstr(OpCode.Call);

		if( !stmtRange.empty ) {
			compiler.loger.error(`Expected end of "call" directive. Maybe ';' is missing`);
		}
	}
}