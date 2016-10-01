module ivy.directive_interpreters;

import ivy.interpreter, ivy.node, ivy.interpreter_data;

/// Creates default root controller, that could be extended by adding child controllers
RootHTMLInterpreter makeRootInterpreter()
{
	auto interp = new RootHTMLInterpreter();
	interp.addController( new StandardDirectivesController() );
	return interp;
}

/// Controller that provides acces to standard directives of template language
class StandardDirectivesController: IInterpretersController
{
private:
	IDirectiveInterpreter[string] _dirInterpreters;

public:
	this()
	{
		// Some hardcoding goes here
		_dirInterpreters["for"] = new ForInterpreter();
		_dirInterpreters["if"] = new IfInterpreter();
		_dirInterpreters["expr"] = new ExprInterpreter();
		_dirInterpreters["pass"] = new PassInterpreter();
		_dirInterpreters["var"] = new VarInterpreter();
		_dirInterpreters["set"] = new SetInterpreter();
		_dirInterpreters["text"] = new TextBlockInterpreter();
		_dirInterpreters["def"] = new DefInterpreter();
		_dirInterpreters["def.getAttr"] = new DefGetAttrInterpreter();
	}

	override {
		string[] directiveNames() @property
		{
			return _dirInterpreters.keys;
		}

		/*
		string[] directiveNamespaces() @property
		{
			return null;
		}
		*/

		void interpret(IDirectiveStatement statement, Interpreter interp)
		{
			auto dirInterp = _dirInterpreters.get( statement.name, null );
			if( dirInterp )
			{
				dirInterp.interpret( statement, interp );
			}
		}

		void _reindex() {}
	}

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
		
		IKeyValueAttribute inAttribute = stmtRange.takeFrontAs!IKeyValueAttribute("Expected 'in' attribute");
		
		if( inAttribute.name != "in" )
			interpretError( "Expected 'in' keyword" );
		
		IExpression aggregateExpr = cast(IExpression) inAttribute.value;

		if( !aggregateExpr )
			interpretError("Expected loop aggregate expression");
		
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

/// Storage and controller for inline directives
class InlineDirectivesController: ICompositeInterpretersController
{
	mixin BaseInterpretersControllerImpl;
}

alias TDataNode = DataNode!(string);
TDataNode[string] interpretNamedAttributes( IAttributeRange attrsRange, Interpreter interp )
{
	import std.range: empty;
	TDataNode[string] attrValues;

	while( !attrsRange.empty )
	{
		IKeyValueAttribute attr = cast(IKeyValueAttribute) attrsRange.front;
		if( !attr )
			break;

		if( attr.name.empty )
			interpretError( "Named attribute name cannot be empty!" );

		if( !attr.value )
			interpretError( "Attribute value AST node cannot be null!" );

		attrsRange.popFront();


		attr.value.accept( interp );

		attrValues[ attr.name ] = interp.opnd;
	}

	return attrValues;
}

class InlineDirectiveInterpreter: IDirectiveInterpreter
{
private:
	string _directiveName;
	IAttributesInterpreter[] _attrInterpreters;
	ICompoundStatement _bodyStatement;
	bool _withNewScope;


public:
	this( string dirName, IAttributesInterpreter[] interpreters, ICompoundStatement bodyStmt, bool withNewScope = false )
	{
		_directiveName = dirName;
		_attrInterpreters = interpreters;
		_bodyStatement = bodyStmt;
		_withNewScope = withNewScope;
	}

	string directiveName() @property
	{
		return _directiveName;
	}

	override void interpret(IDirectiveStatement statement, Interpreter interp)
	{
		import std.range: empty, back, front, popBack, popFront;

		if( !statement || statement.name != _directiveName )
		{
			interpretError( `Expected directive "` ~ _directiveName ~ `"` );
		}

		if( _withNewScope )
			interp.enterScope();
		scope(exit) {
			if( _withNewScope )
				interp.exitScope();
		}

		IAttributeRange attrRange = statement[];
		while( !_attrInterpreters.empty )
		{
			if( attrRange.empty )
			{
				interpretError( `Unexpected end of directive attibutes list for directive "` ~ _directiveName ~ `"` );
			}

			_attrInterpreters.front.processAttributes( attrRange, interp );
			_attrInterpreters.popFront();
		}

		if( !attrRange.empty )
		{
			interpretError( `Not all attributes of directive "` ~ _directiveName ~ `" were processed. Something is wrong!` );
		}

		_bodyStatement.accept(interp); // Running body of inline directive
	}

}

/// Basic interface for classes that store info about inline directive attribute definition
/// and can be used to interpret node of attribute in directive invocation syntax
interface IAttributesInterpreter
{
	void processAttributes( IAttributeRange attrRange, Interpreter interp );
}

class NamedAttributesInterpreter: IAttributesInterpreter
{
private:
	import std.typecons: Tuple;

	string[string] _attrDefs; // Mapping attribute name -> type string

public:
	this( string[string] attrDefs )
	{
		_attrDefs = attrDefs;
	}

	override void processAttributes( IAttributeRange attrRange, Interpreter interp )
	{
		if( !interp.canFindValue( "__attrs__" ) )
		{
			TDataNode[string] attrDict;
			interp.setValue( "__attrs__", TDataNode(attrDict) );
		}

		while( !attrRange.empty )
		{
			IKeyValueAttribute kwAttrExpr = cast(IKeyValueAttribute) attrRange.front;
			if( !kwAttrExpr )
				break; // Parse only named attributes or break

			if( kwAttrExpr.name !in _attrDefs )
				interpretError( `Unexpected named attribute "` ~ kwAttrExpr.name ~ `"` );

			if( !kwAttrExpr.value )
				interpretError( `Expression for named attribute "` ~ kwAttrExpr.name ~ `" must not be null!` );

			kwAttrExpr.value.accept(interp);

			TDataNode attrsNode;
			if( interp.canFindValue( "__attrs__" ) )
			{
				attrsNode = interp.getValue( "__attrs__" );
			}

			if( attrsNode.type != DataNodeType.AssocArray )
				interpretError( `Expected assoc array as attributes dictionary` );

			TDataNode[string] attrDict = attrsNode.assocArray;
			attrDict[kwAttrExpr.name] = interp.opnd;

			attrRange.popFront();
		}

	}

}

import std.stdio;
/// Defines directive using ivy language
class DefInterpreter: IDirectiveInterpreter
{
	override void interpret(IDirectiveStatement statement, Interpreter interp)
	{
		if( !statement || statement.name != "def"  )
			interpretError( "Expected 'def' directive" );

		auto stmtRange = statement[];
		INameExpression defNameExpr = stmtRange.takeFrontAs!INameExpression("Expected name for directive definition");
		IAttributesInterpreter[] attrInterps;
		ICompoundStatement bodyStatement;
		bool withNewScope = false;
		writeln("Start interpreting def directive...");

		while( !stmtRange.empty )
		{
			writeln("Interpreting attributes definitions blocks");
			ICodeBlockStatement attrDefBlockStmt = cast(ICodeBlockStatement) stmtRange.front;
			if( !attrDefBlockStmt )
			{
				break; // Expected to see some attribute declaration
			}

			IDirectiveStatementRange attrDefStmtRange = attrDefBlockStmt[];

			while( !attrDefStmtRange.empty )
			{
				writeln("Interpreting 1");
				IDirectiveStatement attrDefStmt = attrDefStmtRange.front;
				IAttributeRange attrDefStmtAttrRange = attrDefStmt[];

				switch( attrDefStmt.name )
				{
					case "def.kwAttr": {
						IAttributesInterpreter namedAttrsInterp = interpretNamedAttrsBlock(attrDefStmtAttrRange);
						if( namedAttrsInterp )
						{
							attrInterps ~= namedAttrsInterp;
						}
						break;
					}
					/*
					case "def.expr": {

						break;
					}
					case "def.name": {

						break;
					}
					case "def.kwd": {

						break;
					}
					*/
					case "def.newScope": {
						withNewScope = true; // Option to create new scope to store data for this directive
						break;
					}
					case "def.body": {
						if( bodyStatement )
							interpretError( "Multiple body statements are not allowed!!!" );

						if( attrDefStmtAttrRange.empty )
							interpretError( "Expected compound statement as directive body statement, but got end of attributes list!" );

						bodyStatement = cast(ICompoundStatement) attrDefStmtAttrRange.front; // Getting body AST for statement
						if( !bodyStatement )
							interpretError( "Expected compound statement as directive body statement" );
						break;
					}
					default: {
						interpretError( `Unexpected directive attribute definition statement "` ~ attrDefStmt.name ~ `"` );
						break;
					}
				}
				attrDefStmtRange.popFront(); // Going to the next directive statement in code block
			}
			stmtRange.popFront(); // Go to next attr definition directive
		}

		IDirectiveInterpreter inlDirInterp = new InlineDirectiveInterpreter( defNameExpr.name, attrInterps, bodyStatement, withNewScope );
		interp._inlineDirController.addInterpreter( defNameExpr.name, inlDirInterp );
		interp._dirController._reindex();
	}

	// Method parses attributes of "def.kwAttr" directive
	IAttributesInterpreter interpretNamedAttrsBlock(IAttributeRange attrRange)
	{
		writeln("Interpreting named attributes block");
		string[string] attrDefs;
		while( !attrRange.empty )
		{
			writeln("Interpreting named attributes block item");
			IKeyValueAttribute namedAttrDefExpr = cast(IKeyValueAttribute) attrRange.front;
			if( !namedAttrDefExpr )
			{
				writeln("namedAttrDefExpr expected, but got null, so break");
				break;
			}

			INameExpression attrTypeExpr = cast(INameExpression) namedAttrDefExpr.value;
			if( !attrTypeExpr )
				interpretError( `Expected attribute type expression!` );

			attrDefs[ namedAttrDefExpr.name ] = attrTypeExpr.name;
			attrRange.popFront();
		}

		if( attrDefs.length > 0 )
		{
			return new NamedAttributesInterpreter(attrDefs);
		}
		return null;
	}
}


class DefGetAttrInterpreter: IDirectiveInterpreter
{
	override void interpret(IDirectiveStatement statement, Interpreter interp)
	{
		import std.range: empty, back;
		if( !statement || statement.name != "def.getAttr"  )
			interpretError( "Expected 'def.getAttr' directive" );

		auto stmtRange = statement[];

		INameExpression attrNameExpr = stmtRange.takeFrontAs!INameExpression("Expected name of directive attribute");

		TDataNode attrsNode;
		if( interp.canFindValue("__attrs__") )
		{
			attrsNode = interp.getValue( attrNameExpr.name );
		}

		if( attrsNode.type != DataNodeType.AssocArray )
			interpretError( "Cannot get attrubute value, attributes node is not assoc array!" );

		TDataNode[string] attrDict = attrsNode.assocArray;
		if( attrNameExpr.name !in attrDict )
		{
			interp.opnd = TDataNode(null); // Issue an error or return null?
		}
		else
		{
			interp.opnd = attrDict[attrNameExpr.name];
		}

		if( !stmtRange.empty )
			interpretError( "Something is going wrong, expected end of attributes list!" );
	}
}



/*
/// Attaches defined symbols from another ivy template file
class ImportInterpreter: IDirectiveInterpreter
{


}
*/

/*
/// Used to inject another template file directly in current AST
class MixinInterpreter: IDirectiveInterpreter
{


}
*/
