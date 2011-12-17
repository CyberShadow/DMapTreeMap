module dsym;

import std.string;
import std.conv;
import std.ascii;
import std.array;
import std.exception;
import core.demangle;

string[] parseDSymbol(string sym, out string dem)
{
	size_t p = 0;
	auto decoded = decodeDmdString(sym, p);
	if (decoded.length && p==sym.length)
		sym = decoded;

	if (sym.startsWith("__D"))
		sym = sym[1..$];

	dem = demangle(sym).idup;
	string[] segments;
	if (dem != sym)
	{
		enum SUB_SPACE  = '\xFF';
		enum SUB_PERIOD = '\xFE';

		int plevel = 0;
		auto str = dem.dup;
		foreach (ref c; str)
			if (c=='(')
				plevel++;
			else
			if (c==')')
				plevel--;
			else
			if (c==' ' && plevel)
				c = SUB_SPACE;
			else
			if (c=='.' && plevel)
				c = SUB_PERIOD;

		segments = assumeUnique(str).replace("...", [SUB_PERIOD, SUB_PERIOD, SUB_PERIOD]).split(".");
		foreach (ref seg; segments)
		{
			if (seg.startsWith("extern (C) "))
				seg = seg["extern (C) ".length..$];
			if (seg.lastIndexOf(' ')>=0)
				seg = seg[seg.lastIndexOf(' ')+1..$];
			if (seg.indexOf('(')>=0)
				seg = seg[0..seg.indexOf('(')];

			seg = seg
				.replace([SUB_SPACE], " ")
				.replace([SUB_PERIOD], ".");
		}
	}
	else
	{
		if (sym.startsWith("_D") && sym.length>=4 && isDigit(sym[2]))
		{
			auto str = sym[2..$];
			while (str.length)
			{
				try
				{
					auto len = parse!uint(str);
					enforce(len <= str.length);
					segments ~= str[0..len].split("/");
					str = str[len..$];
				}
				catch (Exception e)
				{
					if (str != "Z")
						segments ~= str;
					str = null;
				}
			}
			dem = segments.join(".");

			if (segments[0].startsWith("TypeInfo_"))
				segments = ["TypeInfo", segments[0][9..$]] ~ segments[1..$];
		}
		else
		if (sym.startsWith("__d_"))
			segments = ["D internals", sym[4..$]];
		else
		if (sym.startsWith("_d_"))
			segments = ["D internals", sym[3..$]];
		else
		/*if (sym in cppSymbols)
			dem = cppSymbols[sym];
		else*/
		if (sym.startsWith("?"))
			segments = ["C++ symbols", sym];
		else
		if (sym.startsWith("__imp__"))
			segments = ["Imports", sym[7..$]];
		else
		if (sym.startsWith("_"))
		{
			auto str = sym;
			while (str.startsWith("_")) str = str[1..$];
			segments = ["C symbols", str];
		}
		else
		if (sym.startsWith("/"))
		{
			auto str = sym
				.replace(" (", "(")
				.replace("(", "/")
				.replace(")", "");
			segments = str.split("/");
			segments[0] = "/";

			int j = 0;
			while (j < segments.length-1)
				if (segments[j+1] == "..")
					segments = segments[0..j] ~ segments[j+2..$],
					j--;
				else
					j++;
		}
		else
			segments = [sym];
	}

	return segments;
}
