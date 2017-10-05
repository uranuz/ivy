module ivy.compiler.common;

import ivy.common: IvyException;

class ASTNodeTypeException: IvyException
{
public:
	@nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow
	{
		super(msg, file, line, next);
	}
}

class IvyCompilerException: IvyException
{
public:
	@nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow
	{
		super(msg, file, line, next);
	}
}

// Mixin used to get approximate current position of compiler
mixin template NodeVisitWrapperImpl()
{
	import ivy.common: ExtendedLocation;
	import std.algorithm: map;
	import std.string: join;

	alias CustLocation = ExtendedLocation;

	private CustLocation _currentLocation;

	mixin(
		[
			`IvyNode`,
			`IExpression`,
			`ILiteralExpression`,
			`INameExpression`,
			`IOperatorExpression`,
			`IUnaryExpression`,
			`IBinaryExpression`,
			`IAssocArrayPair`,

			`IStatement`,
			`IKeyValueAttribute`,
			`IDirectiveStatement`,
			`IDataFragmentStatement`,
			`ICompoundStatement`,
			`ICodeBlockStatement`,
			`IMixedBlockStatement`
		].map!(function(string typeStr) {
			return `override void visit(` ~ typeStr ~ ` node) {
				this.loger.internalAssert(node, "node is null!");
				this._currentLocation = node.extLocation;
				this._visit(node);
			}
			`;
		}).join()
	);
}