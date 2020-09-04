module ivy.types.symbol.directive;

import ivy.types.symbol.iface: ICallableSymbol;

class DirectiveSymbol: ICallableSymbol
{
	import ivy.types.symbol.dir_attr: DirAttr;
	import ivy.types.symbol.dir_body_attrs: DirBodyAttrs;

	import std.exception: enforce;

private:
	string _name;
	DirAttr[] _attrs;
	DirBodyAttrs _bodyAttrs;

	size_t[string] _attrIndexes;

public:
	this(string name, DirAttr[] attrs = null, DirBodyAttrs bodyAttrs = DirBodyAttrs.init)
	{
		this._name = name;
		this._attrs = attrs;
		this._bodyAttrs = bodyAttrs;

		enforce(this._name.length > 0, `Expected directive symbol name`);
		this._reindexAttrs();
	}

	private void _reindexAttrs()
	{
		foreach( index, attr; attrs )
		{
			enforce(attr.name !in this._attrIndexes, `Duplicate attribite name for directive symbol: ` ~ this._name);
			this._attrIndexes[attr.name] = index;
		}
	}

	override
	{
		string name() @property {
			return this._name;
		}

		DirAttr[] attrs() @property {
			return this._attrs;
		}

		DirAttr getAttr(string attrName)
		{
			auto idxPtr = attrName in this._attrIndexes;
			enforce(idxPtr !is null, `No attribute with name "` ~ attrName ~ `" for directive "` ~ this._name ~ `"`);
			return this._attrs[*idxPtr];
		}

		DirBodyAttrs bodyAttrs() @property {
			return this._bodyAttrs;
		}
	}
}