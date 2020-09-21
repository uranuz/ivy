module ivy.compiler.common;

import ivy.ast.iface: IAttributeRange;
import ivy.compiler.errors: ASTNodeTypeException;

import ivy.log.utils: getShortFuncName;

T expectNode(T)(IvyNode node, string msg = null, string file = __FILE__, string func = __FUNCTION__, int line = __LINE__)
{
	import std.algorithm: splitter;
	import std.range: retro, take, join;
	import std.array: array;
	import std.conv: to;

	string shortFuncName = getShortFuncName(func);
	enum shortObjName = getShortFuncName(T.stringof);

	T typedNode = cast(T) node;
	if( !typedNode )
		throw new ASTNodeTypeException(shortFuncName ~ "[" ~ line.to!string ~ "]: Expected " ~ shortObjName ~ ":  " ~ msg, file, line);

	return typedNode;
}

T takeFrontAs(T)(IAttributeRange range, string errorMsg = null, string file = __FILE__, string func = __FUNCTION__, int line = __LINE__)
{
	import std.algorithm: splitter;
	import std.range: retro, take, join;
	import std.array: array;
	import std.conv: to;

	static immutable shortObjName = getShortFuncName(T.stringof);
	string shortFuncName = getShortFuncName(func);
	string longMsg = shortFuncName ~ "[" ~ line.to!string ~ "]: Expected " ~ shortObjName ~ ":  " ~ errorMsg;

	if( range.empty )
		throw new ASTNodeTypeException(longMsg, file, line);

	T typedAttr = cast(T) range.front;
	if( !typedAttr )
		throw new ASTNodeTypeException(longMsg, file, line);

	range.popFront();

	return typedAttr;
}