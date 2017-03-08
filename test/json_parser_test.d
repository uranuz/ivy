module ivy.json_parser_test;

import ivy.json, ivy.interpreter_data;

void main()
{
	string jsonStr = `
	{
		"name": "Vasya",
		"animals": [
			"cat", "dog", "bird"
		],
		"numbers": [
			1, 2,3,4, -8
		],
		"floats": [
			12.3, 33.7, -66.6, 0.0
		],
		"specials": [
			null, true, false
		]
	}
	`;

	auto parsedJSON = parseIvyJSON(jsonStr);

	import std.array: appender;
	auto buf = appender!string;

	renderDataNode!(DataRenderType.Text)(parsedJSON, buf);
	import std.stdio;
	writeln(buf.data);
}