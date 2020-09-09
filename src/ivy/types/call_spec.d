module ivy.types.call_spec;

// Directive call specification
struct CallSpec
{
private:
	/// Position attributes count passed in directive call
	size_t _posAttrsCount = 0;

	/// Is there keyword attributes in directive call
	bool _hasKwAttrs = false;

public:
	this(size_t encodedSpec)
	{
		this._posAttrsCount = encodedSpec >> 1;
		this._hasKwAttrs = (1 & encodedSpec) != 0;
	}

	this(size_t posAttrCount, bool hasKwAttrs)
	{
		this._posAttrsCount = posAttrCount;
		this._hasKwAttrs = hasKwAttrs;
	}

	size_t posAttrsCount() @property {
		return this._posAttrsCount;
	}

	bool hasKwAttrs() @property {
		return this._hasKwAttrs;
	}

	size_t encode() {
		return (this._posAttrsCount << 1) + (this._hasKwAttrs? 1: 0);
	}
}