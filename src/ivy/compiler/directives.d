module ivy.compiler.directives;

import ivy.bytecode: OpCode, Instruction;
import ivy.parser.node;
import ivy.parser.statement;
import ivy.parser.expression;
import ivy.compiler.compiler: IDirectiveCompiler, ByteCodeCompiler, takeFrontAs;
import ivy.compiler.symbol_table: Symbol, SymbolKind, DirectiveDefinitionSymbol;
import ivy.interpreter.data_node: DataNode;

alias TDataNode = DataNode!string;

/++
	`Var` directive is defined as list of elements. Each of them could be of following forms:
	- Just name of new variable without any value or type (default value will be set, type is `any`)
		{=var a}
	- Name with initializer value (type is `any`)
		{=var a: "Example"}
	- Name with type but without any value (`as` context keyword is used to describe type)
		{=var a as str}
	- Name with initializer and type
		{=var a: "Example" as str}

	Multiple variables could be defined using one `var` directive
	{=var
		a
		b: "Example"
		c as str
		d: "Example2" as str
	}
+/
class VarCompiler: IDirectiveCompiler
{
public:
	override void compile(IDirectiveStatement stmt, ByteCodeCompiler compiler)
	{
		import std.range: empty, back, empty;

		auto stmtRange = stmt[];
		while( !stmtRange.empty )
		{
			size_t varNameConstIndex;
			if( auto kwPair = cast(IKeyValueAttribute) stmtRange.front )
			{
				if( kwPair.name.empty )
					compiler.loger.error(`Variable name cannot be empty`);
				varNameConstIndex = compiler.addConst( TDataNode(kwPair.name) );

				if( !kwPair.value )
					compiler.loger.error("Expected value for 'var' directive");

				kwPair.value.accept(compiler); // Compile expression for getting value
				stmtRange.popFront();
			}
			else if( auto nameExpr = cast(INameExpression) stmtRange.front )
			{
				if( nameExpr.name.empty )
					compiler.loger.error(`Variable name cannot be empty`);
				varNameConstIndex = compiler.addConst( TDataNode(nameExpr.name) );

				stmtRange.popFront();
			}
			else
			{
				compiler.loger.error(`Expected named attribute or name as variable declarator!`);
			}

			if( !stmtRange.empty )
			{
				if( auto asKwdExpr = cast(INameExpression) stmtRange.front )
				{
					if( asKwdExpr.name == "as" )
					{
						// TODO: Try to find out type of variable after `as` keyword
						// Assuming that there will be no variable with name `as` in programme
						stmtRange.popFront(); // Skip `as` keyword

						if( stmtRange.empty )
							compiler.loger.error(`Expected variable type declaration`);

						// For now just skip type expression
						stmtRange.popFront();
					}
				}
			}

			compiler.addInstr(OpCode.StoreLocalName, varNameConstIndex);
		}

		// For now we expect that directive should return some value on the stack
		compiler.addInstr(OpCode.LoadConst, compiler.addConst( TDataNode() ));

		if( !stmtRange.empty )
			compiler.loger.error("Expected end of directive after key-value pair. Maybe ';' is missing");
	}
}

/++
	`Set` directive is used to set values of existing variables in context.
	It is defined as list of named attributes where key is variable name
	and attr value is new value for variable in context. Example:
	{# set a: "Example" #}

	Multiple variables could be set using one `set` directive
	{# set
			a: "Example"
			b: 10
			c: { s: 10, k: "Example2" }
	#}
+/
class SetCompiler : IDirectiveCompiler
{
public:
	override void compile(IDirectiveStatement statement, ByteCodeCompiler compiler)
	{
		auto stmtRange = statement[];

		while( !stmtRange.empty )
		{
			IKeyValueAttribute kwPair = stmtRange.takeFrontAs!IKeyValueAttribute("Key-value pair expected");

			if( !kwPair.value )
				compiler.loger.error("Expected value for 'set' directive");

			kwPair.value.accept(compiler); //Evaluating expression

			compiler.addInstr(OpCode.StoreName, compiler.addConst( TDataNode(kwPair.name) ));
		}

		// For now we expect that directive should return some value on the stack
		compiler.addInstr(OpCode.LoadConst, compiler.addConst( TDataNode() ));

		if( !stmtRange.empty )
			compiler.loger.error("Expected end of directive after key-value pair. Maybe ';' is missing");
	}

}

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
			compiler.addInstr(OpCode.LoadConst, compiler.addConst( TDataNode() ));
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


class ForCompiler : IDirectiveCompiler
{
public:
	override void compile(IDirectiveStatement statement, ByteCodeCompiler compiler)
	{
		auto stmtRange = statement[];
		INameExpression varNameExpr = stmtRange.takeFrontAs!INameExpression("For loop variable name expected");

		string varName = varNameExpr.name;
		if( varName.length == 0 )
			compiler.loger.error("Loop variable name cannot be empty");

		INameExpression inAttribute = stmtRange.takeFrontAs!INameExpression("Expected 'in' attribute");

		if( inAttribute.name != "in" )
			compiler.loger.error("Expected 'in' keyword");

		IExpression aggregateExpr = stmtRange.takeFrontAs!IExpression("Expected 'for' aggregate expression");
		ICompoundStatement bodyStmt = stmtRange.takeFrontAs!ICompoundStatement("Expected loop body statement");

		if( !stmtRange.empty )
			compiler.loger.error("Expected end of directive after loop body. Maybe ';' is missing");

		// TODO: Check somehow if aggregate has supported type

		// Compile code to calculate aggregate value
		aggregateExpr.accept(compiler);

		// Issue instruction to get iterator from aggregate in execution stack
		compiler.addInstr( OpCode.GetDataRange );

		size_t loopStartInstrIndex = compiler.addInstr(OpCode.RunLoop);

		// Issue command to store current loop item in local context with specified name
		compiler.addInstr(OpCode.StoreLocalName, compiler.addConst( TDataNode(varName) ));

		bodyStmt.accept(compiler);

		// Drop result that we don't care about in this loop type
		compiler.addInstr(OpCode.PopTop);

		size_t loopEndInstrIndex = compiler.addInstr(OpCode.Jump, loopStartInstrIndex);
		compiler.setInstrArg(loopStartInstrIndex, loopEndInstrIndex);

		// Push fake result to "make all happy" ;)
		compiler.addInstr(OpCode.LoadConst, compiler.addConst( TDataNode() ));
	}
}

class AtCompiler : IDirectiveCompiler
{
public:
	override void compile(IDirectiveStatement statement, ByteCodeCompiler compiler)
	{
		auto stmtRange = statement[];

		IvyNode aggregate = stmtRange.takeFrontAs!IvyNode(`Expected "at" aggregate argument`);
		IvyNode indexValue = stmtRange.takeFrontAs!IvyNode(`Expected "at" index value`);

		aggregate.accept(compiler); // Evaluate aggregate
		indexValue.accept(compiler); // Evaluate index
		compiler.addInstr(OpCode.LoadSubscr);

		if( !stmtRange.empty )
			compiler.loger.error(`Expected end of "at" directive after index expression. Maybe ';' is missing. `
				~ `Info: multiple index expressions are not supported yet.`);
	}
}

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
		compiler.addInstr(OpCode.LoadConst, compiler.addConst( TDataNode() ));

		if( !stmtRange.empty )
			compiler.loger.error(`Expected end of "setat" directive after index expression. Maybe ';' is missing. `
				~ `Info: multiple index expressions are not supported yet.`);
	}
}

class RepeatCompiler : IDirectiveCompiler
{
public:
	override void compile(IDirectiveStatement statement, ByteCodeCompiler compiler)
	{
		auto stmtRange = statement[];

		INameExpression varNameExpr = stmtRange.takeFrontAs!INameExpression("Loop variable name expected");

		string varName = varNameExpr.name;
		if( varName.length == 0 )
			compiler.loger.error("Loop variable name cannot be empty");

		INameExpression inAttribute = stmtRange.takeFrontAs!INameExpression("Expected 'in' attribute");

		if( inAttribute.name != "in" )
			compiler.loger.error("Expected 'in' keyword");

		IExpression aggregateExpr = stmtRange.takeFrontAs!IExpression("Expected loop aggregate expression");

		// Compile code to calculate aggregate value
		aggregateExpr.accept(compiler);

		ICompoundStatement bodyStmt = stmtRange.takeFrontAs!ICompoundStatement("Expected loop body statement");

		if( !stmtRange.empty )
			compiler.loger.error("Expected end of directive after loop body. Maybe ';' is missing");

		// Issue instruction to get iterator from aggregate in execution stack
		compiler.addInstr(OpCode.GetDataRange);

		// Creating node for string result on stack
		compiler.addInstr(OpCode.LoadConst, compiler.addConst( TDataNode(TDataNode[].init) ));

		// RunLoop expects  data node range on the top, but result aggregator
		// can be left on (TOP - 1), so swap these...
		compiler.addInstr(OpCode.SwapTwo);

		// Run our super-duper loop
		size_t loopStartInstrIndex = compiler.addInstr(OpCode.RunLoop);

		// Issue command to store current loop item in local context with specified name
		compiler.addInstr(OpCode.StoreLocalName, compiler.addConst( TDataNode(varName) ));

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
	}
}


// Produces OpCode.Nop
class PassCompiler : IDirectiveCompiler
{
public:
	override void compile(IDirectiveStatement statement, ByteCodeCompiler compiler) {
		compiler.addInstr(OpCode.Nop);
	}
}

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

/// Compiles module into module object and saves it into dictionary
class ImportCompiler: IDirectiveCompiler
{
public:
	override void compile(IDirectiveStatement statement, ByteCodeCompiler compiler)
	{
		auto stmtRange = statement[];

		INameExpression moduleNameExpr = stmtRange.takeFrontAs!INameExpression("Expected module name for import");
		if( !stmtRange.empty )
			compiler.loger.error(`Not all attributes for directive "import" were parsed. Maybe ; is missing somewhere`);

		compiler.getOrCompileModule(moduleNameExpr.name); // Module must be compiled before we can import it

		size_t modNameConstIndex = compiler.addConst(TDataNode(moduleNameExpr.name));
		compiler.addInstr(OpCode.LoadConst, modNameConstIndex); // The first is for ImportModule

		compiler.addInstr(OpCode.ImportModule);
		compiler.addInstr(OpCode.SwapTwo); // Swap module return value and imported execution frame
		compiler.addInstr(OpCode.StoreNameWithParents, modNameConstIndex);
	}
}

/// Compiles module into module object and saves it into dictionary
class FromImportCompiler: IDirectiveCompiler
{
public:
	override void compile(IDirectiveStatement statement, ByteCodeCompiler compiler)
	{
		auto stmtRange = statement[];

		INameExpression moduleNameExpr = stmtRange.takeFrontAs!INameExpression("Expected module name for import");

		INameExpression importKwdExpr = stmtRange.takeFrontAs!INameExpression("Expected 'import' keyword, but got end of range");
		if( importKwdExpr.name != "import" )
			compiler.loger.error("Expected 'import' keyword");

		string[] varNames;
		while( !stmtRange.empty )
		{
			INameExpression varNameExpr = stmtRange.takeFrontAs!INameExpression("Expected imported variable name");
			varNames ~= varNameExpr.name;
		}

		if( !stmtRange.empty )
			compiler.loger.error(`Not all attributes for directive "from" were parsed. Maybe ; is missing somewhere`);

		compiler.getOrCompileModule(moduleNameExpr.name); // Module must be compiled before we can import it

		compiler.addInstr(OpCode.LoadConst, compiler.addConst( TDataNode(moduleNameExpr.name) ));

		compiler.addInstr(OpCode.ImportModule);
		compiler.addInstr(OpCode.SwapTwo); // Swap module return value and imported execution frame
		compiler.addInstr(OpCode.LoadConst, compiler.addConst( TDataNode(varNames) )); // Put list of imported names on the stack
		compiler.addInstr(OpCode.FromImport); // Store names from module exec frame into current frame
	}
}

debug import std.stdio;
/// Defines directive using ivy language
class DefCompiler: IDirectiveCompiler
{
	override void compile(IDirectiveStatement statement, ByteCodeCompiler compiler)
	{
		auto stmtRange = statement[];
		INameExpression defNameExpr = stmtRange.takeFrontAs!INameExpression("Expected name for directive definition");

		ICompoundStatement bodyStatement;
		bool isNoscope = false;

		while( !stmtRange.empty )
		{
			ICodeBlockStatement attrsDefBlockStmt = cast(ICodeBlockStatement) stmtRange.front;
			if( !attrsDefBlockStmt ) {
				break; // Expected to see some attribute declaration
			}

			IDirectiveStatementRange attrDefStmtRange = attrsDefBlockStmt[];

			while( !attrDefStmtRange.empty )
			{
				IDirectiveStatement attrDefStmt = attrDefStmtRange.front;
				IAttributeRange attrsDefStmtAttrRange = attrDefStmt[];

				switch( attrDefStmt.name )
				{
					case "def.kv", "def.pos", "def.names", "def.kwd": break;
					case "def.body": {
						if( bodyStatement )
							compiler.loger.error("Multiple body statements are not allowed!!!");

						if( attrsDefStmtAttrRange.empty )
							compiler.loger.error("Unexpected end of def.body directive!");

						// Try to parse noscope flag
						INameExpression noscopeExpr = cast(INameExpression) attrsDefStmtAttrRange.front;
						if( noscopeExpr && noscopeExpr.name == "noscope" )
						{
							isNoscope = true;
							if( attrsDefStmtAttrRange.empty )
								compiler.loger.error("Expected directive body, but end of def.body directive found!");
							attrsDefStmtAttrRange.popFront();
						}

						bodyStatement = cast(ICompoundStatement) attrsDefStmtAttrRange.front; // Getting body AST for statement
						if( !bodyStatement )
							compiler.loger.error(`Expected compound statement as directive body statement`);

						break;
					}
					default: {
						compiler.loger.error(`Unexpected directive attribute definition statement "` ~ attrDefStmt.name ~ `"`);
						break;
					}
				}
				attrDefStmtRange.popFront(); // Going to the next directive statement in code block
			}
			stmtRange.popFront(); // Go to next attr definition directive
		}

		// Here should go commands to compile directive body
		compiler.loger.internalAssert(bodyStatement, `Directive definition body is null`);

		size_t codeObjIndex;
		{
			import std.algorithm: map;
			import std.array: array;

			Symbol symb = compiler.symbolLookup(defNameExpr.name);
			if( symb.kind != SymbolKind.DirectiveDefinition )
				compiler.loger.error(`Expected directive definition symbol kind`);

			DirectiveDefinitionSymbol dirSymbol = cast(DirectiveDefinitionSymbol) symb;
			assert(dirSymbol, `Directive definition symbol is null`);

			if( !isNoscope )
			{
				// Compiler should enter frame of directive body, identified by index in source code
				compiler.enterScope(bodyStatement.location.index);
			}

			codeObjIndex = compiler.enterNewCodeObject(); // Creating code object

			// Generating code for def.body
			bodyStatement.accept(compiler);

			compiler.currentCodeObject._attrBlocks = dirSymbol.dirAttrBlocks.map!( b => b.toInterpreterBlock() ).array;

			scope(exit) {
				compiler.exitCodeObject();
				if( !isNoscope )
				{
					compiler.exitScope();
				}
			}
		}

		// Add instruction to load code object from module constants
		compiler.addInstr(OpCode.LoadConst, codeObjIndex);

		// Add instruction to load directive name from consts
		compiler.addInstr(OpCode.LoadConst, compiler.addConst( TDataNode(defNameExpr.name) ));

		// Add instruction to create directive object
		compiler.addInstr(OpCode.LoadDirective);
	}
}

class InsertCompiler: IDirectiveCompiler
{
	override void compile(IDirectiveStatement stmt, ByteCodeCompiler compiler)
	{
		auto stmtRange = stmt[];

		if( stmtRange.empty )
			compiler.loger.error(`Expected node as "insert"s "aggregate" argument!`);
		stmtRange.front.accept(compiler);
		stmtRange.popFront();

		if( stmtRange.empty )
			compiler.loger.error(`Expected node as "insert"s "value" argument!`);
		stmtRange.front.accept(compiler);
		stmtRange.popFront();

		if( stmtRange.empty )
			compiler.loger.error(`Expected node as "insert"s "index" argument!`);
		stmtRange.front.accept(compiler);
		stmtRange.popFront();

		compiler.addInstr(OpCode.Insert); // Add Insert instruction that works with 3 passed arguments

		if( !stmtRange.empty )
		{
			compiler.loger.write(`InsertCompiler. At end. stmtRange.front.kind: `, stmtRange.front.kind);
			compiler.loger.error(`Expected end of "insert" directive. Maybe ';' is missing`);
		}
	}
}

class SliceCompiler: IDirectiveCompiler
{
	override void compile(IDirectiveStatement stmt, ByteCodeCompiler compiler)
	{
		auto stmtRange = stmt[];

		if( stmtRange.empty )
			compiler.loger.error(`Expected node as "slice"s "aggregate" argument!`);
		stmtRange.front.accept(compiler);
		stmtRange.popFront();

		if( stmtRange.empty )
			compiler.loger.error(`Expected node as "slice"s "begin" argument!`);
		stmtRange.front.accept(compiler);
		stmtRange.popFront();

		if( stmtRange.empty )
			compiler.loger.error(`Expected node as "slice"s "end" argument!`);
		stmtRange.front.accept(compiler);
		stmtRange.popFront();

		compiler.addInstr(OpCode.LoadSlice); // Add Insert instruction that works with 3 passed arguments

		if( !stmtRange.empty )
		{
			compiler.loger.write(`SliceCompiler. At end. stmtRange.front.kind: `, stmtRange.front.kind);
			compiler.loger.error(`Expected end of "slice" directive. Maybe ';' is missing`);
		}
	}
}