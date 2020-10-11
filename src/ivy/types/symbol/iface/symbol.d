module ivy.types.symbol.iface.symbol;

interface IIvySymbol
{
	import trifle.location: Location;
	import std.json: JSONValue;

	string name() @property;

	Location location() @property;

	JSONValue toStdJSON();
}