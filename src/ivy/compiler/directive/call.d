module ivy.compiler.directive.call;

import ivy.compiler.directive.utils;

class CallCompiler: BaseDirectiveCompiler
{
public:
	override void compile(IDirectiveStatement stmt, ByteCodeCompiler compiler)
	{
		import ivy.types.call_spec: CallSpec;

		auto stmtRange = stmt[];
		if( stmtRange.empty )
			compiler.log.error(`Expected callable argument!`);

		// Get callable expression AST and remember in order to put it last in stack
		auto callableExpr = stmtRange.front;
		stmtRange.popFront();

		if( stmtRange.empty )
			compiler.log.error(`Expected call arguments assoc array`);
		stmtRange.front.accept(compiler);
		stmtRange.popFront();

		if( !stmtRange.empty )
			compiler.log.error(`Expected end of "call" directive. Maybe ';' is missing`);

		// Compile callable expr AST
		callableExpr.accept(compiler);
		compiler.addInstr(OpCode.DubTop); // Callable it to be consumed by LoadSubscr. So copy it...

		// Get callable's module name to ensure that it is imported using ImportModule
		compiler.addInstr(OpCode.LoadConst, compiler.addConst( IvyData(`moduleName`) ));
		compiler.addInstr(OpCode.LoadSubscr);

		compiler.addInstr(OpCode.ImportModule);
		compiler.addInstr(OpCode.PopTop); // Drop module's return value...
		compiler.addInstr(OpCode.PopTop); // Drop module's execution frame...

		compiler.addInstr(OpCode.RunCallable, CallSpec(0, true).encode());
	}
}