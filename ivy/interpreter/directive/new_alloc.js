define('ivy/interpreter/directive/len', [
	'ivy/interpreter/directive/utils',
	'ivy/types/data/decl_class_node',
	'ivy/types/data/data'
], function(
	du,
	DeclClassNode,
	idat
) {
return FirClass(
	function NewAllocDirInterpreter() {
		this._symbol = new du.DirectiveSymbol("__new_alloc__", [du.DirAttr("class_", du.IvyAttrType.Any)]);
	}, du.BaseDirectiveInterpreter, {
		interpret: function(interp) {
			interp._stack.push(new DeclClassNode(idat.classNode(interp.getValue("class_"))));
		}
	});
});