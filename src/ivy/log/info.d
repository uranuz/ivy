module ivy.log.info;

// Struct consolidating info for logging
struct LogInfo
{
	import trifle.location: Location;
	import ivy.log.consts: LogInfoType;

	LogInfoType type; // Kind of log event
	string msg; // Log message
	string sourceFileName; // D source file name where log event happens
	size_t sourceLine; // D code source line where log event happens
	string sourceFuncName; // D function name where log event happens
	Location location;
}