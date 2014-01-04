module dsym;

import std.string;
import std.conv;
import std.ascii;
import std.array;
import std.exception;
import core.demangle;

string[] parseDSymbol(string sym, out string dem)
{
	{
		size_t p = 0;
		auto decoded = decodeDmdString(sym, p);
		if (decoded.length && p==sym.length)
			sym = decoded;
	}

	if (sym.startsWith("__D"))
		sym = sym[1..$];

	sizediff_t p;
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
		bool ok = true;
		foreach (seg; segments)
			if (seg.isMangledTemplateInstance())
				ok = false;

		if (ok)
		{
			foreach (ref seg; segments)
			{
				if (seg.startsWith("extern (C) "))
					seg = seg["extern (C) ".length..$];
				if (seg.lastIndexOf(' ')>=0)
					seg = seg[seg.lastIndexOf(' ')+1..$];
				if (seg.indexOf('(')>=0)
					seg = seg[0..seg.indexOf('(')];
				if (seg.indexOf('!')>=0)
					seg = seg[0..seg.indexOf('!')];

				seg = seg
					.replace([SUB_SPACE], " ")
					.replace([SUB_PERIOD], ".");
			}
			return segments;
		}
		// core.demangle failed, use simpler algorithm
	}

	if (sym.startsWith("_D") && sym.length>=4 && isDigit(sym[2]))
	{
		segments = sym[2..$].rlSplit();
		dem = segments.join(".");

		if (segments[0].startsWith("TypeInfo_"))
		{
			auto tiSegments = segments[0][9..$].rlSplitForce();
			if (tiSegments.length > 1)
				segments = tiSegments ~ ["TypeInfo"] ~ segments[1..$];
			else
				segments = ["TypeInfo"] ~ tiSegments ~ segments[1..$];
		}
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
	{
		if (sym.indexOf("@@") > 0)
		{
			while (sym.startsWith("?"))
				sym = sym[1..$];
			while (sym.length && sym[0].isDigit())
				sym = sym[1..$];
			sym = sym[0..sym.indexOf("@@")];
			segments = sym.split("@").reverse;
			dem = segments.join("::");
		}
		else
			segments = [sym];
		segments = ["C++ symbols"] ~ segments;
	}
	else
	if (sym.startsWith("_Z"))
	{
		segments = sym[2..$].rlSplitForce()[0..$-1];
		dem = segments.join("::");
		segments = ["C++ symbols"] ~ segments;
	}
	else
	if (sym.startsWith("__imp__"))
		segments = ["Imports", sym[7..$]];
	else
	if (sym.startsWith("_TMP"))
		segments = ["TMP", sym[4..$]];
	else
	if (sym.startsWith("__HandlerTable"))
		segments = ["Exception handler tables", sym["__HandlerTable".length..$]];
	else
	if ((p = sym.indexOf(": ")) > 0)
	{
		segments = sym[0..p] ~ parseDSymbol(sym[p+2..$], dem);
		dem = sym[0..p+2] ~ dem;
	}
	else
	if (sym.startsWith("_"))
	{
		auto str = sym;
		while (str.startsWith("_")) str = str[1..$];
		p = str.indexOf("_");
		if (p > 0)
			segments = ["C symbols", str[0..p], str[p+1..$]];
		else
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
	if (sym == "internal" || sym == "anon")
		segments = [sym, ""];
	else
		segments = [sym];

	return segments;
}

string[] rlSplit(string str, bool force=false)
{
	string[] segments;
	while (str.length)
	{
		try
		{
			if (force)
				while (str.length && !isDigit(str[0]))
					str = str[1..$];
			auto len = parse!uint(str);
			enforce(len <= str.length);
			segments ~= rlSubSplit(str[0..len]);
			str = str[len..$];
			//while (str.length && !isDigit(str[0]))
			//	str = str[1..$];
		}
		catch (Exception e)
		{
			if (str != "Z")
				segments ~= str;
			str = null;
		}
	}
	return segments;
}

string[] rlSplitForce(string str)
{
	auto s = str;
	try
	{
		while (s.length && !isDigit(s[0]))
			s = s[1..$];
		enforce(s.length);
		return rlSplit(s);
	}
	catch
		return [str];
}

bool isMangledTemplateInstance(string s)
{
	return s.length > 4 && s.startsWith("__T") && isDigit(s[3]);
}

string[] rlSubSplit(string s)
{
	if (s.isMangledTemplateInstance())
		return s[3..$].rlSplit();
	else
		return s.split("/");
}
