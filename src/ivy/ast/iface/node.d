module ivy.ast.iface.node;

interface IvyNode
{
	import trifle.location: Location;
	import ivy.ast.iface.visitor: AbstractNodeVisitor;

	@property {
		IvyNode parent();
		IvyNode[] children();

		Location location() const; // Location info for internal usage

		string kind();
	}

	@property {
		void parent(IvyNode node);
	}

	void accept(AbstractNodeVisitor visitor);

	// string toString();
}