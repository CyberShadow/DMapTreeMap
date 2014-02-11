module mapfile; // salvaged from Diamond

import std.file;
import std.string;
import std.algorithm : sort;

import ae.utils.text;

enum END_PREFIX = "END\t";

struct Symbol
{
	ulong address;
	string name;
	size_t index;
}

final class MapFile
{
	this(string fileName)
	{
		auto lines = splitAsciiLines(cast(string)read(fileName));
		bool parsing = false;
		foreach (index, line; lines)
		{
			line = forceValidUTF8(line);
			scope(failure) std.stdio.writeln(line);

			// OPTLINK / MS link format
			if (parsing)
			{
				if (line.length > 30 && line[5]==':' && line[17]==' ')
				{
					// 0002:00078A44       _D5win327objbase11IsEqualGUIDFS5win328basetyps4GUIDS5win328basetyps4GUIDZi 0047CA44
					Symbol s;
					auto line2 = line[21..$];
					s.name = line2[0..line2.indexOf(' ')];
					auto segments = line2.split();
					if (segments.length < 2)
						continue;
					s.address = fromHex(segments[1]);
					s.index = index;
					symbols ~= s;
				}
			}
			else
				if (line.indexOf("Publics by Value")>0)
					parsing = true;
				
			// LD format
			//                 0x00000000080eaa10                _D20TypeInfo_E2WA6Nation6__initZ
			//  .plt           0x00000000004415c0      0x8c0 /usr/lib/gcc/x86_64-linux-gnu/4.6.1/../../../x86_64-linux-gnu/crt1.o
			//                 0x00000000       0x60 /usr/lib/gcc/i686-pc-linux-gnu/4.6.2/../../../libgphobos2.a(exception.o)

			if (line.length > 45 && line[15..18]==" 0x")
			{
				auto seg  = strip(line[0..16]);
				if (seg == ".comment")
					continue;
				auto parts = line[18..$].split();
				auto addr = fromHex!ulong(parts[0]);
				auto rest = parts[1..$];
				ulong size;
				if (rest.length && rest[0].startsWith("0x"))
				{
					size = fromHex!ulong(rest[0][2..$]);
					rest = rest[1..$];
				}
				string symName = rest.join(" ");
				if (symName.startsWith(". =") ||
					symName.startsWith("_end =") ||
					symName.startsWith("PROVIDE ("))
					continue;
				string name = symName.length ? seg.length ? symName ~ " (" ~ seg ~ ")" : symName : seg;
				symbols ~= Symbol(addr, name, index);

				if (addr && size)
					symbols ~= Symbol(addr+size, END_PREFIX ~ name, index);
			}

			// OS X format
			// 0x00001CCC	0x0000001C	[  4] _D6object7__arrayZ
			auto tabs = line.split("\t");
			if (tabs.length == 3 && tabs[0].startsWith("0x") && tabs[1].startsWith("0x") && tabs[2].startsWith("["))
			{
				auto addr = fromHex!ulong(tabs[0][2..$]);
				auto size = fromHex!ulong(tabs[1][2..$]);
				auto name = tabs[2][tabs[2].indexOf("] ")+2..$];
				symbols ~= Symbol(addr, name, index);
				if (size)
					symbols ~= Symbol(addr+size, END_PREFIX ~ name, index);
			}
		}
		sort!q{a.address == b.address ? a.index < b.index : a.address < b.address}(symbols);
	}

	Symbol[] symbols;
}
