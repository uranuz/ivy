module ivy.compiler.directive.repeat;

import ivy.compiler.directive.utils;
import ivy.ast.iface: INameExpression, IExpression, ICompoundStatement;
import ivy.compiler.compiler: JumpKind;

class RepeatCompiler : BaseDirectiveCompiler
{
public:
	override void compile(IDirectiveStatement stmt, ByteCodeCompiler compiler)
	{
		import std.range: popBack, empty, back;
		alias JumpTableItem = ByteCodeCompiler.JumpTableItem;

		auto stmtRange = stmt[];

		INameExpression varNameExpr = stmtRange.takeFrontAs!INameExpression("Loop variable name expected");

		string varName = varNameExpr.name;
		if( varName.length == 0 )
			compiler.log.error("Loop variable name cannot be empty");

		INameExpression inAttribute = stmtRange.takeFrontAs!INameExpression("Expected 'in' attribute");

		if( inAttribute.name != "in" )
			compiler.log.error("Expected 'in' keyword");

		IExpression aggregateExpr = stmtRange.takeFrontAs!IExpression("Expected loop aggregate expression");

		// Add nem jumps list item into jump table stack
		compiler._jumpTableStack ~= JumpTableItem[].init;

		// Compile code to calculate aggregate value
		aggregateExpr.accept(compiler);

		ICompoundStatement bodyStmt = stmtRange.takeFrontAs!ICompoundStatement("Expected loop body statement");

		if( !stmtRange.empty )
			compiler.log.error("Expected end of directive after loop body. Maybe ';' is missing");

		// Issue instruction to get iterator from aggregate in execution stack
		compiler.addInstr(OpCode.GetDataRange);

		// Creating node for string result on stack
		compiler.addInstr(OpCode.LoadConst, compiler.addConst( IvyData(IvyData[].init) ));

		// RunLoop expects  data node range on the top, but result aggregator
		// can be left on (TOP - 1), so swap these...
		compiler.addInstr(OpCode.SwapTwo);

		// Run our super-duper loop
		size_t loopStartInstrIndex = compiler.addInstr(OpCode.RunLoop);

		// Issue command to store current loop item in local context with specified name
		compiler.addInstr(OpCode.StoreName, compiler.addConst( IvyData(varName) ));

		// Swap data node range with result, so that we have it on (TOP - 1) when loop body finished
		compiler.addInstr(OpCode.SwapTwo);

		bodyStmt.accept(compiler);

		// Apend current result to previous
		compiler.addInstr(OpCode.Append);

		// Put data node range at the TOP and result on (TOP - 1)
		compiler.addInstr(OpCode.SwapTwo);

		size_t loopEndInstrIndex = compiler.addInstr(OpCode.Jump, loopStartInstrIndex);
		// We need to say RunLoop where to jump when range become empty
		compiler.setInstrArg(loopStartInstrIndex, loopEndInstrIndex);

		// Data range is dropped by RunLoop already

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