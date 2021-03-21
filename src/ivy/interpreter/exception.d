module ivy.interpreter.exception;

import ivy.exception: IvyException;


class IvyInterpretException: IvyException
{
	import ivy.interpreter.exec_frame_info: ExecFrameInfo;

protected:
	ExecFrameInfo[] _frameStackInfo;

public:
	this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow @nogc @safe 
	{
		super(msg, file, line, next);
	}

	ExecFrameInfo[] frameStackInfo() @property {
		return this._frameStackInfo;
	}

	void frameStackInfo(ExecFrameInfo[] items) @property
	{
		import std.range: empty, back;
		this._frameStackInfo = items;

		// Set location of last item in frame stack
		if( !items.empty )
			this.location = items.back.location;
	}
}