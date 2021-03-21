module ivy.compiler.node_visit_mixin;

// Mixin used to get approximate current position of compiler
mixin template NodeVisitMixin()
{
	import ivy.ast.iface;
	
	import trifle.location: Location;
	import std.algorithm: map;
	import std.string: join;

	private Location _currentLocation;

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
				this._currentLocation = node.location;
				this._visit(node);
			}
			`;
		}).join()
	);
}