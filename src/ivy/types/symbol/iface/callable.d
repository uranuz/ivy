module ivy.types.symbol.iface.callable;

import ivy.types.symbol.iface.symbol: IIvySymbol;

interface ICallableSymbol: IIvySymbol
{
	import ivy.types.symbol.dir_attr: DirAttr;

	DirAttr[] attrs() @property;
	DirAttr getAttr(string attrName);
}