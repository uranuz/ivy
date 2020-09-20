define('ivy/interpreter/directive/utils', [
	'exports',
	'ivy/interpreter/directive/iface',
	'ivy/interpreter/directive/base',
	'ivy/interpreter/interpreter',
	'ivy/types/data',
	'ivy/types/data/consts',
	'ivy/types/symbol/directive',
	'ivy/types/symbol/dir_attr',
	'ivy/types/symbol/consts',
	'ivy/types/symbol/dir_body_attrs'
], function(
	mod,
	IDirectiveInterpreter,
	BaseDirectiveInterpreter,
	Interpreter,
	idat,
	DataConsts,
	DirectiveSymbol,
	DirAttr,
	SymbolConsts,
	DirBodyAttrs
) {
mod.IDirectiveInterpreter = IDirectiveInterpreter;
mod.BaseDirectiveInterpreter = BaseDirectiveInterpreter;
mod.Interpreter = Interpreter;
mod.idat = idat;
mod.IvyDataType = DataConsts.IvyDataType;
mod.NodeEscapeState = DataConsts.NodeEscapeState;
mod.DirectiveSymbol = DirectiveSymbol;
mod.DirAttr = DirAttr;
mod.IvyAttrType = SymbolConsts.IvyAttrType;
mod.DirBodyAttrs = DirBodyAttrs;
});