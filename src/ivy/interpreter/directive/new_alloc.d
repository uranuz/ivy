module ivy.interpreter.directive.new_alloc;

import ivy.interpreter.directive.utils;

class NewAllocDirInterpreter: BaseDirectiveInterpreter
{
	import ivy.types.data.decl_class: DeclClass;
	import ivy.types.data.decl_class_node: DeclClassNode;
	
	this() {
		this._symbol = new DirectiveSymbol("__new_alloc__", [DirAttr("class_", IvyAttrType.Any)]);
	}
	
	override void interpret(Interpreter interp)
	{
		DeclClass class_ = cast(DeclClass) interp.getValue("class_").classNode;
		interp.assure(class_, "Expected \"class_\" to allocate instance of");
		interp._stack.push(new DeclClassNode(class_));
	}
}