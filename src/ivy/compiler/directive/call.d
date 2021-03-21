module ivy.compiler.directive.call;

import ivy.compiler.directive.utils;

class CallCompiler: BaseDirectiveCompiler
{
public:
	override void compile(IDirectiveStatement stmt, ByteCodeCompiler compiler)
	{
		import ivy.types.call_spec: CallSpec;

		auto stmtRange = stmt[];
		assure(!stmtRange.empty, "Expected callable argument!");

		// Get callable expression AST and remember in order to put it last in stack
		auto callableExpr = stmtRange.front;
		stmtRange.popFront();

		assure(!stmtRange.empty, "Expected call arguments assoc array");
		stmtRange.front.accept(compiler);
		stmtRange.popFront();

		assure(stmtRange.empty, "Expected end of \"call\" directive. Maybe ';' is missing");

		// Compile callable expr AST
		callableExpr.accept(compiler);

		compiler.addInstr(OpCode.RunCallable, CallSpec(0, true).encode());
	}
}