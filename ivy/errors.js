define('ivy/errors', [], function() {
	function IvyError(msg) {
		this.name = 'IvyError';
		this.message = msg;
		this.stack = (new Error()).stack;
	}
	__extends(IvyError, Error);

	function InterpreterError(msg) {
		this.name = 'InterpreterError';
		this.message = msg;
		this.stack = (new Error()).stack;
	}
	__extends(InterpreterError, IvyError);
	return {
		IvyError: IvyError,
		InterpreterError: InterpreterError
	};
});