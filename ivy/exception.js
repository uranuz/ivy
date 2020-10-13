define('ivy/exception', [], function() {
return FirClass(function IvyException(msg) {
	this.name = arguments.callee.name;
	this.message = msg;
	this.stack = (new Error()).stack;
}, Error);
});