module ivy.directive_interpreters;

import ivy.interpreter, ivy.node, ivy.interpreter_data;

/+
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
+/

/+
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
		auto attrInterpRange = _attrInterpreters[];
		while( !attrInterpRange.empty )
		{
			if( attrRange.empty )
			{
				// Maybe it's OK that there is no more:)
				break;
				//interpretError( `Unexpected end of directive attibutes list for directive "` ~ _directiveName ~ `"` );
			}

			attrInterpRange.front.processAttributes( attrRange, interp );
			attrInterpRange.popFront();
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

struct NamedAttrDefinition
{
	string name;
	string typeString;
	IExpression defaultValueExpr;
}

class NamedAttributesInterpreter: IAttributesInterpreter
{
private:
	NamedAttrDefinition[string] _attrDefs;

public:
	this( NamedAttrDefinition[string] attrDefs )
	{
		_attrDefs = attrDefs;
	}

	override void processAttributes( IAttributeRange attrRange, Interpreter interp )
	{
		if( !interp.canFindValue( "__attrs__" ) )
		{
			TDataNode[string] attrDict;
			interp.setLocalValue( "__attrs__", TDataNode(attrDict) );
		}

		TDataNode attrsNode = interp.getValue( "__attrs__" );
		if( attrsNode.type != DataNodeType.AssocArray )
			interpretError( `Expected assoc array as attributes dictionary` );

		foreach( name, attrDef; _attrDefs )
		{
			if( !attrDef.defaultValueExpr )
				continue;

			attrDef.defaultValueExpr.accept(interp);
			attrsNode[name] = interp.opnd;
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
			attrsNode[kwAttrExpr.name] = interp.opnd;

			attrRange.popFront();
		}

		interp.setValue( "__attrs__", attrsNode );
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

		while( !stmtRange.empty )
		{
			ICodeBlockStatement attrDefBlockStmt = cast(ICodeBlockStatement) stmtRange.front;
			if( !attrDefBlockStmt )
			{
				break; // Expected to see some attribute declaration
			}

			IDirectiveStatementRange attrDefStmtRange = attrDefBlockStmt[];

			while( !attrDefStmtRange.empty )
			{
				IDirectiveStatement attrDefStmt = attrDefStmtRange.front;
				IAttributeRange attrDefStmtAttrRange = attrDefStmt[];

				switch( attrDefStmt.name )
				{
					case "def.named": {
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
					case "def.ident": {

						break;
					}
					case "def.kwd": {

						break;
					}
					case "def.result": {

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

	// Method parses attributes of "def.named" directive
	IAttributesInterpreter interpretNamedAttrsBlock(IAttributeRange attrRange)
	{
		writeln("Interpreting named attributes block");
		NamedAttrDefinition[string] attrDefs;
		while( !attrRange.empty )
		{
			writeln("Interpreting named attributes block item");
			string attrName;
			string attrType;
			IExpression defaultValueExpr;

			if( auto kwPair = cast(IKeyValueAttribute) attrRange.front )
			{
				attrName = kwPair.name;
				defaultValueExpr = cast(IExpression) kwPair.value;
				if( !defaultValueExpr )
					interpretError( `Expected attribute default value expression!` );

				attrRange.popFront(); // Skip named attribute
			}
			else if( auto nameExpr = cast(INameExpression) attrRange.front )
			{
				attrName = nameExpr.name;
				attrRange.popFront(); // Skip variable name
			}
			else
			{
				// Just get out of there
				writeln("namedAttrDefExpr expected, but got null, so break");
				break;
			}

			if( !attrRange.empty )
			{
				// Try to parse optional type definition
				if( auto asKwdExpr = cast(INameExpression) attrRange.front )
				{
					if( asKwdExpr.name == "as" )
					{
						// TODO: Try to find out type of attribute after `as` keyword
						// Assuming that there will be no named attribute with name `as` in programme
						attrRange.popFront(); // Skip `as` keyword

						if( attrRange.empty )
							interpretError( `Expected attr type definition, but got end of attrs range!` );

						auto attrTypeExpr = cast(INameExpression) attrRange.front;
						if( !attrTypeExpr )
							interpretError( `Expected attr type definition!` );

						attrType = attrTypeExpr.name; // Getting type of attribute as string (for now)

						attrRange.popFront(); // Skip type expression
					}
				}
			}

			attrDefs[ attrName ] = NamedAttrDefinition( attrName, attrType, defaultValueExpr );
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
			attrsNode = interp.getValue( "__attrs__" );
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

/// Attaches defined symbols from another ivy template file
class ImportInterpreter: IDirectiveInterpreter
{
private:
	string _importPath = "test/";
	string _moduleExt = ".html";

public:
	override void interpret(IDirectiveStatement statement, Interpreter interp)
	{
		if( !statement || statement.name != "import"  )
			interpretError( "Expected 'import' directive" );

		auto stmtRange = statement[];

		INameExpression moduleNameExpr = stmtRange.takeFrontAs!INameExpression("Expected module name for import");

		import std.algorithm: splitter;
		import std.string: join;

		string modulePath = moduleNameExpr.name.splitter('.').join('/');

		IvyModule mod = interp._ivyRepository.getModule( _importPath ~ modulePath ~ _moduleExt );
		mod.doImport( interp );

		if( !stmtRange.empty )
			interpretError( `Not all attributes for directive "import" were parsed. Maybe ; is missing somewhere` );
	}

}
+/


/*
/// Used to inject another template file directly in current AST
class MixinInterpreter: IDirectiveInterpreter
{


}
*/