module ivy.types.symbol.iface.symbol;

interface IIvySymbol
{
	import trifle.location: Location;
	import std.json: JSONValue;

	import ivy.types.symbol.consts: SymbolKind;

	string name() @property;

	Location location() @property;

	SymbolKind kind() @property;

	JSONValue toStdJSON();
}