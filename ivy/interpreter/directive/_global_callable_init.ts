import { Interpreter } from 'ivy/interpreter/interpreter';
import { CallableObject } from 'ivy/types/callable_object';
import { makeDir } from 'ivy/interpreter/directive/utils';
import { GLOBAL_SYMBOL_NAME } from 'ivy/types/symbol/consts';

Interpreter._globalCallable = new CallableObject(makeDir(_globalStub, GLOBAL_SYMBOL_NAME));

function _globalStub(): void {
	// Does nothing...
}