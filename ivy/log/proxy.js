define('ivy/log/proxy', [
	"ivy/log/consts"
], function(
	LogConsts
) {
var
	isDebugMode = false,
	LogInfoType = LogConsts.LogInfoType;
return FirClass(
function LogProxyImpl(func, file, line) {
	this.func = func;
	this.file = file;
	this.line = line;
	this._isDebugMode = true;
}, {
	_enf: function(cond, msg) {
		if( !cond ) {
			throw new Error(msg);
		}
	},

	sendLogInfo: function() {
		// Sucessfully do nothing
	},

	genericWrite: function(logInfoType, data)
	{
		var logMessage = '';
		Array.prototype.forEach.call(data, function(item) {
			logMessage += String(item);
		});

		return this.sendLogInfo(logInfoType, logMessage); /// This method need to be implemented to actualy send log message
	},

	/// Writes regular log message for debug
	write: function(data) {
		if( isDebugMode ) {
			this.genericWrite(LogInfoType.info, data);
		}
	},

	/// Writes warning message
	warn: function() {
		this.genericWrite(LogInfoType.warn, data);
	},

	/// Writes regular error to log and throws ExceptionType
	error: function() {
		this.enforce(false, data);
	},

	/// Tests assertion. If it's false then writes regular error to log and throws ExceptionType
	enforce: function(cond) {
		this._enf(cond, this.genericWrite(LogInfoType.error, arguments));
	},

	/// Writes internal error to log and throws ExceptionType
	internalError: function() {
		this.internalAssert(false, data);
	},

	/// Tests assertion. If it's false then writes internal error to log and throws ExceptionType
	internalAssert: function(cond) {
		this._enf(cond, this.genericWrite(LogInfoType.internalError, arguments));
	},

	/// Name of function where event occured
	func: firProperty(function() {
		return this._func;
	}, function(val) {
		this._func = val;
	}),

	/// File name where event occured
	file: firProperty(function() {
		return this._file;
	}, function(val) {
		this._file = val;
	}),

	/// Line of code where event occured
	line: firProperty(function() {
		return this._line;
	}, function(val) {
		this._line = val;
	})
});
});