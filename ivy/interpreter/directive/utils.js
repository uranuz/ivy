define('ivy/interpreter/directive/utils', [
	'exports',
	'ivy/interpreter/directive/base',
	'ivy/types/symbol/directive'
], function(
	exports,
	DirectiveInterpreter,
	DirectiveSymbol
) {
	function IvyMethodAttr(method, symbolName, attrs) {
		method.symbolName = symbolName;
		method.attrs = attrs;
	};

	function makeDir(Method, symbolName, attrs) {
		return new DirectiveInterpreter(
			_callDir.bind(null, Method, attrs),
			new DirectiveSymbol(symbolName, attrs)
		);
	}

	function _callDir(Method, attrs, interp) {
		var self = interp.hasValue("this") ? interp.getValue("this") : null;
		var args = attrs ? attrs.map(function(it) {
			return interp.getValue(it.name);
		}) : [];

		args.push(interp);

		interp._stack.push(Method.apply(self, args));
	}

	exports.makeDir = makeDir;
	exports.IvyMethodAttr = IvyMethodAttr;
});
