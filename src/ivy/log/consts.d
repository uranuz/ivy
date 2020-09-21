module ivy.log.consts;

enum LogInfoType
{
	info, // Regular log message for debug or smth
	warn, // Warning about strange conditions
	error, // Regular error, caused by wrong template syntax, wrong user input or smth
	internalError // Error that caused by wrong Ivy implementation or smth that should never happens
}