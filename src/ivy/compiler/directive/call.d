module ivy.compiler.directive.call;

import ivy.compiler.directive.utils;

class CallCompiler: IDirectiveCompiler
{
	override void compile(IDirectiveStatement stmt, ByteCodeCompiler compiler)
	{
		auto stmtRange = stmt[];
		if( stmtRange.empty )
			compiler.log.error(`Expected callable argument!`);

		stmtRange.front.accept(compiler);
		stmtRange.popFront();

		compiler.addInstr(OpCode.DubTop); // Callable it to be consumed by LoadSubscr. So copy it...

		// Get callable's module name to ensure that it is imported using ImportModule
		compiler.addInstr(OpCode.LoadConst, compiler.addConst( IvyData(`moduleName`) ));
		compiler.addInstr(OpCode.LoadSubscr);

		compiler.addInstr(OpCode.ImportModule);
		compiler.addInstr(OpCode.PopTop); // Drop module's return value...
		compiler.addInstr(OpCode.PopTop); // Drop module's execution frame...

		if( stmtRange.empty )
			compiler.log.error(`Expected arguments!`);
		stmtRange.front.accept(compiler);
		stmtRange.popFront();

		compiler.addInstr(OpCode.Call);

		if( !stmtRange.empty ) {
			compiler.log.error(`Expected end of "call" directive. Maybe ';' is missing`);
		}
	}
}