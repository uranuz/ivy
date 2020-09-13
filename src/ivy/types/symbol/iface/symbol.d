module ivy.types.symbol.iface.symbol;

interface IIvySymbol
{
	import trifle.location: Location;

	string name() @property;

	Location location() @property;
}