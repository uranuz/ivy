module ivy.compiler.directive.set;

import ivy.compiler.directive.utils;
import ivy.ast.iface: IKeyValueAttribute;

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
class SetCompiler : BaseDirectiveCompiler
{
public:
	override void compile(IDirectiveStatement stmt, ByteCodeCompiler compiler)
	{
		import std.array: split;
		import std.range: empty, front, popFront;

		auto stmtRange = stmt[];

		while( !stmtRange.empty )
		{
			IKeyValueAttribute kwPair = stmtRange.takeFrontAs!IKeyValueAttribute("Key-value pair expected");

			if( !kwPair.value )
				compiler.log.error("Expected value for 'set' directive");

			if( kwPair.name.empty )
				compiler.log.error("Expected variable name for 'set' directive");
			// Split full path to attr by dots...
			string[] varPath = split(kwPair.name, '.');
			string varName = varPath.front;
			varPath.popFront(); // Drop var name
			if( varPath.empty )
			{
				// If it is just variable setter without attributes, then just set variable in execution frame
				kwPair.value.accept(compiler); // Evaluating expression
				compiler.addInstr(OpCode.StoreGlobalName, compiler.addConst( IvyData(varName) ));
				continue; // And that's all...
			}

			// If there is more parts in var path, then we need to load variable from execution frame first
			compiler.addInstr(OpCode.LoadName, compiler.addConst( IvyData(varName) ));

			// Then try to do the same with all attr names in the path
			while( !varPath.empty )
			{
				// Put attr name on the stack...
				compiler.addInstr(OpCode.LoadConst, compiler.addConst( IvyData(varPath.front) ));
				varPath.popFront(); // Drop attr name
				if( !varPath.empty )
				{
					// This is one of the attrs in the chain. So we need to load it...
					compiler.addInstr(OpCode.LoadAttr);
					continue;
				}
				
				// If this was the last attr in the chain, then set it...
				kwPair.value.accept(compiler); // Evaluating expression
				compiler.addInstr(OpCode.StoreAttr);
			}
		}

		// For now we expect that directive should return some value on the stack
		compiler.addInstr(OpCode.LoadConst, compiler.addConst( IvyData() ));

		if( !stmtRange.empty )
			compiler.log.error("Expected end of directive after key-value pair. Maybe ';' is missing");
	}

}