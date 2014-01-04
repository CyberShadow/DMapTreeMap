module testsym;

import std.stdio;
import std.string;

import dsym;

void main()
{
	while (!stdin.eof)
	{
		auto sym = readln().chomp();
		if (!sym.length) continue;
		string dem;
		auto result = parseDSymbol(sym, dem);
		writeln(result, " ", dem);
	}
}
