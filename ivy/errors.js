define('ivy/errors', [], function() {
var
	IvyError = FirClass(function IvyError(msg) {
		this.name = 'IvyError';
		this.message = msg;
		this.stack = (new Error()).stack;
	}, Error),
	InterpreterError = FirClass(function InterpreterError(msg) {
		this.name = 'InterpreterError';
		this.message = msg;
		this.stack = (new Error()).stack;
	}, IvyError);
	return {
		IvyError: IvyError,
		InterpreterError: InterpreterError
	};
});