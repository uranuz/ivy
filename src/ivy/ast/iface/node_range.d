module ivy.ast.iface.node_range;

interface IvyNodeRange
{
	import ivy.ast.iface.node: IvyNode;

	@property IvyNode front();
	void popFront();

	@property IvyNode back();
	void popBack();

	@property bool empty();

	@property IvyNodeRange save();

	IvyNode opIndex(size_t index);
}