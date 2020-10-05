define('ivy/interpreter/exception', [
	'ivy/exception'
], function(
	IvyException
) {
return FirClass(function InterpreterException(msg) {
	this.name = 'InterpreterException';
	this.message = msg;
	this.stack = (new Error()).stack;
}, IvyException);
});