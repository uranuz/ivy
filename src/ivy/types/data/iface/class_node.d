module ivy.types.data.iface.class_node;

interface IClassNode
{
	import ivy.types.data: IvyData;
	import ivy.types.data.iface.class_node: IClassNode;
	import ivy.types.data.iface.range: IvyDataRange;
	import ivy.types.callable_object: CallableObject;
	
	IvyDataRange opSlice();
	IClassNode opSlice(size_t, size_t);
	IvyData opIndex(IvyData);
	IvyData __getAttr__(string);
	void __setAttr__(IvyData, string);
	IvyData __serialize__();
	CallableObject __call__();
	size_t length() @property;
	bool empty() @property;
}