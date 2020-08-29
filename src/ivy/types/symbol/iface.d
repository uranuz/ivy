module ivy.types.symbol.iface;

interface IIvySymbol
{
	string name() @property;
}

interface ICallableSymbol: IIvySymbol
{
	import ivy.types.symbol.dir_attr: DirAttr;
	import ivy.types.symbol.dir_body_attrs: DirBodyAttrs;

	DirAttr[] attrs() @property;
	DirAttr getAttr(string attrName);
	DirBodyAttrs bodyAttrs() @property;
}