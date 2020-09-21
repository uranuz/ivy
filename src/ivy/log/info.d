module ivy.log.info;

// Struct consolidating info for logging
struct LogInfo
{
	import ivy.log.consts: LogInfoType;

	string msg; // Log message
	LogInfoType type; // Kind of log event
	string sourceFuncName; // D function name where log event happens
	string sourceFileName; // D source file name where log event happens
	size_t sourceLine; // D code source line where log event happens
	string processedFile; // Path or name to processed file
	size_t processedLine; // Line number of processed file where log event happens
	string processedText; // Short fragment of processed text where log event happens
}