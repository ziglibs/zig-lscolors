const std = @import("std");
const assert = std.debug.assert;

const entrytypes = @import("entrytypes.zig");
const style = @import("style.zig");

const ls_colors_default = "rs=0:di=01;34:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:mi=00:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arc=01;31:*.arj=01;31:*.taz=01;31:*.lha=01;31:*.lz4=01;31:*.lzh=01;31:*.lzma=01;31:*.tlz=01;31:*.txz=01;31:*.tzo=01;31:*.t7z=01;31:*.zip=01;31:*.z=01;31:*.dz=01;31:*.gz=01;31:*.lrz=01;31:*.lz=01;31:*.lzo=01;31:*.xz=01;31:*.zst=01;31:*.tzst=01;31:*.bz2=01;31:*.bz=01;31:*.tbz=01;31:*.tbz2=01;31:*.tz=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.war=01;31:*.ear=01;31:*.sar=01;31:*.rar=01;31:*.alz=01;31:*.ace=01;31:*.zoo=01;31:*.cpio=01;31:*.7z=01;31:*.rz=01;31:*.cab=01;31:*.wim=01;31:*.swm=01;31:*.dwm=01;31:*.esd=01;31:*.jpg=01;35:*.jpeg=01;35:*.mjpg=01;35:*.mjpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.ogv=01;35:*.ogx=01;35:*.aac=00;36:*.au=00;36:*.flac=00;36:*.m4a=00;36:*.mid=00;36:*.midi=00;36:*.mka=00;36:*.mp3=00;36:*.mpc=00;36:*.ogg=00;36:*.ra=00;36:*.wav=00;36:*.oga=00;36:*.opus=00;36:*.spx=00;36:*.xspf=00;36:";

const EntryTypeMap = std.hash_map.AutoHashMap(entrytypes.EntryType, style.Style);
const PatternMap = std.hash_map.StringHashMap(style.Style);

const LsColors = struct {
    entry_type_mapping: EntryTypeMap,
    pattern_mapping: PatternMap,

    const Self = @This();

    pub fn parseStr(alloc: *std.mem.Allocator, s: []const u8) !Self {
        var entry_types = EntryTypeMap.init(alloc);
        var patterns = PatternMap.init(alloc);

        var rules_iter = std.mem.separate(s, ":");
        while (rules_iter.next()) |rule| {
            var iter = std.mem.separate(rule, "=");

            if (iter.next()) |pattern| {
                if (iter.next()) |sty| {
                    if (iter.next() != null)
                        continue;

                    if (try style.Style.fromAnsiSequence(alloc, sty)) |style_parsed| {
                        if (entrytypes.EntryType.fromStr(pattern)) |entry_type| {
                            _ = try entry_types.put(entry_type, style_parsed);
                        } else {
                            _ = try patterns.put(pattern, style_parsed);
                        }
                    }
                }
            }
        }

        return Self {
            .entry_type_mapping = entry_types,
            .pattern_mapping = patterns,
        };
    }

    pub fn default(alloc: *std.mem.Allocator) !Self {
        return Self.parseStr(alloc, ls_colors_default);
    }

    pub fn fromEnv(alloc: *std.mem.Allocator) !Self {
        if (std.os.getenv("LSCOLORS")) |env| {
            return Self.parseStr(alloc, env);
        } else {
            return Self.default(alloc);
        }
    }

    pub fn deinit(self: *Self) void {
        self.entry_type_mapping.deinit();
        self.pattern_mapping.deinit();
    }
};

test "parse empty" {
    var arena = std.heap.ArenaAllocator.init(std.heap.direct_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    const lsc = &try LsColors.parseStr(allocator, "");
    lsc.deinit();
}

test "parse default" {
    var arena = std.heap.ArenaAllocator.init(std.heap.direct_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    const lsc = &try LsColors.default(allocator);
    lsc.deinit();
}

test "parse  geoff.greer.fm default lscolors" {
    var arena = std.heap.ArenaAllocator.init(std.heap.direct_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    const lsc = &try LsColors.parseStr(allocator, "di=34:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43");
    assert(lsc.entry_type_mapping.get(entrytypes.EntryType.Directory).?.value.foreground.? == style.Color.Blue);
    lsc.deinit();
}