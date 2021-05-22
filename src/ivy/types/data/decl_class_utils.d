module ivy.types.data.decl_class_utils;

import ivy.types.data.decl_class: DeclClass;
import ivy.types.data.decl_class_node: DeclClassNode;

DeclClass makeClass(alias ClassNode)(string symbolName)
	if( is(ClassNode : DeclClassNode) )
{
	import std.traits:
		getSymbolsByUDA,
		getUDAs,
		isSomeFunction;
	import std.exception: enforce;

	import ivy.interpreter.directive.utils: IvyMethodAttr, makeDir;
	import ivy.types.data: IvyData;
	import ivy.types.callable_object: CallableObject;

	IvyData[string] dataDict;
	static foreach( alias method; getSymbolsByUDA!(ClassNode, IvyMethodAttr) )
	{{
		static assert(isSomeFunction!method, "Some function expected to be marked with IvyMethodAttr");
		alias udas = getUDAs!(method, IvyMethodAttr);
		static assert(udas.length == 1, "Expected only one instance of IvyMethodAttr on method");
		enum IvyMethodAttr ivyMethodAttr = udas[0];
		static if( ivyMethodAttr.symbolName.length > 0 ) {
			enum methodSymbolName = ivyMethodAttr.symbolName;
		} else {
			enum methodSymbolName = __traits(identifier, method);
		}
		enforce(methodSymbolName !in dataDict, "Symbol '" ~ methodSymbolName ~ "' already exists in class: " ~ symbolName);
		dataDict[methodSymbolName] = new CallableObject(makeDir!method(methodSymbolName, ivyMethodAttr.attrs));
	}}
	return new DeclClass(symbolName, dataDict);
}