module ivy.compiler.directive.expr;

import ivy.compiler.directive.utils;
import ivy.ast.iface: INameExpression;

class ExprCompiler: IDirectiveCompiler
{
	override void compile(IDirectiveStatement stmt, ByteCodeCompiler compiler)
	{
		auto stmtRange = stmt[];
		if( stmtRange.empty )
			compiler.loger.error(`Expected node as "expr" argument!`);

		stmtRange.front.accept(compiler);
		stmtRange.popFront();

		if( !stmtRange.empty )
		{
			compiler.loger.write("ExprCompiler. At end. stmtRange.front.kind: ", ( cast(INameExpression) stmtRange.front ).name);
			compiler.loger.error(`Expected end of "expr" directive. Maybe ';' is missing`);
		}
	}
}