module ivy.parser.exception;

import ivy.exception: IvyException;

class IvyParserException: IvyException
{
public:
	@nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow {
		super(msg, file, line, next);
	}
}