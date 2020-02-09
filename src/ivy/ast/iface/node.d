module ivy.ast.iface.node;

interface IvyNode
{
	import trifle.location: LocationConfig, Location, PlainLocation, ExtendedLocation;
	import ivy.ast.iface.visitor: AbstractNodeVisitor;

	@property {
		IvyNode parent();
		IvyNode[] children();

		Location location() const;             // Location info for internal usage
		PlainLocation plainLocation() const;   // Location for user info
		ExtendedLocation extLocation() const;  // Extended location info
		LocationConfig locationConfig() const; // Configuration of available location data

		string kind();
	}

	@property {
		void parent(IvyNode node);
	}

	void accept(AbstractNodeVisitor visitor);

	// string toString();
}