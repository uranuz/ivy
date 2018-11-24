module ivy.compiler.directive.if_dir;

import ivy.compiler.directive.utils;
import ivy.parser.node: INameExpression, IExpression;

class IfCompiler: IDirectiveCompiler
{
	override void compile(IDirectiveStatement statement, ByteCodeCompiler compiler)
	{
		import std.typecons: Tuple;
		import std.range: back, empty;
		alias IfSect = Tuple!(IExpression, "cond", IExpression, "stmt");

		IfSect[] ifSects;
		IExpression elseBody;

		auto stmtRange = statement[];

		IExpression condExpr = stmtRange.takeFrontAs!IExpression("Conditional expression expected" );
		IExpression bodyStmt = stmtRange.takeFrontAs!IExpression("'If' directive body statement expected");

		ifSects ~= IfSect(condExpr, bodyStmt);

		while( !stmtRange.empty )
		{
			compiler.loger.write(`IfCompiler, stmtRange.front: `, stmtRange.front);
			INameExpression keywordExpr = stmtRange.takeFrontAs!INameExpression("'elif' or 'else' keyword expected");
			if( keywordExpr.name == "elif" )
			{
				condExpr = stmtRange.takeFrontAs!IExpression("'elif' conditional expression expected");
				bodyStmt = stmtRange.takeFrontAs!IExpression("'elif' body statement expected");

				ifSects ~= IfSect(condExpr, bodyStmt);
			}
			else if( keywordExpr.name == "else" )
			{
				elseBody = stmtRange.takeFrontAs!IExpression("'else' body statement expected");
				if( !stmtRange.empty )
					compiler.loger.error("'else' statement body expected to be the last 'if' attribute. Maybe ';' is missing");
				break;
			}
			else
			{
				compiler.loger.error("'elif' or 'else' keyword expected");
			}
		}

		// Array used to store instr indexes of jump instructions after each
		// if, elif block, used to jump to the end of directive after block
		// has been executed
		size_t[] jumpInstrIndexes;
		jumpInstrIndexes.length = ifSects.length;

		foreach( i, ifSect; ifSects )
		{
			ifSect.cond.accept(compiler);

			// Add conditional jump instruction
			// Remember address of jump instruction
			size_t jumpInstrIndex = compiler.addInstr(OpCode.JumpIfFalse);

			// Add `if body` code
			ifSect.stmt.accept(compiler);

			// Instruction to jump after the end of if directive when
			// current body finished
			jumpInstrIndexes[i] = compiler.addInstr(OpCode.Jump);

			// Getting address of instruction following after if body
			compiler.setInstrArg(jumpInstrIndex, compiler.getInstrCount());
		}

		if( elseBody )
		{
			// Compile elseBody
			elseBody.accept(compiler);
		}
		else
		{
			// It's fake elseBody used to push fake return value onto stack
			compiler.addInstr(OpCode.LoadConst, compiler.addConst( IvyData() ));
		}

		size_t afterEndInstrIndex = compiler.getInstrCount();
		compiler.addInstr(OpCode.Nop); // Need some fake to jump if it's end of code object

		foreach( currIndex; jumpInstrIndexes )
		{
			// Fill all generated jump instructions with address of instr after directive end
			compiler.setInstrArg(currIndex, afterEndInstrIndex);
		}

		if( !stmtRange.empty )
			compiler.loger.error(`Expected end of "if" directive. Maybe ';' is missing`);
	}
}