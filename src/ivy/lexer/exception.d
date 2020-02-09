module ivy.lexer.exception;

import ivy.exception: IvyException;

class IvyLexerException: IvyException
{
public:
	@nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow
	{
		super(msg, file, line, next);
	}
}

void lexerError(string msg, string file = __FILE__, size_t line = __LINE__)
{
	throw new IvyLexerException(msg, file, line);
}