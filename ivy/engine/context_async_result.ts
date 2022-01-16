import {Interpreter} from 'ivy/interpreter/interpreter';
import {AsyncResult} from 'ivy/types/data/async_result';

export class ContextAsyncResult {
	public interp: Interpreter;
	public asyncResult: AsyncResult;

	constructor(interp: Interpreter, asyncResult: AsyncResult) {
		this.interp = interp;
		this.asyncResult = asyncResult;
	}
}