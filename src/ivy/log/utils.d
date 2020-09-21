module ivy.log.utils;

string getShortFuncName(string func)
{
	import std.algorithm: splitter;
	import std.range: retro, take;
	import std.array: array, join;

	return func.splitter('.').retro.take(2).array.retro.join(".");
}