module ivy.interpreter.directive.scope_dir;

import ivy.interpreter.directive.utils;

class ScopeDirInterpreter: BaseDirectiveInterpreter
{
	this(){
		this._symbol = new DirectiveSymbol("scope");
	}

	override void interpret(Interpreter interp) {
		interp._stack.push(interp.previousFrame._dataDict);
	}
}