define('ivy/exception', [], function() {
return FirClass(function IvyException(msg) {
	this.name = 'IvyException';
	this.message = msg;
	this.stack = (new Error()).stack;
}, Error);
});