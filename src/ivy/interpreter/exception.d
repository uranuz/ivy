module ivy.interpreter.exception;

import ivy.exception: IvyException;

struct CallStackInfoItem
{
	string mod;
	string callable;
}


class IvyInterpretException: IvyException
{
private:
	string _moduleName;
	size_t _moduleLine;
	size_t _instrAddr;
	int _opcode;
	CallStackInfoItem[] _callStackInfo;

public:
	this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow @nogc @safe 
	{
		super(msg, file, line, next);
	}

	CallStackInfoItem[] callStackInfo() @property {
		return _callStackInfo;
	}

	void callStackInfo(CallStackInfoItem[] items) @property {
		_callStackInfo = items;
	}

	string moduleName() @property {
		return _moduleName;
	}

	void moduleName(string val) @property {
		_moduleName = val;
	}

	int opcode() @property {
		return _opcode;
	}

	void opcode(int val) @property {
		_opcode = val;
	}


	size_t moduleLine() @property {
		return _moduleLine;
	}

	void moduleLine(size_t val) @property {
		_moduleLine = val;
	}

	size_t instrAddr() @property {
		return _instrAddr;
	}

	void instrAddr(size_t val) @property {
		_instrAddr = val;
	}

}