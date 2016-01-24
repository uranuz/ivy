module declarative.directive_interpreters;

import declarative.interpreter, declarative.node, declarative.interpreter_data;

shared static this()
{
	dirInterpreters["for"] = new ForInterpreter();
	dirInterpreters["if"] = new IfInterpreter();
	dirInterpreters["expr"] = new ExprInterpreter();
	dirInterpreters["pass"] = new PassInterpreter();
	dirInterpreters["var"] = new VarInterpreter();
	dirInterpreters["set"] = new SetInterpreter();
	dirInterpreters["text"] = new TextBlockInterpreter();
}

class ForInterpreter : IDirectiveInterpreter
{
public:
	override void interpret(IDirectiveStatement statement, Interpreter interp)
	{
		if( !statement || statement.name != "for"  )
			interpretError( "Expected 'for' directive" );
		
		auto stmtRange = statement[];

		INameExpression varNameExpr = stmtRange.takeFrontAs!INameExpression("For loop variable name expected");
		
		string varName = varNameExpr.name;
		if( varName.length == 0 )
			interpretError("Loop variable name cannot be empty");
		
		INameExpression inNameExpr = stmtRange.takeFrontAs!INameExpression("Expected 'in' keyword");
		
		if( inNameExpr.name != "in" )
			interpretError( "Expected 'in' keyword" );
		
		IExpression aggregateExpr = stmtRange.takeFrontAs!IExpression("Expected loop aggregate expression");
		
		aggregateExpr.accept(interp);
		auto aggr = interp.opnd;
		
		if( aggr.type != DataNodeType.Array ) 
			interpretError( "Aggregate type must be array" );

		ICompoundStatement bodyStmt = stmtRange.takeFrontAs!ICompoundStatement( "Expected loop body statement" );

		if( !stmtRange.empty )
			interpretError( "Expected end of directive after loop body. Maybe ';' is missing" );

		TDataNode[] results;
		
		if( interp.canFindValue(varName) )
				interpretError( "For loop variable name '" ~ varName ~ "' already exists" );
		
		foreach( aggrItem; aggr.array )
		{
			interp.setValue(varName, aggrItem);
			bodyStmt.accept(interp);
			results ~= interp.opnd;
		}
		
		interp.removeLocalValue(varName);
		
		//Location bodyStmtLoc = bodyStmt.location;
		//size_t bodyFirstIndent = bodyStmtLoc.firstIndent;
		//IndentStyle bodyFirstIndentStyle = bodyStmtLoc.firstIndentStyle;
		
		
		interp.opnd = results;
	}

}

class IfInterpreter : IDirectiveInterpreter
{
public:
	override void interpret(IDirectiveStatement statement, Interpreter interp)
	{
		if( !statement || statement.name != "if"  )
			interpretError( "Expected 'if' directive" );
		
		import std.typecons: Tuple;
		import std.range: back, empty;
		alias IfSect = Tuple!(IExpression, "cond", IStatement, "stmt");
		
		IfSect[] ifSects;
		IStatement elseBody;
		
		auto stmtRange = statement[];
		
		IExpression condExpr = stmtRange.takeFrontAs!IExpression( "Conditional expression expected" );
		IStatement bodyStmt = stmtRange.takeFrontAs!IStatement( "'If' directive body statement expected" );
		
		ifSects ~= IfSect(condExpr, bodyStmt);
		
		while( !stmtRange.empty )
		{
			INameExpression keywordExpr = stmtRange.takeFrontAs!INameExpression("'elif' or 'else' keyword expected");
			if( keywordExpr.name == "elif" )
			{
				condExpr = stmtRange.takeFrontAs!IExpression( "'elif' conditional expression expected" );
				bodyStmt = stmtRange.takeFrontAs!IStatement( "'elif' body statement expected" );
				
				ifSects ~= IfSect(condExpr, bodyStmt);
			}
			else if( keywordExpr.name == "else" )
			{
				elseBody = stmtRange.takeFrontAs!IStatement( "'else' body statement expected" );
				if( !stmtRange.empty )
					interpretError("'else' statement body expected to be the last 'if' attribute. Maybe ';' is missing");
				break;
			}
			else
			{
				interpretError("'elif' or 'else' keyword expected");
			}
		}
		
		bool lookElse = true;
		interp.opnd = false;
		
		foreach( i, ifSect; ifSects )
		{
			
			ifSect.cond.accept(interp);
			
			auto cond = interp.opnd;
			
			bool boolCond = cond.boolean;
			
			if( cond.type != DataNodeType.Boolean )
				interpretError( "Conditional expression type must be boolean" );
				
			if( cond.boolean )
			{
				lookElse = false;
				ifSect.stmt.accept(interp);
				
				import std.array: appender;
				
				auto opndText = appender!string();
				
				writeDataNodeAsString(interp.opnd, opndText);

				break;
			}
		}
		
		if( lookElse && elseBody )
		{
			elseBody.accept(interp);
		}
	}
}

class PassInterpreter : IDirectiveInterpreter
{
public:
	override void interpret(IDirectiveStatement statement, Interpreter interp)
	{
		interp.opnd = TDataNode.init;
	}

}

class ExprInterpreter : IDirectiveInterpreter
{
public:
	override void interpret(IDirectiveStatement statement, Interpreter interp)
	{
		if( !statement || statement.name != "expr"  )
			interpretError( "Expected 'expr' directive" );
		
		auto stmtRange = statement[];
		
		IExpression expr = stmtRange.takeFrontAs!IExpression("Expression expected");

		expr.accept(interp);
	}

}

class SetInterpreter : IDirectiveInterpreter
{
public:
	override void interpret(IDirectiveStatement statement, Interpreter interp)
	{
		if( !statement || statement.name != "set"  )
			interpretError( "Expected 'set' directive" );
		
		auto stmtRange = statement[];
		
		IKeyValueAttribute kwPair = stmtRange.takeFrontAs!IKeyValueAttribute("Key-value pair expected");
		
		if( !stmtRange.empty )
			interpretError( "Expected end of directive after key-value pair. Maybe ';' is missing" );
		
		if( !interp.canFindValue( kwPair.name ) )
			interpretError( "Undefined identifier '" ~ kwPair.name ~ "'" );
		
		if( !kwPair.value )
			interpretError( "Expected value for 'set' directive" );
		
		kwPair.value.accept(interp); //Evaluating expression
		interp.setValue(kwPair.name, interp.opnd);
		
		interp.opnd = TDataNode.init; //Doesn't return value
	}

}

class VarInterpreter : IDirectiveInterpreter
{
public:
	override void interpret(IDirectiveStatement statement, Interpreter interp)
	{
		if( !statement || statement.name != "var"  )
			interpretError( "Expected 'var' directive" );

		auto stmtRange = statement[];
		
		IKeyValueAttribute kwPair = stmtRange.takeFrontAs!IKeyValueAttribute("Key-value pair expected");
		
		if( !stmtRange.empty )
			interpretError( "Expected end of directive after key-value pair. Maybe ';' is missing" );
		
		if( kwPair.name.length > 0 )
		
		if( !kwPair.value )
			interpretError( "Expected value for 'var' directive" );
		
		kwPair.value.accept(interp); //Evaluating expression
		interp.setValue(kwPair.name, interp.opnd);
		
		interp.opnd = TDataNode.init; //Doesn't return value
	}

}




class TextBlockInterpreter: IDirectiveInterpreter
{
public:
	override void interpret(IDirectiveStatement statement, Interpreter interp)
	{
		if( !statement || statement.name != "text"  )
			interpretError( "Expected 'var' directive" );
			
		auto stmtRange = statement[];
		
		if( stmtRange.empty )
			throw new ASTNodeTypeException("Expected compound statement or expression, but got end of directive");
			
		interp.opnd = TDataNode.init;
		
		if( auto expr = cast(IExpression) stmtRange.front )
		{
			expr.accept(interp);
		}
		else if( auto block = cast(ICompoundStatement) stmtRange.front )
		{
			block.accept(interp);
		}
		else
			new ASTNodeTypeException("Expected compound statement or expression");
		
		stmtRange.popFront(); //Skip attribute of directive
		
		if( !stmtRange.empty )
			interpretError("Expected only one attribute in 'text' directive");
		
		import std.array: appender;

		auto result = appender!string();
		
		writeDataNodeLines( interp.opnd, result, 15 );
		
		string dat = result.data;

		interp.opnd = result.data;
	}

}