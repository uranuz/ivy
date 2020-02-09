module ivy.ast.common;

import trifle.location: LocationConfig;

mixin template BaseDeclNodeImpl(LocationConfig c)
{
	import trifle.location: Location, PlainLocation, ExtendedLocation, CustomizedLocation;

	import ivy.ast.iface: IvyNode;
	import ivy.ast.iface.visitor: AbstractNodeVisitor;
	
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

mixin template BaseExpressionImpl(LocationConfig c)
{
	import ivy.ast.consts: LiteralType;
	import ivy.ast.common: BaseDeclNodeImpl;
	import ivy.ast.iface.statement: IStatement;

	mixin BaseDeclNodeImpl!c;

	public @property override
	{
		IStatement asStatement() {
			return null;
		}

		LiteralType literalType() {
			return LiteralType.NotLiteral;
		}

		bool isScalar() {
			assert( 0, "Cannot determine expression type" );
		}

		bool isNullExpr() {
			assert( 0, "Expression is not null expr!" );
		}
	}

	public override {
		bool toBoolean() {
			assert( 0, "Expression is not boolean!" );
		}

		int toInteger() {
			assert( 0, "Expression is not integer!" );
		}

		double toFloating() {
			assert( 0, "Expression is not floating!" );
		}

		string toStr() {
			assert( 0, "Expression is not string!" );
		}
	}
}