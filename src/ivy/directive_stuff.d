module ivy.directive_stuff;

struct DirValueAttr
{
	import ivy.interpreter.data_node: IvyData;

	string name;
	string typeName;
	IvyData defaultValue;

	this(string name, string typeName = null, IvyData defValue = IvyData())
	{
		this.name = name;
		this.typeName = typeName;
		this.defaultValue = defValue;
	}
}

// We pass callable attributes by blocks. Every attribute block has size an type
// Size and type stored in single integer argument in stack preceding the block
// Size is major binary part of this integer denoted by bit offset:
enum size_t _stackBlockHeaderSizeOffset = 4;
// To have some validity check bit between size and block type must always be zero
// The following mask is used to check for validity:
enum size_t _stackBlockHeaderCheckMask = 0b1000;
// And there is mask to extract type of block
enum size_t _stackBlockHeaderTypeMask = 0b111;


enum DirAttrKind { NamedAttr, ExprAttr, BodyAttr };

static this()
{
	static assert( DirAttrKind.max <= _stackBlockHeaderTypeMask, `DirAttrKind set of values exeeded of defined limit` );
}

import std.typecons: Tuple;
alias DirBodyAttr = Tuple!(
	bool, "isNoscope",
	bool, "isNoescape"
);

struct DirAttrsBlock
{
	static struct Storage {
		union {
			DirValueAttr[string] namedAttrs;
			DirValueAttr[] exprAttrs;
			DirBodyAttr bodyAttr;
		}
	}

	private DirAttrKind _kind;
	private Storage _storage;

	this( DirAttrKind attrKind, DirValueAttr[string] attrs )
	{
		assert( attrKind == DirAttrKind.NamedAttr, `Expected NamedAttr kind for attr block` );

		_kind = attrKind;
		_storage.namedAttrs = attrs;
	}

	this( DirAttrKind attrKind, DirValueAttr[] attrs )
	{
		assert( attrKind == DirAttrKind.ExprAttr, `Expected ExprAttr kind for attr block` );

		_kind = attrKind;
		_storage.exprAttrs = attrs;
	}

	this( DirAttrKind attrKind, DirBodyAttr value )
	{
		assert( attrKind == DirAttrKind.BodyAttr, `Expected BodyAttr kind for attr block` );

		_kind = attrKind;
		_storage.bodyAttr = value;
	}

	this( DirAttrKind attrKind )
	{
		_kind = attrKind;
	}

	DirAttrKind kind() @property {
		return _kind;
	}

	void kind(DirAttrKind value) @property {
		_kind = value;
	}

	void namedAttrs( DirValueAttr[string] attrs ) @property {
		_storage.namedAttrs = attrs;
		_kind = DirAttrKind.NamedAttr;
	}

	DirValueAttr[string] namedAttrs() @property {
		assert( _kind == DirAttrKind.NamedAttr, `Directive attrs block is not of NamedAttr kind` );
		return _storage.namedAttrs;
	}

	void exprAttrs( DirValueAttr[] attrs ) @property {
		_storage.exprAttrs = attrs;
		_kind = DirAttrKind.ExprAttr;
	}

	DirValueAttr[] exprAttrs() @property {
		assert( _kind == DirAttrKind.ExprAttr, `Directive attrs block is not of ExprAttr kind` );
		return _storage.exprAttrs;
	}

	void bodyAttr(DirBodyAttr value) @property {
		_storage.bodyAttr = value;
		_kind = DirAttrKind.BodyAttr;
	}

	DirBodyAttr bodyAttr() @property {
		assert( _kind == DirAttrKind.BodyAttr, `Directive attrs block is not of BodyAttr kind` );
		return _storage.bodyAttr;
	}

	string toString()
	{
		import std.conv: to;
		final switch( _kind ) with( DirAttrKind )
		{
			case NamedAttr:
			case ExprAttr:
			case BodyAttr:
				return `<` ~ _kind.to!string ~ ` attrs block>`;
		}
	}
}