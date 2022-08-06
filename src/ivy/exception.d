module ivy.exception;

// Base class for Ivy exceptions
class IvyException: Exception
{
	import trifle.location: Location;
public:
	@nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow {
		super(msg, file, line, next);
	}

	Location location;

	override const(char)[] message() const @safe nothrow {
		return this.msg ~ "\nLocation: " ~ this.location.toString();
	}
}