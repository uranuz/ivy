module ivy.types.symbol.module_;

import ivy.types.symbol.iface: ICallableSymbol;

class ModuleSymbol: ICallableSymbol
{
	import ivy.types.symbol.dir_attr: DirAttr;
	import ivy.types.symbol.dir_body_attrs: DirBodyAttrs;

	import std.exception: enforce;

private:
	string _name;
	string _fileName;

public:
	this(string name, string fileName)
	{
		this._name = name;
		this._fileName = fileName;

		enforce(this._name.length > 0, `Expected module symbol name`);
		enforce(this._fileName.length > 0, `Expected module symbol file name`);
	}

	override
	{
		string name() @property {
			return this._name;
		}

		DirAttr[] attrs() @property {
			return null;
		}

		DirAttr getAttr(string attrName) {
			assert(false, `Module symbol has no attributes`);
		}

		DirBodyAttrs bodyAttrs() @property {
			return DirBodyAttrs.init;
		}
	}

	string fileName() @property {
		return this._fileName;
	}
}