module ivy.compiler.directive.def;

import ivy.compiler.directive.utils;

static immutable string[] ATTR_KEYWORDS = [
	"var",
	"def.kv",
	"def.pos"
];

/// Defines directive using ivy language
class DefCompiler: IDirectiveCompiler
{
	import ivy.compiler.symbol_table: SymbolTableFrame;

	import ivy.types.symbol.iface: IIvySymbol;
	import ivy.types.symbol.directive: DirectiveSymbol;
	import ivy.types.symbol.dir_attr: DirAttr;
	import ivy.types.symbol.dir_body_attrs: DirBodyAttrs;

	import ivy.ast.iface:
		IExpression,
		ICompoundStatement,
		IAttributeRange,
		INameExpression,
		ICodeBlockStatement,
		IDirectiveStatementRange,
		IKeyValueAttribute,
		ILiteralExpression;

public:
	static struct CompilerDirAttr
	{
		DirAttr attr;
		IExpression defaultValueExpr;
	}

	static struct CompilerDirBodyAttrs
	{
		DirBodyAttrs attr;
		ICompoundStatement statement;
	}

	override void collect(IDirectiveStatement stmt, CompilerSymbolsCollector collector)
	{
		import std.algorithm: canFind;
		import std.range: empty, back, popBack;

		IAttributeRange defAttrsRange = stmt[];

		INameExpression dirNameExpr = defAttrsRange.takeFrontAs!INameExpression("Expected directive name");
		ICodeBlockStatement defBlockStmt = defAttrsRange.takeFrontAs!ICodeBlockStatement("Expected code block as directive attributes definition");
		IDirectiveStatementRange defStmtRange = defBlockStmt[];

		collector.log.write(`collect: `, stmt.name, `, `, dirNameExpr.name);

		if( defStmtRange.empty )
			collector.log.error("Expected directive params or body, but got end of input");

		DirAttr[] attrs;
		IDirectiveStatement attrsStmt = defStmtRange.front; // Current attributes definition statement
		if( ATTR_KEYWORDS.canFind(attrsStmt.name)  )
		{
			IAttributeRange attrsStmtRange = attrsStmt[]; // Range of attribute definitions
			while( !attrsStmtRange.empty )
			{
				attrs ~= _analyzeValueAttr(attrsStmtRange, collector).attr;
			}
			defStmtRange.popFront(); // Consume def.kv/ def.pos statement
		}

		if( defStmtRange.empty )
			collector.log.error("Expected directive body, but got end of input");

		{
			CompilerDirBodyAttrs res = _analyzeDirBody(defStmtRange.front, collector);
			defStmtRange.popFront();

			if( collector._frameStack.empty )
				collector.log.error(`Symbol table frame stack is empty`);

			SymbolTableFrame oldScope = collector._frameStack.back;
			collector.log.write(`oldScope: `, oldScope.toPrettyStr());

			// Add directive definition into existing frame
			DirectiveSymbol symb = new DirectiveSymbol(dirNameExpr.name, stmt.location, attrs, res.attr);

			if( !res.attr.isNoscope )
			{
				// Create new frame for body if not forbidden
				collector._frameStack ~= oldScope.newChildFrame(symb);
			} else {
				oldScope.add(symb);
			}

			scope(exit)
			{
				if( !res.attr.isNoscope ) {
					collector.exitScope();
				}
			}

			// Analyse nested tree
			res.statement.accept(collector);
		}

		if( !defStmtRange.empty )
			collector.log.error(`No extra def statements expected so far`);

		if( !defAttrsRange.empty )
			collector.log.error(`Expected end of directive definition statement. Maybe ; is missing`);
	}


	override void compile(IDirectiveStatement stmt, ByteCodeCompiler compiler)
	{
		import ivy.types.call_spec: CallSpec;

		import std.algorithm: canFind;

		IAttributeRange defAttrsRange = stmt[];

		INameExpression dirNameExpr = defAttrsRange.takeFrontAs!INameExpression("Expected directive name");
		ICodeBlockStatement defBlockStmt = defAttrsRange.takeFrontAs!ICodeBlockStatement("Expected code block as directive attributes definition");
		IDirectiveStatementRange defStmtRange = defBlockStmt[];

		if( defStmtRange.empty )
			compiler.log.error("Expected directive params or body, but got end of input");

		IDirectiveStatement attrsStmt = defStmtRange.front; // Current attributes definition statement

		size_t defValCount = 0;
		if( ATTR_KEYWORDS.canFind(attrsStmt.name)  )
		{
			IAttributeRange attrsStmtRange = attrsStmt[]; // Range of attribute definitions

			while( !attrsStmtRange.empty )
			{
				CompilerDirAttr res = _analyzeValueAttr(attrsStmtRange, compiler);

				if( res.defaultValueExpr )
				{
					compiler.addInstr(OpCode.LoadConst, compiler.addConst( IvyData(res.attr.name) ));

					res.defaultValueExpr.accept(compiler);
					++defValCount; // Increase default values counter
				}
			}
			defStmtRange.popFront(); // Consume def.kv/ def.pos statement

			// If there are attributes with defaults then create assoc array of them
			if( defValCount > 0 )
				compiler.addInstr(OpCode.MakeAssocArray, defValCount);
		}

		if( defStmtRange.empty )
			compiler.log.error("Expected directive body, but got end of input");

		{
			CompilerDirBodyAttrs res = _analyzeDirBody(defStmtRange.front, compiler);
			defStmtRange.popFront();

			DirectiveSymbol dirSymbol = cast(DirectiveSymbol) compiler.symbolLookup(dirNameExpr.name);
			if( dirSymbol is null )
				compiler.log.error(`Expected directive definition symbol kind`);

			size_t codeObjIndex;
			// Compilation of CodeObject itself
			{
				if( !res.attr.isNoscope )
				{
					// Compiler should enter frame of directive body, identified by index in source code
					compiler._symbolsCollector.enterScope(stmt.location);
				}

				scope(exit)
				{
					if( !res.attr.isNoscope ) {
						compiler._symbolsCollector.exitScope();
					}
				}

				codeObjIndex = compiler.enterNewCodeObject(dirSymbol); // Creating code object
				scope(exit) compiler.exitCodeObject();

				// Generating code for body
				res.statement.accept(compiler);
			}

			// Add instruction to load code object from module constants
			compiler.addInstr(OpCode.LoadConst, codeObjIndex);

			// Add instruction to create directive object
			compiler.addInstr(OpCode.MakeCallable, CallSpec(0, defValCount > 0).encode());

			// Save callable in scope by name
			compiler.addInstr(OpCode.StoreName, compiler.addConst( IvyData(dirSymbol.name) ));

			// For now we expect that directive should return some value on the stack
			compiler.addInstr(OpCode.LoadConst, compiler.addConst( IvyData() ));
		}
	}

	CompilerDirAttr _analyzeValueAttr(Compiler)(IAttributeRange attrRange, Compiler compiler)
	{
		import ivy.ast.consts: LiteralType;

		CompilerDirAttr res;
		if( IKeyValueAttribute kwPair = cast(IKeyValueAttribute) attrRange.front )
		{
			res.attr.name = kwPair.name;
			res.defaultValueExpr = cast(IExpression) kwPair.value;
			if( !res.defaultValueExpr )
				compiler.log.error(`Expected attribute default value expression!`);
		}
		else if( INameExpression nameExpr = cast(INameExpression) attrRange.front )
		{
			res.attr.name = nameExpr.name;
		}
		else
		{
			compiler.log.error(`Expected [name] or [key: value] expression as attribute definition`);
		}

		attrRange.popFront(); // Skip attribute

		if( !attrRange.empty )
		{
			// Try to parse optional type definition
			if( INameExpression asKwdExpr = cast(INameExpression) attrRange.front )
			{
				if( asKwdExpr.name == "as" )
				{
					// TODO: Try to find out type of attribute after `as` keyword
					// Assuming that there will be no named attribute with name `as` in programme
					attrRange.popFront(); // Skip `as` keyword

					if( attrRange.empty )
						compiler.log.error(`Expected attr type definition, but got end of attrs range!`);

					ILiteralExpression attrTypeExpr = cast(ILiteralExpression) attrRange.front;
					if( attrTypeExpr is null || attrTypeExpr.literalType != LiteralType.String )
						compiler.log.error(`Expected string literal as attr type definition!`);

					res.attr.typeName = attrTypeExpr.toStr(); // Getting type of attribute as string (for now)

					attrRange.popFront(); // Skip type expression
				}
			}
		}

		return res;
	}


	CompilerDirBodyAttrs _analyzeDirBody(Compiler)(IDirectiveStatement bodyDefStmt, Compiler compiler)
	{
		import std.algorithm: canFind;

		CompilerDirBodyAttrs res;

		if( !["def.body", "do"].canFind(bodyDefStmt.name) )
			compiler.log.error(`Expected directive body, but got:`, bodyDefStmt.name);

		IAttributeRange bodyStmtRange = bodyDefStmt[]; // Range on attributes of attributes definition statement

		// Try to parse noscope and noescape flags
		body_flags_loop:
		while( !bodyStmtRange.empty )
		{
			INameExpression flagExpr = cast(INameExpression) bodyStmtRange.front;
			if( flagExpr is null ) {
				break;
			}
			bodyStmtRange.popFront();
			switch( flagExpr.name )
			{
				case "noscope": res.attr.isNoscope = true; break;
				case "noescape": res.attr.isNoescape = true; break;
				default:
					compiler.log.error("Unexpected directive body flag: ", flagExpr.name);
			}
		}

		if( bodyStmtRange.empty )
			compiler.log.error("Unexpected end of def.body directive!");

		// Getting body AST for statement just for check if it is there
		res.statement = cast(ICompoundStatement) bodyStmtRange.front;
		if( !res.statement )
			compiler.log.error("Expected compound statement as directive body statement");

		bodyStmtRange.popFront(); // Need to consume body statement to behave correctly

		if( !bodyStmtRange.empty )
			compiler.log.error("Expected end of directive body definition");

		return res;
	}
}