module ivy.types.symbol.dir_attr;

public import ivy.types.symbol.consts: IvyAttrType;

struct DirAttr
{
	import ivy.types.data: IvyData;

	string name;
	string typeName;

	this(string name, string typeName = null)
	{
		this.name = name;
		this.typeName = typeName;
	}
}