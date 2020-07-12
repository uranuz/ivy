module ivy.compiler.directive.set_at;

import ivy.compiler.directive.utils;
import ivy.ast.iface: IExpression;

class SetAtCompiler : IDirectiveCompiler
{
public:
	override void compile(IDirectiveStatement statement, ByteCodeCompiler compiler)
	{
		auto stmtRange = statement[];

		IExpression aggregate = stmtRange.takeFrontAs!IExpression(`Expected expression as "at" aggregate argument`);
		IExpression assignedValue = stmtRange.takeFrontAs!IExpression(`Expected expression as "at" value to assign`);
		IExpression indexValue = stmtRange.takeFrontAs!IExpression(`Expected expression as "at" index value`);

		aggregate.accept(compiler); // Evaluate aggregate
		assignedValue.accept(compiler); // Evaluate assigned value
		indexValue.accept(compiler); // Evaluate index
		compiler.addInstr(OpCode.StoreSubscr);

		// Add fake value to stack as a result
		compiler.addInstr(OpCode.LoadConst, compiler.addConst( IvyData() ));

		if( !stmtRange.empty )
			compiler.log.error(`Expected end of "setat" directive after index expression. Maybe ';' is missing. `
				~ `Info: multiple index expressions are not supported yet.`);
	}
}