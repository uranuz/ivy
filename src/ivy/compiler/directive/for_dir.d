module ivy.compiler.directive.for_dir;

import ivy.compiler.directive.utils;
import ivy.ast.iface: INameExpression, IExpression, ICompoundStatement;
import ivy.compiler.compiler: JumpKind;

class ForCompiler : BaseDirectiveCompiler
{
public:
	override void compile(IDirectiveStatement stmt, ByteCodeCompiler compiler)
	{
		import std.range: popBack, empty, back;
		alias JumpTableItem = ByteCodeCompiler.JumpTableItem;
		
		auto stmtRange = stmt[];
		INameExpression varNameExpr = stmtRange.takeFrontAs!INameExpression("For loop variable name expected");

		string varName = varNameExpr.name;
		if( varName.length == 0 )
			compiler.log.error("Loop variable name cannot be empty");

		INameExpression inAttribute = stmtRange.takeFrontAs!INameExpression("Expected 'in' attribute");

		if( inAttribute.name != "in" )
			compiler.log.error("Expected 'in' keyword");

		IExpression aggregateExpr = stmtRange.takeFrontAs!IExpression("Expected 'for' aggregate expression");
		ICompoundStatement bodyStmt = stmtRange.takeFrontAs!ICompoundStatement("Expected loop body statement");

		if( !stmtRange.empty )
			compiler.log.error("Expected end of directive after loop body. Maybe ';' is missing");

		// TODO: Check somehow if aggregate has supported type

		// Add nem jumps list item into jump table stack
		compiler._jumpTableStack ~= JumpTableItem[].init;

		// Compile code to calculate aggregate value
		aggregateExpr.accept(compiler);

		// Issue instruction to get iterator from aggregate in execution stack
		compiler.addInstr( OpCode.GetDataRange );

		size_t loopStartInstrIndex = compiler.addInstr(OpCode.RunLoop);

		// Issue command to store current loop item in local context with specified name
		compiler.addInstr(OpCode.StoreName, compiler.addConst( IvyData(varName) ));

		bodyStmt.accept(compiler);

		// Drop result that we don't care about in this loop type
		compiler.addInstr(OpCode.PopTop);

		size_t loopEndInstrIndex = compiler.addInstr(OpCode.Jump, loopStartInstrIndex);
		compiler.setInstrArg(loopStartInstrIndex, loopEndInstrIndex);

		// Push fake result to "make all happy" ;)
		compiler.addInstr(OpCode.LoadConst, compiler.addConst( IvyData() ));

		compiler.log.internalAssert(!compiler._jumpTableStack.empty, `Jump table stack is empty!`);
		JumpTableItem[] jumpTable = compiler._jumpTableStack.back;
		compiler._jumpTableStack.popBack();
		foreach( ref JumpTableItem item; jumpTable )
		{
			final switch( item.jumpKind )
			{
				case JumpKind.Break: {
					compiler.setInstrArg(item.instrIndex, loopStartInstrIndex);
					break;
				}
				case JumpKind.Continue: {
					compiler.setInstrArg(item.instrIndex, loopEndInstrIndex);
					break;
				}
			}
		}
	}
}