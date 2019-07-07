module ivy.compiler.directive.return_dir;

import ivy.compiler.directive.utils;

class ReturnCompiler: IDirectiveCompiler
{
	override void compile(IDirectiveStatement stmt, ByteCodeCompiler compiler)
	{
		auto stmtRange = stmt[];

		if( !stmtRange.empty )
		{
			// Evaluating return expression if it is there
			stmtRange.front.accept(compiler);
			stmtRange.popFront();
		}
		else
		{
			// Put Undef value on the stack if there is no value
			compiler.addInstr(OpCode.LoadConst, compiler.addConst( IvyData() ));
		}

		if( !stmtRange.empty ) {
			compiler.loger.error(`Expected end of "return" directive. Maybe ';' is missing`);
		}

		compiler.addInstr(OpCode.Return); // Add Return instruction that goes to the end of code object
	}
}