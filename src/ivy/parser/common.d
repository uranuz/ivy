module ivy.parser.common;

import ivy.common;
import ivy.parser.node: IvyNode;
import ivy.parser.node_visitor: AbstractNodeVisitor;

mixin template BaseDeclNodeImpl(LocationConfig c)
{
	enum locConfig = c;
	alias CustLocation = CustomizedLocation!locConfig;

	private IvyNode _parentNode;
	private CustLocation _location;

	public @property override
	{
		IvyNode parent() {
			return _parentNode;
		}

		Location location() const {
			return _location.toLocation();
		}

		PlainLocation plainLocation() const {
			return _location.toPlainLocation();
		}

		ExtendedLocation extLocation() const {
			return _location.toExtendedLocation();
		}

		LocationConfig locationConfig() const {
			return _location.config;
		}
	}

	public @property override
	{
		void parent(IvyNode node) {
			_parentNode = node;
		}
	}

	public override void accept(AbstractNodeVisitor visitor) {
		visitor.visit(this);
	}
}