module ivy.compiler.directive.expr;

import ivy.compiler.directive.utils;
import ivy.ast.iface: INameExpression;

class ExprCompiler: BaseDirectiveCompiler
{
public:
	override void compile(IDirectiveStatement stmt, ByteCodeCompiler compiler)
	{
		auto stmtRange = stmt[];
		assure(!stmtRange.empty, "Expected node as \"expr\" argument!");

		stmtRange.front.accept(compiler);
		stmtRange.popFront();

		assure(stmtRange.empty, "Expected end of \"expr\" directive. Maybe ';' is missing");
	}
}