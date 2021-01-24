module ivy.types.decl_class_factory;

class DeclClassFactory
{
	import ivy.types.data: IvyData;
	import ivy.types.data.decl_class: DeclClass;

public:
	this() {}

	DeclClass makeClass(string name, IvyData[string] dataDict, DeclClass baseClass) {
		return new DeclClass(name, dataDict, baseClass);
	}
}