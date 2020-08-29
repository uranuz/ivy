module ivy.types.data.iface.range;

interface IvyDataRange
{
	import ivy.types.data: IvyData;

	bool empty() @property;
	IvyData front();
	void popFront();
}