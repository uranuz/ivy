module ivy.types.data.exception;

import ivy.exception: IvyException;

class DataNodeException: IvyException
{
public:
	@nogc @safe this(string msg, int line = 0, int pos = 0, Throwable next = null) pure nothrow {
		super(msg, file, line, next);
	}

	@nogc @safe this(string msg, string file, size_t line, Throwable next = null) pure nothrow	{
		super(msg, file, line, next);
	}
}

class PropertyNotImplException: DataNodeException
{
public:
	@safe this(string nodeKind, string prop, string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow {
		super(`Property "` ~ prop ~ `" is not implemented for node kind "` ~ nodeKind ~ `"`, file, line, next);
	}
}