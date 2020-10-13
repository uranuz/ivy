define('ivy/types/data/exception', [
	'exports',
	'ivy/exception'
], function(
	exports,
	IvyException
) {
[
	FirClass(function DataNodeException(message) {
		this.superproto.constructor.call(this, message);
	}, IvyException),
	FirClass(function NotImplException(message) {
		this.superproto.constructor.call(this, message);
	}, IvyException)
].forEach(function(it) {
	exports[it.name] = it;
});
});