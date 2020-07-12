module ivy.compiler.node_visit_mixin;

// Mixin used to get approximate current position of compiler
mixin template NodeVisitMixin()
{
	import trifle.location: ExtendedLocation;
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
				this.log.internalAssert(node, "node is null!");
				this._currentLocation = node.extLocation;
				this._visit(node);
			}
			`;
		}).join()
	);
}