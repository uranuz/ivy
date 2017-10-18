module ivy.directive_stuff;

struct DirValueAttr(bool isForCompiler = false)
{
	string name;
	string typeName;

	static if( isForCompiler )
	{
		import ivy.parser.node: IExpression;

		IExpression defaultValueExpr;
		this( string name, string typeName, IExpression defValue = null )
		{
			this.name = name;
			this.typeName = typeName;
			this.defaultValueExpr = defValue;
		}
	}
	else
	{
		this( string name, string typeName )
		{
			this.name = name;
			this.typeName = typeName;
		}
	}

	DirValueAttr!(false) toInterpreterValue() {
		return DirValueAttr!(false)(name, typeName);
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


enum DirAttrKind { NamedAttr, ExprAttr, IdentAttr, KwdAttr, BodyAttr };

static this()
{
	static assert( DirAttrKind.max <= _stackBlockHeaderTypeMask, `DirAttrKind set of values exeeded of defined limit` );
}

struct DirAttrsBlock(bool isForCompiler = false)
{
	import std.typecons: Tuple, tuple;
	import std.meta: AliasSeq;
	alias TValueAttr = DirValueAttr!(isForCompiler);
	alias BodyAttrs = AliasSeq!(
		bool, "isNoscope",
		bool, "isNoescape"
	);

	static if( isForCompiler ) {
		import ivy.parser.node: ICompoundStatement;
		alias TBodyTuple = Tuple!(ICompoundStatement, "ast", BodyAttrs);
	}	else {
		alias TBodyTuple = Tuple!(BodyAttrs);
	}

	static struct Storage {
		union {
			TValueAttr[string] namedAttrs;
			TValueAttr[] exprAttrs;
			string[] names;
			string keyword;
			TBodyTuple bodyAttr;
		}
	}

	private DirAttrKind _kind;
	private Storage _storage;

	this( DirAttrKind attrKind, TValueAttr[string] attrs )
	{
		assert( attrKind == DirAttrKind.NamedAttr, `Expected NamedAttr kind for attr block` );

		_kind = attrKind;
		_storage.namedAttrs = attrs;
	}

	this( DirAttrKind attrKind, TValueAttr[] attrs )
	{
		assert( attrKind == DirAttrKind.ExprAttr, `Expected ExprAttr kind for attr block` );

		_kind = attrKind;
		_storage.exprAttrs = attrs;
	}

	this( DirAttrKind attrKind, string[] names )
	{
		assert( attrKind == DirAttrKind.IdentAttr, `Expected IdentAttr kind for attr block` );

		_kind = attrKind;
		_storage.names = names;
	}

	this( DirAttrKind attrKind, string kwd )
	{
		assert( attrKind == DirAttrKind.KwdAttr, `Expected Keyword kind for attr block` );

		_kind = attrKind;
		_storage.keyword = kwd;
	}

	this( DirAttrKind attrKind, TBodyTuple value )
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

	void namedAttrs( TValueAttr[string] attrs ) @property {
		_storage.namedAttrs = attrs;
		_kind = DirAttrKind.NamedAttr;
	}

	TValueAttr[string] namedAttrs() @property {
		assert( _kind == DirAttrKind.NamedAttr, `Directive attrs block is not of NamedAttr kind` );
		return _storage.namedAttrs;
	}

	void exprAttrs( TValueAttr[] attrs ) @property {
		_storage.exprAttrs = attrs;
		_kind = DirAttrKind.ExprAttr;
	}

	TValueAttr[] exprAttrs() @property {
		assert( _kind == DirAttrKind.ExprAttr, `Directive attrs block is not of ExprAttr kind` );
		return _storage.exprAttrs;
	}

	void names(string[] names) @property {
		_storage.names = names;
		_kind = DirAttrKind.IdentAttr;
	}

	string[] names() @property {
		assert( _kind == DirAttrKind.IdentAttr, `Directive attrs block is not of IdentAttr kind` );
		return _storage.names;
	}

	void keyword(string value) @property {
		_storage.keyword = value;
		_kind = DirAttrKind.KwdAttr;
	}

	string keyword() @property {
		assert( _kind == DirAttrKind.KwdAttr, `Directive attrs block is not of KwdAttr kind` );
		return _storage.keyword;
	}

	void bodyAttr(TBodyTuple value) @property {
		_storage.bodyAttr = value;
		_kind = DirAttrKind.BodyAttr;
	}

	TBodyTuple bodyAttr() @property {
		assert( _kind == DirAttrKind.BodyAttr, `Directive attrs block is not of BodyAttr kind` );
		return _storage.bodyAttr;
	}

	DirAttrsBlock!(false) toInterpreterBlock()
	{
		import std.algorithm: map;
		import std.array: array;

		final switch( _kind )
		{
			case DirAttrKind.NamedAttr: {
				DirValueAttr!(false)[string] attrs;
				foreach( key, ref currAttr; _storage.namedAttrs ) {
					attrs[key] = currAttr.toInterpreterValue();
				}
				return DirAttrsBlock!(false)(_kind, attrs);
			}
			case DirAttrKind.ExprAttr:
				return DirAttrsBlock!(false)(_kind, _storage.exprAttrs.map!( a => a.toInterpreterValue() ).array);
			case DirAttrKind.IdentAttr:
				return DirAttrsBlock!(false)(_kind, _storage.names);
			case DirAttrKind.KwdAttr:
				return DirAttrsBlock!(false)(_kind, _storage.keyword);
			case DirAttrKind.BodyAttr:
				return DirAttrsBlock!(false)(_kind,
					tuple!("isNoscope", "isNoescape")(_storage.bodyAttr.isNoscope, _storage.bodyAttr.isNoescape)
				);
		}
		assert( false, `This should never happen` );
	}

	string toString()
	{
		import std.conv: to;
		final switch( _kind ) with( DirAttrKind )
		{
			case NamedAttr:
			case ExprAttr:
			case IdentAttr:
			case KwdAttr:
			case BodyAttr:
				return `<` ~ _kind.to!string ~ ` attrs block>`;
		}
	}
}