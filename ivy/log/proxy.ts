import {LogInfoType} from 'ivy/log/consts';

var isDebugMode = false;

export class IvyLogProxy {
	write(logInfoType: LogInfoType) {
		return this._writeImpl(logInfoType, arguments);
	}

	/// Writes warning message
	warn() {
		this._writeImpl(LogInfoType.warn, arguments);
	}

	/// Writes regular error to log and throws ExceptionType
	error(data: any) {
		this._writeImpl(LogInfoType.error, arguments);
	}

	/// Writes internal error to log and throws ExceptionType
	internalError() {
		this._writeImpl(LogInfoType.internalError, arguments);
	}

	_writeImpl(logInfoType: LogInfoType, args: any) {
		var logMessage = '';
		Array.prototype.forEach.call(args, (item: any) => {
			logMessage += String(item);
		});

		/// This method need to be implemented to actualy send log message
		return this._sendLogInfo(logInfoType, logMessage);
	}

	_sendLogInfo(logInfoType: LogInfoType, data: string) {
		// Log errors and warnings onto console
		switch( logInfoType ) {
			case LogInfoType.error:
			case LogInfoType.internalError: {
				console.error('[IVY] ' + data);
				break;
			}
			case LogInfoType.warn: {
				console.warn('[IVY] ' + data);
				break;
			}
			default: break;
		}
	}
}