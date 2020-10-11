module ivy.types.symbol.dir_body_attrs;

struct DirBodyAttrs
{
	import std.json: JSONValue;

	bool isNoscope;
	bool isNoescape;

	JSONValue toStdJSON()
	{
		return JSONValue([
			"isNoscope": this.isNoscope,
			"isNoescape": this.isNoescape
		]);
	}
}
