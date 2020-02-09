module ivy.compiler.directive.def;

import ivy.compiler.directive.utils;

import ivy.directive_stuff: DirAttrKind, _stackBlockHeaderSizeOffset;
import ivy.ast.iface: INameExpression, ICompoundStatement, ICodeBlockStatement, IDirectiveStatementRange, IAttributeRange;
import ivy.compiler.symbol_table: Symbol, SymbolKind, DirectiveDefinitionSymbol;

/// Defines directive using ivy language
class DefCompiler: IDirectiveCompiler
{
	override void compile(IDirectiveStatement statement, ByteCodeCompiler compiler)
	{
		auto stmtRange = statement[];
		INameExpression defNameExpr = stmtRange.takeFrontAs!INameExpression("Expected name for directive definition");
		compiler.loger.internalAssert(defNameExpr.name.length > 0, `Directive definition name shouldn't be empty!`);

		ICompoundStatement bodyStatement;
		size_t stackItemsCount = 2; // CodeObject and it's name counted

		while( !stmtRange.empty )
		{
			ICodeBlockStatement attrsDefBlockStmt = cast(ICodeBlockStatement) stmtRange.front;
			if( !attrsDefBlockStmt ) {
				break; // Expected to see some attribute declaration
			}

			IDirectiveStatementRange attrsDefStmtRange = attrsDefBlockStmt[];

			while( !attrsDefStmtRange.empty )
			{
				IDirectiveStatement attrDefStmt = attrsDefStmtRange.front;
				IAttributeRange attrsDefStmtAttrRange = attrDefStmt[];

				switch( attrDefStmt.name )
				{
					case "def.kv": {
						size_t argCount = 0;
						while( !attrsDefStmtAttrRange.empty )
						{
							auto res = compiler.analyzeValueAttr(attrsDefStmtAttrRange);
							compiler.loger.internalAssert(res.isSet, `Check 3`);

							if( res.defaultValueExpr )
							{
								compiler.addInstr( OpCode.LoadConst, compiler.addConst(IvyData(res.attr.name)) );
								++stackItemsCount;

								res.defaultValueExpr.accept(compiler);
								++stackItemsCount;

								++argCount; // Increase default value pairs counter
							}
						}

						// Add instruction to load value that consists of number of pairs in block and type of block
						size_t blockHeader = ( argCount << _stackBlockHeaderSizeOffset ) + DirAttrKind.NamedAttr;
						compiler.addInstr(OpCode.LoadConst, compiler.addConst( IvyData(blockHeader) ));
						++stackItemsCount; // We should count args block header
						break;
					}
					case "def.pos": {
						size_t argCount = 0;
						while( !attrsDefStmtAttrRange.empty )
						{
							auto res = compiler.analyzeValueAttr(attrsDefStmtAttrRange);
							compiler.loger.internalAssert(res.isSet, `Check 4`);

							if( res.defaultValueExpr ) {
								res.defaultValueExpr.accept(compiler);
								++stackItemsCount;
								++argCount; // Increase default values counter
							}
						}

						// Add instruction to load value that consists of number of positional arguments in block and type of block
						size_t blockHeader = ( argCount << _stackBlockHeaderSizeOffset ) + DirAttrKind.ExprAttr;
						compiler.addInstr(OpCode.LoadConst, compiler.addConst( IvyData(blockHeader) ));
						++stackItemsCount; // We should count args block header
						break;
					}
					case "def.names": case "def.kwd": {
						compiler.loger.error(`Not implemented yet!`);
						break;
					}
					case "def.body": {
						if( bodyStatement )
							compiler.loger.error("Multiple body statements are not allowed!!!");

						auto res = compiler.analyzeDirBody(attrsDefStmtAttrRange);
						bodyStatement = res.statement;

						Symbol symb = compiler.symbolLookup(defNameExpr.name);
						if( symb.kind != SymbolKind.DirectiveDefinition )
							compiler.loger.error(`Expected directive definition symbol kind`);

						DirectiveDefinitionSymbol dirSymbol = cast(DirectiveDefinitionSymbol) symb;
						compiler.loger.internalAssert(dirSymbol, `Directive definition symbol is null`);

						size_t codeObjIndex;
						// Compilation of CodeObject itself
						{
							if( !res.attr.isNoscope )
							{
								// Compiler should enter frame of directive body, identified by index in source code
								compiler._symbolsCollector.enterScope(bodyStatement.location.index);
							}

							scope(exit)
							{
								if( !res.attr.isNoscope ) {
									compiler._symbolsCollector.exitScope();
								}
							}


							codeObjIndex = compiler.enterNewCodeObject(defNameExpr.name); // Creating code object
							scope(exit) compiler.exitCodeObject();

							// Generating code for def.body
							bodyStatement.accept(compiler);

							// Add directive metainfo
							compiler.currentCodeObject._attrBlocks = dirSymbol.dirAttrBlocks;
						}

						// Add instruction to load code object from module constants
						compiler.addInstr(OpCode.LoadConst, codeObjIndex);

						// Add instruction to load directive name from consts
						compiler.addInstr(OpCode.LoadConst, compiler.addConst( IvyData(defNameExpr.name) ));

						// Add instruction to create directive object
						compiler.addInstr(OpCode.LoadDirective, stackItemsCount);
						break;
					}
					default: {
						compiler.loger.error(`Unexpected directive attribute definition statement "` ~ attrDefStmt.name ~ `"`);
						break;
					}
				}
				attrsDefStmtRange.popFront(); // Going to the next directive statement in code block
			}
			stmtRange.popFront(); // Go to next attr definition directive
		}

		// Check wheter dir body was found at all
		compiler.loger.internalAssert(bodyStatement, `Directive definition body is null`);
	}
}