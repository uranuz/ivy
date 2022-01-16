import {DirectiveInterpreter} from 'ivy/interpreter/directive/base';
import { Interpreter } from 'ivy/interpreter/interpreter';
import {DirectiveSymbol} from 'ivy/types/symbol/directive';
import { DirAttr } from 'ivy/types/symbol/dir_attr';

export function makeDir(Method: Function, symbolName: string, attrs?: DirAttr[]) {
	return new DirectiveInterpreter(
		_callDir.bind(null, Method, attrs),
		new DirectiveSymbol(symbolName, attrs)
	);
}

function _callDir(Method: Function, attrs: DirAttr[], interp: Interpreter) {
	var self = interp.hasValue("this") ? interp.getValue("this") : null;
	var args = attrs ? attrs.map(function(it) {
		return interp.getValue(it.name);
	}) : [];

	args.push(interp);

	interp._stack.push(Method.apply(self, args));
}
