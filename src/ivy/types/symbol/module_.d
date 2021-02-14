module ivy.types.symbol.module_;

import ivy.types.symbol.iface: ICallableSymbol;

class ModuleSymbol: ICallableSymbol
{
	import trifle.location: Location;
	
	import ivy.types.symbol.dir_attr: DirAttr;
	import ivy.types.symbol.consts: SymbolKind;

	import std.exception: enforce;
	import std.json: JSONValue;

private:
	string _name;
	Location _loc;

public:
	this(string name, Location loc)
	{
		this._name = name;
		this._loc = loc;

		enforce(this._name.length > 0, `Expected module symbol name`);
	}

	override
	{
		string name() @property {
			return this._name;
		}

		Location location() @property {
			return _loc;
		}

		SymbolKind kind() @property {
			return SymbolKind.module_;
		}

		DirAttr[] attrs() @property {
			return null;
		}

		DirAttr getAttr(string attrName) {
			assert(false, `Module symbol has no attributes`);
		}

		JSONValue toStdJSON() @property {
			return JSONValue([
				"name": this._name
			]);
		}
	}
}